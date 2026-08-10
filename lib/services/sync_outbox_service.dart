// Retry bookkeeping for the method push phase (WP A3) and staging for the pull
// phase (WP A4).
//
// Both live in side boxes on purpose. openRAL objects and methods are hashed as
// a whole (`generateStableHash`) and those hashes are compared against the
// cloud's per-user hash table, so any bookkeeping field written into a document
// would silently invalidate it. Nothing in here ever touches a document.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Per-method retry state for the push phase.
class SyncAttempt {
  SyncAttempt({
    required this.uid,
    this.attemptCount = 0,
    this.lastError,
    this.nextRetryAt,
    DateTime? firstFailureAt,
  }) : firstFailureAt = firstFailureAt ?? DateTime.now().toUtc();

  final String uid;
  int attemptCount;
  String? lastError;
  DateTime? nextRetryAt;
  final DateTime firstFailureAt;

  bool get isDue =>
      nextRetryAt == null || !nextRetryAt!.isAfter(DateTime.now().toUtc());

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'attemptCount': attemptCount,
        'lastError': lastError,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'firstFailureAt': firstFailureAt.toIso8601String(),
      };

  static SyncAttempt fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return SyncAttempt(
      uid: map['uid']?.toString() ?? '',
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError']?.toString(),
      nextRetryAt: DateTime.tryParse(map['nextRetryAt']?.toString() ?? ''),
      firstFailureAt:
          DateTime.tryParse(map['firstFailureAt']?.toString() ?? ''),
    );
  }
}

class SyncOutboxService {
  SyncOutboxService._();
  static final SyncOutboxService instance = SyncOutboxService._();

  Box<Map<dynamic, dynamic>>? _attempts;
  Box<Map<dynamic, dynamic>>? _staging;
  final Random _random = Random();

  /// Retry backoff: 30s, 60s, 2min, 4min ... capped at 15 minutes (+ jitter).
  static const Duration _baseBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(minutes: 15);

  /// Marker key inside the staging box. Only when it is present is a staged
  /// batch complete and therefore safe to commit.
  static const String _stagingCompleteKey = '__staging_complete__';

  bool get isOpen =>
      _attempts != null &&
      _attempts!.isOpen &&
      _staging != null &&
      _staging!.isOpen;

  Future<void> open(String userId) async {
    _attempts = await _openBox('sync_attempts_$userId', _attempts);
    _staging = await _openBox('sync_staging_$userId', _staging);
  }

  Future<Box<Map<dynamic, dynamic>>> _openBox(
      String boxName, Box<Map<dynamic, dynamic>>? current) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Map<dynamic, dynamic>>(boxName);
    }
    if (current != null && current.isOpen) await current.close();
    return Hive.openBox<Map<dynamic, dynamic>>(boxName);
  }

  Future<void> close() async {
    if (_attempts != null && _attempts!.isOpen) await _attempts!.close();
    if (_staging != null && _staging!.isOpen) await _staging!.close();
    _attempts = null;
    _staging = null;
  }

  //! ------------------------------------------------ push retry bookkeeping

  SyncAttempt? attemptFor(String uid) {
    if (_attempts == null || !_attempts!.isOpen) return null;
    final raw = _attempts!.get(uid);
    return raw == null ? null : SyncAttempt.fromMap(raw);
  }

  /// True when a previously failed item is still inside its backoff window and
  /// should be skipped in this run.
  bool isBackedOff(String uid) {
    final attempt = attemptFor(uid);
    return attempt != null && !attempt.isDue;
  }

  /// The earliest moment at which any backed-off item becomes due again.
  DateTime? get nextDueAt {
    if (_attempts == null || !_attempts!.isOpen) return null;
    DateTime? earliest;
    for (final raw in _attempts!.values) {
      final next = SyncAttempt.fromMap(raw).nextRetryAt;
      if (next == null) continue;
      if (earliest == null || next.isBefore(earliest)) earliest = next;
    }
    return earliest;
  }

  Future<void> recordFailure(String uid, String error) async {
    if (_attempts == null || !_attempts!.isOpen) return;
    final attempt = attemptFor(uid) ?? SyncAttempt(uid: uid);
    attempt.attemptCount += 1;
    attempt.lastError = error;
    attempt.nextRetryAt =
        DateTime.now().toUtc().add(backoffFor(attempt.attemptCount));
    await _attempts!.put(uid, attempt.toMap());
    debugPrint(
        'sync_outbox: $uid failed (attempt ${attempt.attemptCount}) - next try ${attempt.nextRetryAt}');
  }

  Future<void> recordSuccess(String uid) async {
    if (_attempts == null || !_attempts!.isOpen) return;
    if (_attempts!.containsKey(uid)) await _attempts!.delete(uid);
  }

  Duration backoffFor(int attemptCount) {
    final exponent = attemptCount <= 0 ? 0 : attemptCount - 1;
    final factor = exponent > 20 ? (1 << 20) : (1 << exponent);
    var seconds = _baseBackoff.inSeconds * factor;
    if (seconds > _maxBackoff.inSeconds) seconds = _maxBackoff.inSeconds;
    final jitter = _random.nextInt(max(1, (seconds * 0.2).round()));
    return Duration(seconds: seconds + jitter);
  }

  int get failingCount => _attempts?.length ?? 0;

  //! ------------------------------------------------- atomic pull staging

  /// Discards whatever an interrupted run left behind and starts a fresh batch.
  Future<void> beginStaging() async {
    if (_staging == null || !_staging!.isOpen) return;
    await _staging!.clear();
  }

  Future<void> stage(String uid, Map<String, dynamic> doc) async {
    if (_staging == null || !_staging!.isOpen) return;
    if (uid.isEmpty || uid == _stagingCompleteKey) return;
    await _staging!.put(uid, doc);
  }

  /// Marks the staged batch as fully received. Only after this marker exists may
  /// the batch be committed - a crash before it leaves the staging box to be
  /// discarded on the next start.
  Future<void> markStagingComplete() async {
    if (_staging == null || !_staging!.isOpen) return;
    await _staging!
        .put(_stagingCompleteKey, {'completedAt': DateTime.now().toUtc().toIso8601String()});
  }

  bool get hasCompleteStagedBatch =>
      _staging != null &&
      _staging!.isOpen &&
      _staging!.containsKey(_stagingCompleteKey);

  bool get hasStagedData =>
      _staging != null && _staging!.isOpen && _staging!.isNotEmpty;

  /// The staged documents, without the completion marker.
  Map<String, Map<dynamic, dynamic>> get stagedDocuments {
    if (_staging == null || !_staging!.isOpen) return {};
    final result = <String, Map<dynamic, dynamic>>{};
    for (final key in _staging!.keys) {
      if (key == _stagingCompleteKey) continue;
      final value = _staging!.get(key);
      if (value != null) result[key.toString()] = value;
    }
    return result;
  }

  Future<void> clearStaging() async {
    if (_staging == null || !_staging!.isOpen) return;
    await _staging!.clear();
  }

  /// Commits a complete staged batch into [target] in one Hive write, then
  /// clears the staging area. Returns the number of committed documents.
  ///
  /// An incomplete batch is discarded instead of applied - the next sync run
  /// re-fetches it cleanly via the hash comparison.
  Future<int> commitStagingInto(Box<Map<dynamic, dynamic>> target) async {
    if (_staging == null || !_staging!.isOpen) return 0;
    if (!hasCompleteStagedBatch) {
      if (hasStagedData) {
        debugPrint(
            'sync_outbox: discarding ${_staging!.length} staged docs from an interrupted pull');
        await clearStaging();
      }
      return 0;
    }
    final documents = stagedDocuments;
    if (documents.isNotEmpty) {
      await target.putAll(documents);
    }
    await clearStaging();
    debugPrint('sync_outbox: committed ${documents.length} pulled documents');
    return documents.length;
  }
}

/// Short-hand used across the sync stack.
SyncOutboxService get syncOutbox => SyncOutboxService.instance;

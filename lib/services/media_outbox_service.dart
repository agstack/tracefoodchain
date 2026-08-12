// Durable media persistence for photos/documents (WP A1).
//
// Problem: a photo used to exist only as a path inside an openRAL image object.
// If the upload failed - or the app was killed between "upload returned 200" and
// "downloadURL written" - there was no record that the media still had to reach
// the cloud, and no way to tell an unverified upload from a confirmed one.
//
// This service keeps a separate, durable Hive outbox next to localStorage with
// an explicit state chain:
//
//   capturedLocal -> uploading -> uploadedUnverified -> confirmedRemote -> deletedLocal
//
// The outbox lives in its own box on purpose: openRAL objects and methods are
// hashed as a whole and the hash is compared against the cloud's per-user hash
// table, so no sync bookkeeping may ever be written into the documents.
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// Outcome of checking the remote copy.
enum MediaVerification {
  /// The object is there and matches - safe to reference.
  confirmed,

  /// The object is provably not there (404/403) or has the wrong size.
  missing,

  /// We could not find out - network error, CORS, unexpected status. The
  /// upload must be kept and the check retried, never discarded.
  unverifiable,
}

/// State chain of a media item on its way to the cloud.
class MediaStatus {
  /// File is durably stored on the device, nothing uploaded yet.
  static const String capturedLocal = 'capturedLocal';

  /// An upload attempt is currently running.
  static const String uploading = 'uploading';

  /// Storage reported success, but we have not yet verified the remote copy.
  static const String uploadedUnverified = 'uploadedUnverified';

  /// Remote copy verified (exists, size matches) - safe to reference.
  static const String confirmedRemote = 'confirmedRemote';

  /// Local copy has been released after confirmation.
  static const String deletedLocal = 'deletedLocal';

  /// The local source is gone and the upload can never succeed - e.g. a web
  /// blob URL whose page is gone. Kept (not deleted) so the loss stays visible
  /// instead of the item silently disappearing from the queue.
  static const String unrecoverable = 'unrecoverable';
}

/// A single tracked media item. Backed by a plain Map so no Hive adapter and no
/// box migration is required.
class MediaOutboxEntry {
  MediaOutboxEntry({
    required this.mediaUID,
    required this.status,
    required this.localPath,
    this.imageName,
    this.remoteUrl,
    this.remotePath,
    this.sha256Hex,
    this.sizeBytes = 0,
    this.attemptCount = 0,
    this.lastError,
    this.linkedMethodUID,
    this.bytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.nextRetryAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String mediaUID;
  String status;
  String localPath;
  String? imageName;
  String? remoteUrl;
  String? remotePath;
  String? sha256Hex;
  int sizeBytes;
  int attemptCount;
  String? lastError;
  String? linkedMethodUID;

  /// Web only: the raw bytes. Blob URLs die with the browser tab, so the bytes
  /// themselves are the durable copy there.
  Uint8List? bytes;

  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? nextRetryAt;

  bool get isConfirmed =>
      status == MediaStatus.confirmedRemote || status == MediaStatus.deletedLocal;

  /// No upload attempt can ever succeed for this item any more.
  bool get isUnrecoverable => status == MediaStatus.unrecoverable;

  /// Still counted as pending - a lost photo is an open issue, not a
  /// non-event - but excluded from the retry work list below.
  bool get isPending => !isConfirmed;

  /// True once the retry backoff has elapsed (or no backoff is set).
  bool get isDue =>
      nextRetryAt == null || !nextRetryAt!.isAfter(DateTime.now().toUtc());

  Map<String, dynamic> toMap() => {
        'mediaUID': mediaUID,
        'status': status,
        'localPath': localPath,
        'imageName': imageName,
        'remoteUrl': remoteUrl,
        'remotePath': remotePath,
        'sha256': sha256Hex,
        'sizeBytes': sizeBytes,
        'attemptCount': attemptCount,
        'lastError': lastError,
        'linkedMethodUID': linkedMethodUID,
        'bytes': bytes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nextRetryAt': nextRetryAt?.toIso8601String(),
      };

  static MediaOutboxEntry fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return MediaOutboxEntry(
      mediaUID: map['mediaUID']?.toString() ?? '',
      status: map['status']?.toString() ?? MediaStatus.capturedLocal,
      localPath: map['localPath']?.toString() ?? '',
      imageName: map['imageName']?.toString(),
      remoteUrl: map['remoteUrl']?.toString(),
      remotePath: map['remotePath']?.toString(),
      sha256Hex: map['sha256']?.toString(),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError']?.toString(),
      linkedMethodUID: map['linkedMethodUID']?.toString(),
      bytes: map['bytes'] is Uint8List
          ? map['bytes'] as Uint8List
          : (map['bytes'] is List<int>
              ? Uint8List.fromList(List<int>.from(map['bytes'] as List))
              : null),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      nextRetryAt: DateTime.tryParse(map['nextRetryAt']?.toString() ?? ''),
    );
  }
}

class MediaOutboxService {
  MediaOutboxService._();
  static final MediaOutboxService instance = MediaOutboxService._();

  Box<Map<dynamic, dynamic>>? _box;
  final Random _random = Random();

  /// Retry backoff: 30s, 60s, 2min, 4min ... capped at 15 minutes (+ jitter).
  static const Duration _baseBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(minutes: 15);

  bool get isOpen => _box != null && _box!.isOpen;

  /// Opens the user-scoped outbox. Mirrors the localStorage lifecycle so media
  /// of one user never leaks into another user's session.
  Future<void> open(String userId) async {
    final boxName = 'media_outbox_$userId';
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<Map<dynamic, dynamic>>(boxName);
      return;
    }
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _box = await Hive.openBox<Map<dynamic, dynamic>>(boxName);
    debugPrint('media_outbox opened for $userId (${_box!.length} entries)');
  }

  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _box = null;
  }

  List<MediaOutboxEntry> get all {
    if (!isOpen) return const [];
    return _box!.values.map(MediaOutboxEntry.fromMap).toList();
  }

  MediaOutboxEntry? get(String mediaUID) {
    if (!isOpen) return null;
    final raw = _box!.get(mediaUID);
    if (raw == null) return null;
    return MediaOutboxEntry.fromMap(raw);
  }

  /// Media that still has to reach the cloud (anything before confirmedRemote).
  ///
  /// Excludes unrecoverable items: they will never be uploaded, so counting
  /// them as "waiting for upload" would promise something that cannot happen.
  /// They are reported separately via [unrecoverable].
  List<MediaOutboxEntry> get pending => all
      .where((e) => e.isPending && !e.isUnrecoverable)
      .toList(growable: false);

  int get pendingCount => pending.length;

  int get unrecoverableCount => unrecoverable.length;

  /// Pending media whose retry backoff has elapsed - the actual upload work list.
  List<MediaOutboxEntry> get dueForUpload => pending
      .where((e) => e.isDue && !e.isUnrecoverable)
      .toList(growable: false);

  /// Media that can never be uploaded any more, for reporting.
  List<MediaOutboxEntry> get unrecoverable =>
      all.where((e) => e.isUnrecoverable).toList(growable: false);

  Future<void> _put(MediaOutboxEntry entry) async {
    if (!isOpen) return;
    entry.updatedAt = DateTime.now().toUtc();
    await _box!.put(entry.mediaUID, entry.toMap());
  }

  /// Registers a freshly captured media item.
  ///
  /// [localPath] must already point at durable storage (application documents
  /// directory) on native platforms. On web there is no filesystem, so the raw
  /// [bytes] are stored in the box and become the durable copy.
  Future<MediaOutboxEntry?> enqueue({
    required String mediaUID,
    required String localPath,
    String? imageName,
    Uint8List? bytes,
    String? linkedMethodUID,
  }) async {
    if (!isOpen) {
      debugPrint('media_outbox not open - cannot enqueue $mediaUID');
      return null;
    }
    if (mediaUID.isEmpty) return null;

    final existing = get(mediaUID);
    if (existing != null) {
      // Never downgrade an entry that already made progress.
      if (linkedMethodUID != null && existing.linkedMethodUID == null) {
        existing.linkedMethodUID = linkedMethodUID;
        await _put(existing);
      }
      return existing;
    }

    Uint8List? durableBytes = bytes;
    int size = 0;
    String? digest;

    try {
      if (kIsWeb) {
        durableBytes ??= await _readWebBytes(localPath);
        if (durableBytes != null) {
          size = durableBytes.length;
          digest = sha256.convert(durableBytes).toString();
        }
      } else {
        durableBytes = null; // native keeps the file, not the bytes
        final file = File(localPath);
        if (await file.exists()) {
          final content = await file.readAsBytes();
          size = content.length;
          digest = sha256.convert(content).toString();
        } else {
          debugPrint('media_outbox: file missing at capture time: $localPath');
        }
      }
    } catch (e) {
      debugPrint('media_outbox: could not fingerprint $mediaUID: $e');
    }

    // On web the bytes ARE the durable copy. Without them the entry is a
    // placeholder for a photo that is already lost - say so at capture time
    // rather than letting it fail silently on the next sync.
    if (kIsWeb && durableBytes == null) {
      debugPrint('media_outbox: WARNING - no bytes for $mediaUID.'
          ' On web the caller must pass `bytes`, the blob URL cannot be read'
          ' back later. The photo will not be recoverable.');
    }

    final entry = MediaOutboxEntry(
      mediaUID: mediaUID,
      status: MediaStatus.capturedLocal,
      localPath: localPath,
      imageName: imageName,
      sha256Hex: digest,
      sizeBytes: size,
      bytes: durableBytes,
      linkedMethodUID: linkedMethodUID,
    );
    await _put(entry);
    debugPrint(
        'media_outbox: enqueued $mediaUID ($size bytes) as capturedLocal');
    return entry;
  }

  Future<Uint8List?> _readWebBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('media_outbox: could not read web blob $url: $e');
    }
    return null;
  }

  /// Links the media to the openRAL method that references it. The local copy is
  /// only ever released once that method itself is synced (no orphans).
  Future<void> linkMethod(String mediaUID, String methodUID) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.linkedMethodUID = methodUID;
    await _put(entry);
  }

  Future<void> markUploading(String mediaUID) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.status = MediaStatus.uploading;
    entry.attemptCount += 1;
    await _put(entry);
  }

  Future<void> markUploadedUnverified(
      String mediaUID, String remoteUrl, String? remotePath) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.status = MediaStatus.uploadedUnverified;
    entry.remoteUrl = remoteUrl;
    entry.remotePath = remotePath;
    entry.lastError = null;
    entry.nextRetryAt = null;
    await _put(entry);
  }

  Future<void> markConfirmed(String mediaUID) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.status = MediaStatus.confirmedRemote;
    entry.lastError = null;
    entry.nextRetryAt = null;
    await _put(entry);
  }

  /// The remote copy could not be verified (missing, or the size does not
  /// match). The upload is treated as never having happened: the entry falls
  /// back to `capturedLocal` so the next run re-uploads from the durable local
  /// copy instead of confirming a broken remote file.
  Future<void> markVerificationFailed(String mediaUID, String reason) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.status = MediaStatus.capturedLocal;
    entry.remoteUrl = null;
    entry.remotePath = null;
    entry.lastError = reason;
    entry.nextRetryAt =
        DateTime.now().toUtc().add(backoffFor(entry.attemptCount));
    await _put(entry);
    debugPrint('media_outbox: $mediaUID verification failed ($reason) - will re-upload');
  }

  /// The check itself could not be carried out. The upload stays as it is and
  /// only the verification is retried - re-uploading would waste the bandwidth
  /// this whole mechanism exists to save.
  Future<void> markVerificationDeferred(String mediaUID, String reason) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    entry.status = MediaStatus.uploadedUnverified;
    entry.lastError = reason;
    entry.nextRetryAt =
        DateTime.now().toUtc().add(backoffFor(entry.attemptCount));
    await _put(entry);
    debugPrint('media_outbox: $mediaUID verification deferred ($reason),'
        ' retry at ${entry.nextRetryAt}');
  }

  /// Records a failure and schedules the next attempt with exponential backoff
  /// plus jitter, so a fleet of devices returning online does not stampede.
  /// Maximum attempts before a missing local source is declared permanent.
  static const int _maxLocalSourceAttempts = 3;

  Future<void> markFailure(String mediaUID, String error,
      {bool localSourceMissing = false}) async {
    final entry = get(mediaUID);
    if (entry == null) return;
    // A failed attempt falls back to the last durable state.
    if (entry.status == MediaStatus.uploading) {
      entry.status = entry.remoteUrl != null
          ? MediaStatus.uploadedUnverified
          : MediaStatus.capturedLocal;
    }
    entry.lastError = error;

    // Without a local source there is nothing left to upload - retrying just
    // produces noise on every sync forever.
    if (localSourceMissing &&
        entry.remoteUrl == null &&
        entry.attemptCount >= _maxLocalSourceAttempts) {
      entry.status = MediaStatus.unrecoverable;
      entry.nextRetryAt = null;
      await _put(entry);
      debugPrint('media_outbox: $mediaUID is UNRECOVERABLE after'
          ' ${entry.attemptCount} attempts - local source gone ($error)');
      return;
    }

    entry.nextRetryAt = DateTime.now().toUtc().add(backoffFor(entry.attemptCount));
    await _put(entry);
    debugPrint(
        'media_outbox: $mediaUID failed (attempt ${entry.attemptCount}), retry at ${entry.nextRetryAt}');
  }

  Duration backoffFor(int attemptCount) {
    final exponent = attemptCount <= 0 ? 0 : attemptCount - 1;
    // 2^exponent, guarded against overflow for pathological attempt counts.
    final factor = exponent > 20 ? (1 << 20) : (1 << exponent);
    var seconds = _baseBackoff.inSeconds * factor;
    if (seconds > _maxBackoff.inSeconds) seconds = _maxBackoff.inSeconds;
    final jitter = _random.nextInt(max(1, (seconds * 0.2).round()));
    return Duration(seconds: seconds + jitter);
  }

  /// Verifies that the remote copy really exists and has the expected size
  /// before the item is considered safe. This is the gate between
  /// `uploadedUnverified` and `confirmedRemote`.
  ///
  /// Distinguishes "the file is not there" from "I could not check" - a browser
  /// that blocks the check (CORS, offline) must not make us discard a perfectly
  /// good upload and start over.
  Future<MediaVerification> verifyRemoteCopy(MediaOutboxEntry entry) async {
    final url = entry.remoteUrl;
    if (url == null || url.isEmpty) {
      debugPrint('media_outbox: verify ${entry.mediaUID} - no remote URL');
      return MediaVerification.missing;
    }

    http.Response? response;
    try {
      response = await http.head(Uri.parse(url));
      debugPrint('media_outbox: verify ${entry.mediaUID} HEAD -> '
          'HTTP ${response.statusCode}, headers=${response.headers}');
    } catch (e) {
      debugPrint('media_outbox: verify ${entry.mediaUID} HEAD threw: $e');
      response = null;
    }

    // Firebase Storage download URLs do not always answer HEAD - fall back to
    // a ranged GET that transfers a single byte.
    if (response == null || (response.statusCode != 200)) {
      try {
        response = await http.get(
          Uri.parse(url),
          headers: {'Range': 'bytes=0-0'},
        );
        debugPrint('media_outbox: verify ${entry.mediaUID} ranged GET -> '
            'HTTP ${response.statusCode}, headers=${response.headers}');
      } catch (e) {
        // Network error or a browser-blocked request (CORS): we simply do not
        // know whether the object is there.
        debugPrint('media_outbox: verify ${entry.mediaUID} GET threw: $e'
            ' -> treating as UNVERIFIABLE, keeping the upload');
        return MediaVerification.unverifiable;
      }
    }

    final status = response.statusCode;
    if (status == 404 || status == 403) {
      debugPrint('media_outbox: verify ${entry.mediaUID} -> MISSING (HTTP $status)');
      return MediaVerification.missing;
    }
    if (status != 200 && status != 206) {
      debugPrint('media_outbox: verify ${entry.mediaUID} -> UNVERIFIABLE '
          '(unexpected HTTP $status)');
      return MediaVerification.unverifiable;
    }

    final remoteSize = _remoteSizeOf(response);
    debugPrint('media_outbox: verify ${entry.mediaUID} sizes: '
        'local=${entry.sizeBytes} remote=${remoteSize ?? "unknown"}');
    if (entry.sizeBytes > 0 && remoteSize != null && remoteSize > 0) {
      if (remoteSize != entry.sizeBytes) {
        debugPrint('media_outbox: verify ${entry.mediaUID} -> MISSING '
            '(size mismatch ${entry.sizeBytes} vs $remoteSize)');
        return MediaVerification.missing;
      }
    }
    debugPrint('media_outbox: verify ${entry.mediaUID} -> CONFIRMED');
    return MediaVerification.confirmed;
  }

  /// Total size of the remote object, from either `content-length` (HEAD) or the
  /// `content-range` header of a ranged GET.
  int? _remoteSizeOf(http.Response response) {
    final range = response.headers['content-range'];
    if (range != null && range.contains('/')) {
      final total = range.split('/').last.trim();
      final parsed = int.tryParse(total);
      if (parsed != null) return parsed;
    }
    final length = response.headers['content-length'];
    if (length != null) {
      final parsed = int.tryParse(length);
      // A ranged GET reports the length of the range, not of the object.
      if (parsed != null && response.statusCode != 206) return parsed;
    }
    return null;
  }

  /// True when the local copy may be released: the remote copy is confirmed,
  /// the image object itself is synced, and the referencing method no longer
  /// needs a sync either. Without both checks a media file could be released
  /// while the document pointing at it still only exists on this device.
  bool isSafeToReleaseLocal(
      MediaOutboxEntry entry, bool Function(String uid) needsSync) {
    if (entry.status != MediaStatus.confirmedRemote) return false;
    if (needsSync(entry.mediaUID)) return false;
    final methodUID = entry.linkedMethodUID;
    if (methodUID != null && methodUID.isNotEmpty && needsSync(methodUID)) {
      return false;
    }
    return true;
  }

  /// Releases local copies of confirmed media.
  ///
  /// On web the cached bytes are dropped (they only exist to survive a tab
  /// reload). On native the file is kept by default because the app also renders
  /// photos from disk while offline - pass [deleteNativeFiles] to release those
  /// too once storage pressure matters.
  Future<int> releaseConfirmedLocalCopies({
    required bool Function(String uid) needsSync,
    bool deleteNativeFiles = false,
  }) async {
    if (!isOpen) return 0;
    int released = 0;
    for (final entry in all) {
      if (!isSafeToReleaseLocal(entry, needsSync)) continue;

      if (kIsWeb) {
        if (entry.bytes == null) continue;
        entry.bytes = null;
        entry.status = MediaStatus.deletedLocal;
        await _put(entry);
        released++;
      } else if (deleteNativeFiles) {
        try {
          final file = File(entry.localPath);
          if (await file.exists()) await file.delete();
          entry.status = MediaStatus.deletedLocal;
          await _put(entry);
          released++;
        } catch (e) {
          debugPrint('media_outbox: could not delete ${entry.localPath}: $e');
        }
      }
    }
    if (released > 0) {
      debugPrint('media_outbox: released $released local copies');
    }
    return released;
  }

  /// Returns the bytes to upload, reading from the durable local copy.
  Future<Uint8List?> readBytes(MediaOutboxEntry entry) async {
    try {
      if (kIsWeb) {
        if (entry.bytes != null) return entry.bytes;
        return await _readWebBytes(entry.localPath);
      }
      final file = File(entry.localPath);
      if (await file.exists()) return await file.readAsBytes();
      debugPrint('media_outbox: local file gone: ${entry.localPath}');
      return null;
    } catch (e) {
      debugPrint('media_outbox: readBytes failed for ${entry.mediaUID}: $e');
      return null;
    }
  }

  /// One-time migration: image objects captured before the outbox existed are
  /// picked up so they are retried and verified like everything else.
  Future<int> backfill({
    required Iterable<Map<String, dynamic>> imageObjects,
    required String Function(Map<String, dynamic> doc) uidOf,
    required dynamic Function(Map<String, dynamic> doc, String prop) propertyOf,
  }) async {
    if (!isOpen) return 0;
    int added = 0;
    for (final doc in imageObjects) {
      final uid = uidOf(doc);
      if (uid.isEmpty || get(uid) != null) continue;

      final localPath = propertyOf(doc, 'localDownloadURL')?.toString() ?? '';
      final cloudUrl = propertyOf(doc, 'downloadURL')?.toString() ?? '';
      final hasLocal = localPath.isNotEmpty && localPath != '-no data found-';
      final hasCloud = cloudUrl.isNotEmpty && cloudUrl != '-no data found-';

      if (!hasLocal && !hasCloud) continue;

      if (hasCloud) {
        // Already uploaded by the legacy path, but never verified.
        final entry = MediaOutboxEntry(
          mediaUID: uid,
          status: MediaStatus.uploadedUnverified,
          localPath: hasLocal ? localPath : '',
          imageName: doc['identity']?['name']?.toString(),
          remoteUrl: cloudUrl,
          remotePath: propertyOf(doc, 'storagePath')?.toString(),
        );
        await _put(entry);
        added++;
      } else {
        final entry = await enqueue(
          mediaUID: uid,
          localPath: localPath,
          imageName: doc['identity']?['name']?.toString(),
        );
        if (entry != null) added++;
      }
    }
    if (added > 0) debugPrint('media_outbox: backfilled $added legacy entries');
    return added;
  }

  /// Debug helper - human readable dump of the outbox.
  String describe() {
    if (!isOpen) return 'media_outbox: closed';
    final buffer = StringBuffer('media_outbox (${_box!.length} entries):\n');
    for (final entry in all) {
      buffer.writeln(
          '  ${entry.mediaUID} ${entry.status} attempts=${entry.attemptCount} '
          'size=${entry.sizeBytes} err=${entry.lastError ?? "-"}');
    }
    return buffer.toString();
  }
}

/// Short-hand used across the sync stack.
MediaOutboxService get mediaOutbox => MediaOutboxService.instance;

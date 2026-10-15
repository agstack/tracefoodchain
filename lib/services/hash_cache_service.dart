// Cache of the document hashes the pull sends to the cloud.
//
// Every pull sends the hash of every local document (see _runSyncCycle).
// Computing them took about 16 ms per document on the web - 45 s for 2,700
// documents, on every sync. The cache keeps the hash of each document until
// the document is written again, so a sync only hashes what changed.
//
// Invalidation: every write to localStorage (put, putAll, delete - whoever
// does it) arrives as an event of localStorage.watch() and removes the entry.
// A hash is only stored if the document it was computed from is still the
// one in the box (identity check), so a write during a sync cannot leave a
// stale entry behind.
//
// A stale entry (e.g. a write of the background isolate, which does not
// maintain the cache) heals itself: the cloud either sends its version again,
// which replaces the document and its entry, or the hashes match anyway.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';

class HashCacheService {
  HashCacheService._();
  static final HashCacheService instance = HashCacheService._();

  /// Bump when the output of generateStableHash changes - the cache is then
  /// cleared on the next open.
  static const int _formatVersion = 1;
  static const String _versionKey = '__formatVersion';

  Box<String>? _box;
  StreamSubscription<BoxEvent>? _watch;

  /// Hashes computed in the current scan, written in one go by [flush].
  /// Key -> (document the hash was computed from, hash).
  final Map<String, (Map<dynamic, dynamic>, String)> _pending = {};

  bool get isOpen => _box != null && _box!.isOpen;

  /// Opens the cache for [userId] and starts watching [storage].
  Future<void> open(String userId, Box<Map<dynamic, dynamic>> storage) async {
    final boxName = 'hash_cache_$userId';
    if (_box == null || !_box!.isOpen || _box!.name != boxName.toLowerCase()) {
      await close();
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box<String>(boxName)
          : await Hive.openBox<String>(boxName);
    }
    if (_box!.get(_versionKey) != '$_formatVersion') {
      await _box!.clear();
      await _box!.put(_versionKey, '$_formatVersion');
    }

    await _watch?.cancel();
    _watch = storage.watch().listen((event) {
      final key = event.key.toString();
      _pending.remove(key);
      if (isOpen && _box!.containsKey(key)) _box!.delete(key);
    });
    debugPrint('hash_cache opened for $userId (${_box!.length - 1} entries)');
  }

  Future<void> close() async {
    await _watch?.cancel();
    _watch = null;
    _pending.clear();
    if (_box != null && _box!.isOpen) await _box!.close();
    _box = null;
  }

  /// Hash of [doc] (stored under [key] in localStorage), from the cache if
  /// possible. [docWithoutSyncFlag] is the copy that is hashed - without
  /// needsSync, which must not be part of the hash.
  String hashFor(String key, Map<dynamic, dynamic> doc,
      Map<String, dynamic> docWithoutSyncFlag) {
    if (isOpen) {
      final cached = _box!.get(key);
      if (cached != null) return cached;
    }
    final hash = generateStableHash(docWithoutSyncFlag);
    if (isOpen) _pending[key] = (doc, hash);
    return hash;
  }

  /// Stores the hashes computed since the last flush - only those whose
  /// document has not been replaced meanwhile.
  Future<void> flush(Box<Map<dynamic, dynamic>> storage) async {
    if (!isOpen || _pending.isEmpty) {
      _pending.clear();
      return;
    }
    final Map<String, String> entries = {};
    _pending.forEach((key, value) {
      if (identical(storage.get(key), value.$1)) entries[key] = value.$2;
    });
    _pending.clear();
    if (entries.isNotEmpty) await _box!.putAll(entries);
    debugPrint('hash_cache: stored ${entries.length} new hashes');
  }
}

HashCacheService get hashCache => HashCacheService.instance;

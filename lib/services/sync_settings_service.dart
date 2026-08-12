// Persistent, app-wide sync preferences (WP A2).
//
// The cloud sync stack is reachable from plain top-level functions
// (`setObjectMethod`, background isolates, timers) that have no BuildContext and
// therefore no access to the Provider tree. The switch therefore lives in a
// singleton backed by shared_preferences and exposes ValueNotifiers so widgets
// can still rebuild on change.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace_foodchain_app/helpers/frame_safe_value_notifier.dart';

const String _kUploadPausedKey = 'uploadPaused';
const String _kLastSuccessfulSyncKey = 'lastSuccessfulSync';

class SyncSettingsService {
  SyncSettingsService._();
  static final SyncSettingsService instance = SyncSettingsService._();

  /// True while the user has deliberately suspended all cloud traffic.
  final ValueNotifier<bool> uploadPaused = FrameSafeValueNotifier<bool>(false);

  /// Timestamp (UTC) of the last sync run that finished without errors.
  final ValueNotifier<DateTime?> lastSuccessfulSync =
      FrameSafeValueNotifier<DateTime?>(null);

  /// Number of local items still waiting to reach the cloud
  /// (methods flagged `needsSync` + media that is not `confirmedRemote`).
  final ValueNotifier<int> pendingItemCount = FrameSafeValueNotifier<int>(0);

  /// Items that can never be uploaded any more - e.g. a photo whose local copy
  /// is gone. Kept apart from [pendingItemCount] so "waiting for upload" never
  /// contradicts a sync that correctly reports nothing to do.
  final ValueNotifier<int> failedItemCount = FrameSafeValueNotifier<int>(0);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      uploadPaused.value = prefs.getBool(_kUploadPausedKey) ?? false;
      final lastSync = prefs.getString(_kLastSuccessfulSyncKey);
      if (lastSync != null && lastSync.isNotEmpty) {
        lastSuccessfulSync.value = DateTime.tryParse(lastSync);
      }
      _loaded = true;
    } catch (e) {
      debugPrint('SyncSettingsService.load failed: $e');
    }
  }

  /// Persisted so the paused state survives an app restart.
  Future<void> setUploadPaused(bool paused) async {
    if (uploadPaused.value == paused) return;
    uploadPaused.value = paused;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kUploadPausedKey, paused);
    } catch (e) {
      debugPrint('SyncSettingsService.setUploadPaused failed: $e');
    }
  }

  Future<void> markSyncSuccessful() async {
    final now = DateTime.now().toUtc();
    lastSuccessfulSync.value = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSuccessfulSyncKey, now.toIso8601String());
    } catch (e) {
      debugPrint('SyncSettingsService.markSyncSuccessful failed: $e');
    }
  }

  /// Convenience accessor for the non-widget call sites.
  bool get isUploadPaused => uploadPaused.value;
}

/// Short-hand used across the sync stack.
SyncSettingsService get syncSettings => SyncSettingsService.instance;

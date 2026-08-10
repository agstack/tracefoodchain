// Sync orchestration helpers shared by the UI, the connectivity listener and
// the background isolate (WP A1/A2/A3/A4).
import 'package:flutter/foundation.dart';

import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/media_outbox_service.dart';
import 'package:trace_foodchain_app/services/sync_outbox_service.dart';
import 'package:trace_foodchain_app/services/sync_settings_service.dart';

// workmanager has no web implementation, so the registration is behind a
// conditional import - the same pattern the app already uses for device ids and
// the Google Maps initializer.
import 'package:trace_foodchain_app/services/background_sync_stub.dart'
    if (dart.library.io) 'package:trace_foodchain_app/services/background_sync_workmanager.dart'
    as platform;

class BackgroundSyncService {
  BackgroundSyncService._();

  /// Registers the periodic, connectivity-gated background sync (no-op on web).
  static Future<void> register() => platform.registerBackgroundSync();

  static Future<void> cancel() => platform.cancelBackgroundSync();
}

/// Convenience wrapper used by the "sync now" button, the dashboard timer and
/// the connectivity listener: pushes media first (so no method ever references
/// an unverified photo), then pushes/pulls methods for every configured cloud.
/// Honours the pause switch through the services it calls.
Future<void> runFullSync({
  bool syncFromCloud = true,
  void Function(String cloudKey)? onStatus,
}) async {
  if (syncSettings.isUploadPaused) {
    debugPrint('runFullSync: skipped (uploadPaused)');
    return;
  }
  await cloudSyncService.recoverInterruptedPull();
  await cloudSyncService.uploadPendingPhotos();
  for (final cloudKey in cloudConnectors.keys) {
    if (cloudKey == 'open-ral.io') continue;
    onStatus?.call(cloudKey);
    await cloudSyncService.syncMethods(cloudKey, syncFromCloud: syncFromCloud);
  }
}

/// Opens all user-scoped sync boxes. Called next to `initializeUserLocalStorage`
/// so the outboxes share the localStorage lifecycle.
Future<void> openUserSyncBoxes(String userId) async {
  await mediaOutbox.open(userId);
  await syncOutbox.open(userId);
}

Future<void> closeUserSyncBoxes() async {
  await mediaOutbox.close();
  await syncOutbox.close();
}

/// Recomputes the "waiting to be uploaded" counter shown in the sync UI.
void refreshPendingItemCount() {
  int pending = mediaOutbox.isOpen ? mediaOutbox.pendingCount : 0;
  if (localStorage != null && localStorage!.isOpen) {
    for (final doc in localStorage!.values) {
      if (doc['needsSync'] != null) pending++;
    }
  }
  syncSettings.pendingItemCount.value = pending;
}

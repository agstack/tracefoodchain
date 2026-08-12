// Sync orchestration helpers shared by the UI, the connectivity listener and
// the background isolate (WP A1/A2/A3/A4).
import 'package:flutter/foundation.dart';

import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
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
/// [force] bypasses the retry backoff - use it for an explicit "sync now",
/// never for the automatic triggers.
/// [onDetail] receives a human-readable progress line (upload/download counts).
/// [ignorePause] lets an explicit user action run despite a paused upload -
/// pausing suppresses *automatic* traffic, it is not a lock.
Future<SyncSummary> runFullSync({
  bool syncFromCloud = true,
  bool force = false,
  bool ignorePause = false,
  void Function(String cloudKey)? onStatus,
  void Function(String detail)? onDetail,
}) async {
  if (syncSettings.isUploadPaused && !ignorePause) {
    debugPrint('runFullSync: skipped (uploadPaused)');
    return const SyncSummary();
  }
  await cloudSyncService.recoverInterruptedPull();
  await cloudSyncService.uploadPendingPhotos(ignorePause: ignorePause);

  int pushed = 0, failed = 0, deferred = 0, pulled = 0, conflicts = 0;
  bool blocked = false;

  for (final cloudKey in cloudConnectors.keys) {
    if (cloudKey == 'open-ral.io') continue;
    onStatus?.call(cloudKey);
    // Snapshot by identity: if the notifier still holds the same object
    // afterwards, no cycle ran (another one was already active) and counting it
    // again would report a previous run's numbers as if they were fresh.
    final before = cloudSyncService.lastSyncSummary.value;
    await cloudSyncService.syncMethods(
      cloudKey,
      syncFromCloud: syncFromCloud,
      force: force,
      ignorePause: ignorePause,
      onProgress: (current, total) => onDetail?.call('↑ $current/$total'),
      onFetchingFromCloud: () => onDetail?.call('↓ ...'),
      onDownloadProgress: (current, total) =>
          onDetail?.call('↓ $current/$total'),
    );
    final summary = cloudSyncService.lastSyncSummary.value;
    if (identical(summary, before)) {
      blocked = true;
      continue;
    }
    if (summary != null) {
      pushed += summary.pushed;
      failed += summary.failed;
      deferred += summary.deferred;
      pulled += summary.pulled;
      conflicts += summary.conflicts;
    }
  }

  refreshPendingItemCount();
  return SyncSummary(
    pushed: pushed,
    failed: failed,
    deferred: deferred,
    pulled: pulled,
    conflicts: conflicts,
    blockedByRunningSync: blocked,
  );
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
  syncSettings.failedItemCount.value =
      mediaOutbox.isOpen ? mediaOutbox.unrecoverableCount : 0;
}

/// One item that is still waiting to reach the cloud.
class PendingItem {
  const PendingItem({
    required this.uid,
    required this.label,
    required this.type,
    required this.isMethod,
    required this.hasConflict,
    this.reason,
    this.isLost = false,
  });

  final String uid;
  final String label;
  final String type;
  final bool isMethod;

  /// Flagged by the cloud as a merge conflict - this will never clear by
  /// retrying, it needs a decision.
  final bool hasConflict;
  final String? reason;

  /// The item can never be uploaded any more - listed so the loss is visible,
  /// but deliberately not counted as "waiting".
  final bool isLost;

  String get displayName =>
      label.isNotEmpty ? label : (uid.isEmpty ? '?' : uid.substring(0, 8));
}

/// Lists exactly the items behind [SyncSettingsService.pendingItemCount].
///
/// A bare number ("2 open") cannot be checked by the user - especially when it
/// counts bookkeeping artefacts such as a conflict-flagged object rather than
/// anything they knowingly created.
List<PendingItem> collectPendingItems() {
  final items = <PendingItem>[];

  if (localStorage != null && localStorage!.isOpen) {
    for (final raw in localStorage!.values) {
      if (raw['needsSync'] == null) continue;
      final doc = Map<String, dynamic>.from(raw);
      final uid = doc['identity']?['UID']?.toString() ?? '';
      // Objects carry methodHistoryRef, methods do not.
      final isMethod = doc['methodHistoryRef'] == null;
      items.add(PendingItem(
        uid: uid,
        label: doc['identity']?['name']?.toString() ?? '',
        type: doc['template']?['RALType']?.toString() ?? '?',
        isMethod: isMethod,
        hasConflict: doc['hasMergeConflict'] == true,
        reason: doc['mergeConflictReason']?.toString() ??
            (syncOutbox.isOpen ? syncOutbox.attemptFor(uid)?.lastError : null),
      ));
    }
  }

  if (mediaOutbox.isOpen) {
    for (final entry in mediaOutbox.pending) {
      items.add(PendingItem(
        uid: entry.mediaUID,
        label: entry.imageName ?? '',
        type: 'image',
        isMethod: false,
        hasConflict: false,
        reason: entry.lastError ?? entry.status,
      ));
    }
    // Lost media is listed too - it is the only place the user can see that a
    // photo will never arrive.
    for (final entry in mediaOutbox.unrecoverable) {
      items.add(PendingItem(
        uid: entry.mediaUID,
        label: entry.imageName ?? '',
        type: 'image',
        isMethod: false,
        hasConflict: false,
        isLost: true,
        reason: entry.lastError,
      ));
    }
  }

  return items;
}

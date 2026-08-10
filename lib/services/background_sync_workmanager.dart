// Native implementation of the periodic background sync (WP A3).
//
// `workmanager` was already a dependency but was never registered, so a device
// that regained connectivity while the app was backgrounded did not sync until
// the user opened the app again.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:trace_foodchain_app/firebase_options.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/sync_settings_service.dart';

const String kPeriodicSyncTask = 'tfc_periodic_sync';
const String kPeriodicSyncTaskUnique = 'tfc_periodic_sync_unique';

/// Runs in a background isolate - must be a top-level function.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kPeriodicSyncTask) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await Hive.initFlutter();

      await syncSettings.load();
      if (syncSettings.isUploadPaused) {
        debugPrint('[BG SYNC] skipped - uploads paused by user');
        return true;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[BG SYNC] skipped - no authenticated user');
        return true;
      }

      // Opens localStorage plus the media/retry/staging boxes and recovers an
      // interrupted pull.
      await initializeUserLocalStorage(user.uid);
      await cloudSyncService.uploadPendingPhotos();
      // Push only: a full pull in the background would compete with the
      // foreground session for bandwidth on exactly the weak networks this is
      // meant to survive.
      await cloudSyncService.syncMethods('tracefoodchain.org',
          syncFromCloud: false);
      debugPrint('[BG SYNC] finished');
      return true;
    } catch (e) {
      debugPrint('[BG SYNC] failed: $e');
      // Returning false lets workmanager apply its own retry policy.
      return false;
    }
  });
}

/// Only Android and iOS have a workmanager implementation.
bool get _isSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

Future<void> registerBackgroundSync() async {
  if (!_isSupported) {
    debugPrint('Background sync not supported on this platform, skipping');
    return;
  }
  try {
    await Workmanager().initialize(
      backgroundSyncDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      kPeriodicSyncTaskUnique,
      kPeriodicSyncTask,
      // 15 minutes is the platform minimum for periodic work on Android.
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    debugPrint('Background sync registered (every 15 min, when connected)');
  } catch (e) {
    debugPrint('Could not register background sync: $e');
  }
}

Future<void> cancelBackgroundSync() async {
  if (!_isSupported) return;
  try {
    await Workmanager().cancelByUniqueName(kPeriodicSyncTaskUnique);
  } catch (e) {
    debugPrint('Could not cancel background sync: $e');
  }
}

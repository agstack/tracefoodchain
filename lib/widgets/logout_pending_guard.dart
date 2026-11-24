import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/background_sync_service.dart';

/// Fragt vor dem Abmelden nach, wenn auf diesem Gerät noch etwas auf den
/// Upload wartet. Gibt true zurück, wenn abgemeldet werden soll.
///
/// Abmelden löscht nichts - aber was nicht hochgeladen ist, liegt dann nur
/// noch im Speicher dieses Geräts bzw. Browsers und geht erst beim nächsten
/// Anmelden genau dort hinaus. Wer danach in einem anderen Browser
/// weiterarbeitet, verliert es faktisch.
///
/// Gewarnt wird nur bei Einträgen, die noch hochgeladen werden können:
/// Konflikte und verlorene Fotos ändern sich durch Warten nicht und würden
/// sonst bei jedem Abmelden eine Warnung auslösen.
Future<bool> confirmLogoutWithPendingUploads(BuildContext context) async {
  while (context.mounted) {
    final waiting = collectPendingItems()
        .where((item) => !item.hasConflict && !item.isLost)
        .length;
    if (waiting == 0) return true;

    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutPendingTitle,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.logoutPendingBody(waiting),
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'logout'),
            child: Text(l10n.logoutAnyway,
                style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'sync'),
            child: Text(l10n.syncNowButton),
          ),
        ],
      ),
    );

    if (choice == 'logout') return true;
    if (choice != 'sync' || !context.mounted) return false;

    // Hochladen, dann erneut prüfen - was danach noch wartet, wird wieder
    // angezeigt.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await cloudSyncService.uploadPendingPhotos(ignorePause: true);
      await cloudSyncService.syncMethods('tracefoodchain.org',
          syncFromCloud: false, ignorePause: true);
    } catch (e) {
      debugPrint('Sync before logout failed: $e');
    } finally {
      refreshPendingItemCount();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
  return false;
}

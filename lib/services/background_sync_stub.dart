// Web fallback: workmanager has no web implementation, so background sync is a
// no-op there. The browser tab syncs through the in-app timer and the
// connectivity listener instead.
Future<void> registerBackgroundSync() async {}

Future<void> cancelBackgroundSync() async {}

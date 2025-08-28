// import 'package:flutter/material.dart';
// import '../l10n/app_localizations.dart';
// import 'package:trace_foodchain_app/screens/home_screen.dart';

// // Globaler ValueNotifier, der eine Map mit Keys "type" und "text" hält.
// // Beispiel: {'type': 'error', 'text': 'Ein Fehler ist aufgetreten'} oder {'type': 'info', 'text': 'Operation erfolgreich'}.
// ValueNotifier<Map<String, String>?> globalSnackBarNotifier =
//     ValueNotifier(null);

// class GlobalSnackBarListener extends StatefulWidget {
//   final Widget child;
//   const GlobalSnackBarListener({Key? key, required this.child})
//       : super(key: key);

//   @override
//   _GlobalSnackBarListenerState createState() => _GlobalSnackBarListenerState();
// }

// class _GlobalSnackBarListenerState extends State<GlobalSnackBarListener> {
//   @override
//   void initState() {
//     super.initState();
//     globalSnackBarNotifier.addListener(_showSnackbar);
//   }

//   @override
//   void dispose() {
//     globalSnackBarNotifier.removeListener(_showSnackbar);
//     super.dispose();
//   }

//   void _showSnackbar() {
//     final msg = globalSnackBarNotifier.value;
//     if (msg == null || !msg.containsKey('text') || !msg.containsKey('type'))
//       return;

//     // Sicherstellen, dass der Kontext initialisiert ist, bevor l10n verwendet wird.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // Prüfen, ob AppLocalizations verfügbar ist
//       final l10n = AppLocalizations.of(context);
//       if (l10n == null) {
//         debugPrint('AppLocalizations.of(context) ist null');
//         return;
//       }

//       String? text;
//       String? mtext;
//       switch (msg['text']) {
//         case "error syncing to cloud":
//           mtext = l10n.errorSyncToCloud + ": \n";
//           break;
//         case "sync to cloud successful":
//           mtext = l10n.syncToCloudSuccessful;
//           break;
//         default:
//           mtext = msg['text']!;
//       }

//       if (msg.containsKey('errorCode')) {
//         switch (msg['errorCode']!) {
//           case '400':
//             text = mtext + l10n.errorBadRequest;
//             break;
//           case '401':
//             text = mtext + l10n.errorUnauthorized;
//             break;
//           case '403':
//             text = mtext + l10n.errorForbidden;
//             break;
//           case '404':
//             text = mtext + l10n.errorNotFound;
//             break;
//           case '409':
//             text = mtext + l10n.errorMergeConflict;
//             break;
//           case '500':
//             text = mtext + l10n.errorInternalServerError;
//             break;
//           case '503':
//             text = mtext + l10n.errorServiceUnavailable;
//             break;
//           case '504':
//             text = mtext + l10n.errorGatewayTimeout;
//             break;
//           case 'unknown error':
//             text = mtext + l10n.errorUnknown;
//             break;
//           case 'no valid cloud connection properties found!':
//             text = mtext + l10n.errorNoCloudConnectionProperties;
//             break;
//           default:
//             text = msg['text']!;
//         }
//       } else {
//         text = mtext;
//       }

//       final color = (msg['type'] == 'error') ? Colors.red : Colors.green;
//       snackbarMessageNotifier.value = text;
//       globalSnackBarNotifier.value = null;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {

//     return widget.child;
//   }
// }

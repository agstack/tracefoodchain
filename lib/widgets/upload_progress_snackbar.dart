import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/main.dart';
import '../l10n/app_localizations.dart';

/// Zeigt eine SnackBar mit Upload-Fortschritt an
///
/// Verwendung:
/// ```dart
/// showUploadProgressSnackBar(context);
/// ```
void showUploadProgressSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  final snackBar = SnackBar(
    duration: const Duration(days: 1), // Bleibt offen bis manuell geschlossen
    content: Row(
      children: [
        const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: uploadProgress,
            builder: (context, double value, child) {
              return Text(
                l10n.uploadProgress(value.toStringAsFixed(1)),
                style: const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ],
    ),
    backgroundColor: Colors.blue[700],
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

/// Schließt die Upload-SnackBar und zeigt optional eine Erfolgsmeldung
void closeUploadProgressSnackBar(BuildContext context, {bool success = true}) {
  final l10n = AppLocalizations.of(context)!;

  // Schließe aktuelle SnackBar
  ScaffoldMessenger.of(context).clearSnackBars();

  // Zeige Erfolgsmeldung
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              l10n.uploadSuccess,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              l10n.uploadFailed,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Widget für Upload-Progress Dialog (Alternative zur SnackBar)
class UploadProgressDialog extends StatelessWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            l10n.uploadingFile,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: uploadProgress,
            builder: (context, double value, child) {
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: value / 100.0,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.uploadProgress(value.toStringAsFixed(1)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Zeigt den Upload-Dialog an
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UploadProgressDialog(),
    );
  }

  /// Schließt den Upload-Dialog
  static void close(BuildContext context) {
    Navigator.of(context).pop();
  }
}

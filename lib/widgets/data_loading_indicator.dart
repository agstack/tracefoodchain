import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class DataLoadingIndicator extends StatelessWidget {
  final String? text;
  final Color? textColor;
  final Color? spinnerColor;
  const DataLoadingIndicator(
      {super.key, this.text, this.textColor, this.spinnerColor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String ftext = l10n.loadingData;
    Color tcolor = Colors.black;
    if (text != null) {
      ftext = text!;
    }
    if (textColor != null) {
      tcolor = textColor!;
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: spinnerColor ?? const Color(0xFF95D155),
            ),
            const SizedBox(height: 20),
            Text(
              ftext,
              style: TextStyle(color: tcolor),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}

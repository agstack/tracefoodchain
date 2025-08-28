import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final currentLocale =
        appState.locale ?? const Locale('en'); // Provide default locale
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: customTheme,
      child: PopupMenuButton<Locale>(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Image.asset(
            'assets/flags/${currentLocale.languageCode}.png',
            width: 24,
            height: 24,
          ),
        ),
        onSelected: (Locale locale) {
          appState.setLocale(locale);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
          PopupMenuItem<Locale>(
            value: const Locale('en'),
            child: _buildLanguageItem(l10n.languageEnglish, 'en'),
          ),
          PopupMenuItem<Locale>(
            value: const Locale('es'),
            child: _buildLanguageItem(l10n.languageSpanish, 'es'),
          ),
          PopupMenuItem<Locale>(
            value: const Locale('de'),
            child: _buildLanguageItem(l10n.languageGerman, 'de'),
          ),
          PopupMenuItem<Locale>(
            value: const Locale('fr'),
            child: _buildLanguageItem(l10n.languageFrench, 'fr'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(String languageName, String languageCode) {
    return Row(
      children: [
        Image.asset(
          'assets/flags/$languageCode.png',
          width: 24,
          height: 24,
        ),
        const SizedBox(width: 10),
        Text(languageName),
      ],
    );
  }
}

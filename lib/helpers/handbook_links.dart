import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/role_management_service.dart';
import '../services/service_functions.dart';

/// Handbücher in Google Docs, je Sprache.
///
/// Registrar- und Koordinatoren-Handbuch gibt es nur auf Deutsch, Englisch
/// und Spanisch; andere Sprachen bekommen die englische Fassung.
const Map<String, String> _registrarHandbooks = {
  'de': '1gWofLWNU7FhLhvGPj0CJOMackXSaChsWEMPGOOGpzHU',
  'en': '1duxbHg2gNURyFwTNJF5Xl7DthGtt-bEhzEF3ed0eACk',
  'es': '11sTTMlEa2I1UZd4CspSrz6IrDJer6zuWkuAbqlOA31U',
};

const Map<String, String> _coordinatorHandbooks = {
  'de': '1CXYYhtw-jLcu3-uXZciULcSOlU0OFQatNCgSN_yknIA',
  'en': '1dd9BusLcGjxzlfjZbe3OIqw9Cc2RTcEBaXGB5DmVT4I',
  'es': '1C1PFmIFw95tXDD2zp7qZuBBYaiO6wM729z3AbPUYLGw',
};

/// EUDR-Tracing-Modus: für alle übrigen Rollen und vor der Anmeldung.
const Map<String, String> _eudrHandbooks = {
  'de': '1wURF_uGIW3eKHh1qEn380_JE5tOdOyZRfFRQuL46Hn0',
  'en': '1JcNxTNEs6nkTDotVzFw-AFU0arB6T8aI1BfzKAuDF0A',
  'es': '1IVqaR_mJkQKbVobJfYM_EUxYCpd5B5qel0mY2U_KPVg',
  'fr': '19Z0dMR6CqHqaT2nU9qM4uzHftNFlIeZpd2AlyuHngP4',
};

const Set<String> _coordinatorRoles = {
  'registrarCoordinator',
  'countryCoordinator',
  'tfcAdmin',
  'SUPERADMIN',
};

/// Link zum Handbuch, das zu [role] passt; null steht für "noch keine Rolle".
String handbookUrl(String? role, String languageCode) {
  final Map<String, String> docs;
  if (role == 'registrar') {
    docs = _registrarHandbooks;
  } else if (_coordinatorRoles.contains(role)) {
    docs = _coordinatorHandbooks;
  } else {
    docs = _eudrHandbooks;
  }
  final id = docs[languageCode] ?? docs['en']!;
  return 'https://docs.google.com/document/d/$id';
}

/// Öffnet das Handbuch zur Rolle des angemeldeten Nutzers (bzw. zu [role])
/// in der Sprache der App.
Future<void> openHandbook(BuildContext context, {String? role}) async {
  final effectiveRole = role ?? RoleManagementService().getCurrentUserRole();
  final languageCode = Localizations.localeOf(context).languageCode;
  final url = Uri.parse(handbookUrl(effectiveRole, languageCode));
  if (!await launchUrl(url) && context.mounted) {
    await fshowInfoDialog(
        context, AppLocalizations.of(context)!.errorOpeningUrl);
  }
}

/// Hilfe-Symbol für die Kopfzeile, das das passende Handbuch öffnet.
class HandbookButton extends StatelessWidget {
  const HandbookButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: AppLocalizations.of(context)!.helpButtonTooltip,
      onPressed: () => openHandbook(context),
    );
  }
}

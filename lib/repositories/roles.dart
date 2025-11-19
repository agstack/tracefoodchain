import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class Role {
  final String key;
  final IconData icon;
  final String Function(AppLocalizations) getLocalizedName;

  const Role({
    required this.key,
    required this.icon,
    required this.getLocalizedName,
  });
}

List<Role> roles = [
  Role(
    key: 'Farmer',
    icon: Icons.agriculture,
    getLocalizedName: (l10n) => l10n.roleFarmer,
  ),
  Role(
    key: 'Trader',
    icon: Icons.business,
    getLocalizedName: (l10n) => l10n.roleTrader,
  ),
  Role(
    key: 'Processor',
    icon: Icons.factory,
    getLocalizedName: (l10n) => l10n.roleProcessor,
  ),
  Role(
    key: 'Importer',
    icon: Icons.local_shipping,
    getLocalizedName: (l10n) => l10n.roleImporter,
  ),
  Role(
    key: 'registrar',
    icon: Icons.assignment_ind,
    getLocalizedName: (l10n) => l10n.roleRegistrar,
  ),
  Role(
    key: 'System Administrator',
    icon: Icons.admin_panel_settings,
    getLocalizedName: (l10n) => l10n.roleSystemAdministrator,
  ),
  // Add other roles as needed
];

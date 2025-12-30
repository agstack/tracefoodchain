import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/fade_route.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import '../l10n/app_localizations.dart';
// import 'package:trace_foodchain_app/screens/geo_ids_view.dart';
import 'package:trace_foodchain_app/screens/sign_up_screen.dart';
import 'package:trace_foodchain_app/screens/field_registry_screen.dart';
import 'package:trace_foodchain_app/screens/user_management_screen.dart';
import 'package:trace_foodchain_app/screens/registrar_qc_screen.dart';
import 'package:trace_foodchain_app/screens/user_profile_view_screen.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/services/asset_registry_api_service.dart';
import 'package:trace_foodchain_app/services/user_registry_api_service.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Globale Variable zum Speichern des Modus
bool isTestmode = false;
bool showArchived = false;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // Neuer Switch zur Auswahl des Datenmodus (Test-/Echt-Modus)
          StatefulBuilder(
            builder: (context, setState) {
              return SwitchListTile(
                title: Text(
                    l10n.dataMode), // Lokalisierter Titel, z. B. "Datenmodus"
                subtitle: Text(isTestmode
                    ? l10n.testMode
                    : l10n.realMode), // z. B. "Testmodus" bzw. "Echtmodus"
                value: isTestmode,
                onChanged: (bool value) {
                  setState(() {
                    isTestmode = value;
                  });
                },
              );
            },
          ),
          // Neuer Switch zum Anzeigen archivierter Container
          StatefulBuilder(
            builder: (context, setState) {
              return SwitchListTile(
                title: Text(l10n.showArchivedContainers),
                subtitle: Text(showArchived
                    ? l10n.archivedContainersVisible
                    : l10n.archivedContainersHidden),
                value: showArchived,
                onChanged: (bool value) {
                  setState(() {
                    showArchived = value;
                  });
                },
              );
            },
          ),
          // User Profile
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const Icon(Icons.account_circle),
            title: Text(l10n.userProfile),
            subtitle: Text(l10n.viewAndEditProfile),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserProfileViewScreen(),
                ),
              );
            },
          ),
          // Field Registry
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const Icon(Icons.map),
            title: Text(l10n.fieldRegistry),
            subtitle: Text(l10n.fieldRegistryTitle),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FieldRegistryScreen(),
                ),
              );
            },
          ),
          // User Management (nur für privilegierte Rollen)
          if (PermissionService().hasPermission('user_management'))
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.userManagement),
              subtitle: Text(l10n.assignRole),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          // QC Review (nur für SUPERADMIN und registrarCoordinator)
          if (PermissionService().hasPermission('qc_review'))
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(Icons.fact_check),
              title: Text(l10n.qcReview),
              subtitle: Text(l10n.qcReviewSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegistrarQCScreen(),
                  ),
                );
              },
            ),
          // Test Asset Registry with User Registry Button
          // ListTile(
          //   contentPadding: const EdgeInsets.all(12),
          //   leading: const Icon(Icons.security),
          //   title: const Text("Test Asset Registry with User Registry"),
          //   onTap: () => _testAssetRegistryWithUserRegistry(context),
          // ),
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const Icon(Icons.arrow_circle_right),
            title: const Text("Log out"),
            onTap: appState.isConnected
                ? () async {
                    // Verwende die zentrale signOut-Methode aus AppState
                    // Diese schließt automatisch die Hive-Datenbank
                    final appState =
                        Provider.of<AppState>(context, listen: false);
                    await appState.signOut();

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const AuthScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                : () async {
                    fshowInfoDialog(context, l10n.nologoutpossible);
                  },
          ),
        ],
      ),
    );
  }

  /// Zeigt einen Login-Dialog für die User Registry an
  Future<Map<String, String>?> _showUserRegistryLoginDialog(
      BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.login),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                hintText: 'user@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: l10n.password,
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.pleaseEnterEmailAndPassword)),
                );
                return;
              }
              Navigator.pop(context, {
                'email': emailController.text,
                'password': passwordController.text,
              });
            },
            child: Text(l10n.login),
          ),
        ],
      ),
    );
  }

  void _showChangefarmerIdDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeFarmerId,
            style: const TextStyle(color: Colors.black54)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.enterNewFarmerID),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement changing farmer ID logic
              Navigator.pop(context);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showAssociateFarmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.associateWithDifferentFarm,
            style: const TextStyle(color: Colors.black54)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.enterNewFarmID),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement associating with a different farm logic
              Navigator.pop(context);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

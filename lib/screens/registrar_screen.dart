import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/gps_position_widget.dart';
import '../widgets/stepper_registrar_registration.dart';
import '../widgets/field_boundary_recorder.dart';
import '../widgets/language_selector.dart';
import '../screens/registrar_qc_screen.dart';
import '../screens/sign_up_screen.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../services/open_ral_service.dart';

class RegistrarScreen extends StatefulWidget {
  const RegistrarScreen({super.key});

  @override
  State<RegistrarScreen> createState() => _RegistrarScreenState();
}

class _RegistrarScreenState extends State<RegistrarScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _userName = '';
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkUserRole();
  }

  void _checkUserRole() {
    if (appUserDoc != null) {
      final userRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
      setState(() {
        _isSuperAdmin = userRole == 'SUPERADMIN';
      });
    }
  }

  void _loadUserName() {
    if (appUserDoc != null) {
      final firstName = appUserDoc!['specificProperties']?.firstWhere(
            (prop) => prop['key'] == 'firstName',
            orElse: () => {'value': ''},
          )['value'] ??
          '';
      final lastName = appUserDoc!['specificProperties']?.firstWhere(
            (prop) => prop['key'] == 'lastName',
            orElse: () => {'value': ''},
          )['value'] ??
          '';

      setState(() {
        _userName = '$firstName $lastName'.trim();
        if (_userName.isEmpty) {
          _userName = user?.email ?? 'Registrar';
        }
      });
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout, style: const TextStyle(color: Colors.black)),
        content: Text(l10n.logoutConfirmation,
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      // Verwende die zentrale signOut-Methode aus AppState
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.signOut();

      // Navigiere zum AuthScreen und entferne alle vorherigen Routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _openRegistrationForm() {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // GPS-Check
    if (!appState.hasGPS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.gpsRequired),
          content: Text(l10n.pleaseEnableGps),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Öffne Registrierungs-Stepper
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StepperRegistrarRegistration(),
      ),
    );
  }

  void _openQCReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrarQCScreen(),
      ),
    );
  }

  void _openFieldBoundaryRecorder() {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // GPS-Check
    if (!appState.hasGPS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.gpsRequired),
          content: Text(l10n.pleaseEnableGps),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Öffne Field Boundary Recorder
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FieldBoundaryRecorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registrarDashboard),
        actions: [
          const LanguageSelector(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              radius: 30,
                              child: const Icon(
                                Icons.verified_user,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.welcome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'REGISTRAR',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.quickActions,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildActionButton(
                              context,
                              icon: Icons.agriculture,
                              label: l10n.registerFarmFarmer,
                              color: Colors.blue,
                              onTap: _openRegistrationForm,
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.terrain,
                              label: l10n.recordFieldBoundary,
                              color: Colors.green,
                              onTap: _openFieldBoundaryRecorder,
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.history,
                              label: 'View History',
                              color: Colors.teal,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('History view - Coming soon'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // GPS Position Widget
                const GpsPositionWidget(),
                const SizedBox(height: 24),

                // Statistics Card (Placeholder for future)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.todaysStatistics,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              icon: Icons.person_add,
                              label: l10n.registered,
                              value: '0',
                              color: Colors.blue,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.check_circle,
                              label: l10n.verified,
                              value: '0',
                              color: Colors.green,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.pending,
                              label: l10n.pending,
                              value: '0',
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

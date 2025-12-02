import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../widgets/gps_position_widget.dart';
import '../main.dart';

class RegistrarScreen extends StatefulWidget {
  const RegistrarScreen({super.key});

  @override
  State<RegistrarScreen> createState() => _RegistrarScreenState();
}

class _RegistrarScreenState extends State<RegistrarScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
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
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Dashboard'),
        actions: [
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
                                  Text(
                                    'Welcome',
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

                // GPS Position Widget
                const GpsPositionWidget(),
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
                          'Quick Actions',
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
                              icon: Icons.person_add,
                              label: 'Register Entity',
                              color: Colors.blue,
                              onTap: () {
                                // TODO: Implement entity registration
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Entity registration - Coming soon'),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.qr_code_scanner,
                              label: 'Scan QR',
                              color: Colors.orange,
                              onTap: () {
                                // TODO: Implement QR scanning
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('QR scanning - Coming soon'),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.check_circle,
                              label: 'Verify Location',
                              color: Colors.green,
                              onTap: () {
                                // TODO: Implement location verification
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Location verification - Coming soon'),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.history,
                              label: 'View History',
                              color: Colors.purple,
                              onTap: () {
                                // TODO: Implement history view
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

                // Statistics Card (Placeholder for future)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Statistics',
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
                              label: 'Registered',
                              value: '0',
                              color: Colors.blue,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.check_circle,
                              label: 'Verified',
                              value: '0',
                              color: Colors.green,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.pending,
                              label: 'Pending',
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

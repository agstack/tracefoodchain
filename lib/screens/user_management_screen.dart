import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';
import 'package:trace_foodchain_app/helpers/role_debug_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin-Screen für User-Management mit Role-Assignment
/// Nur verfügbar für privilegierte Rollen (SUPERADMIN, tfcAdmin, registrarCoordinator)
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final RoleManagementService _roleService = RoleManagementService();
  final PermissionService _permissionService = PermissionService();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  /// Prüft Berechtigungen und lädt User-Daten
  Future<void> _checkPermissionsAndLoad() async {
    // Synchronisiere Rolle von der Cloud bevor Berechtigungen geprüft werden
    if (await _roleService.isOnline()) {
      await _roleService.syncRoleFromCloud();
    }

    final currentRole = _roleService.getCurrentUserRole();

    // Prüfe Grundberechtigung für User Management
    if (!_permissionService.hasPermission('user_management')) {
      setState(() {
        _errorMessage =
            'Keine Berechtigung für Benutzerverwaltung. Ihre Rolle: $currentRole';
      });
      return;
    }

    // Prüfe Online-Status
    if (!await _roleService.isOnline()) {
      setState(() {
        _errorMessage = 'Benutzerverwaltung ist nur online verfügbar';
      });
      return;
    }

    _loadUsers();
  }

  /// Lädt alle verwaltbaren User
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _roleService.getManagedUsers();
      // Da formatUserForDisplay jetzt async ist, müssen wir alle User einzeln formatieren
      final List<Map<String, dynamic>> formattedUsers = [];
      for (final user in users) {
        final formattedUser = await _roleService.formatUserForDisplay(user);
        formattedUsers.add(formattedUser);
      }

      setState(() {
        _users = formattedUsers;
        _filteredUsers = formattedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Filtert User-Liste basierend auf Such- und Rollenfilter
  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            user['name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            user['email']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        final matchesRole = _selectedRoleFilter == 'all' ||
            user['role'] == _selectedRoleFilter ||
            (_selectedRoleFilter == 'no_role' &&
                user['role'] == RoleManagementService.NO_ROLE);

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  /// Zeigt Role-Assignment Dialog
  Future<void> _showRoleAssignmentDialog(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(context)!;

    // SICHERHEIT: Prüfe ob es sich um einen SUPERADMIN handelt
    if (user['role'] == 'SUPERADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 ${l10n.superadminSecurityError}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final availableRoles = _roleService.getAvailableRoles();
    final currentUserRole = _roleService.getCurrentUserRole();

    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${l10n.noAvailableRolesForPermission} ($currentUserRole)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String selectedRole = availableRoles.first;
    String reason = '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${l10n.assignRole} - ${user['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${l10n.currentRole}: ${_getLocalizedRole(user['role'])}'),
                  const SizedBox(height: 16),
                  Text(l10n.newRole),
                  DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedRole = newValue!;
                      });
                    },
                    items: availableRoles
                        .map<DropdownMenuItem<String>>((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(_getLocalizedRole(role)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.reason),
                  TextField(
                    onChanged: (value) => reason = value,
                    decoration: InputDecoration(
                      hintText: l10n.enterReasonForRoleChange,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'role': selectedRole,
                      'reason': reason,
                    });
                  },
                  child: Text(l10n.assignRole),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _assignRole(user['uid'], result['role']!, result['reason']!);
    }
  }

  /// Weist User neue Rolle zu
  Future<void> _assignRole(
      String userUID, String newRole, String reason) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // Zeige Loading-Indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _roleService.changeUserRole(
        targetUserUID: userUID,
        newRole: newRole,
        reason: reason,
      );

      Navigator.of(context).pop(); // Schließe Loading-Dialog

      // Zeige Success-Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roleAssignedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );

      // Synchronisiere Rolle falls eigene Rolle geändert wurde
      if (userUID == FirebaseAuth.instance.currentUser?.uid) {
        await _roleService.syncRoleFromCloud();
      }

      // Lade User-Liste neu
      _loadUsers();
    } catch (e) {
      Navigator.of(context).pop(); // Schließe Loading-Dialog

      // Zeige Error-Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.errorAssigningRole}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Zeigt User-Details Dialog
  Future<void> _showUserDetailsDialog(Map<String, dynamic> user) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.userManagement),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', user['name']),
              _buildDetailRow('E-Mail', user['email']),
              _buildDetailRow(AppLocalizations.of(context)!.currentRole,
                  _getLocalizedRole(user['role'])),
              _buildDetailRow('User ID', user['uid']),
              _buildDetailRow(
                  'Verwaltbar',
                  user['canManage']
                      ? AppLocalizations.of(context)!.yes
                      : AppLocalizations.of(context)!.no),
            ],
          ),
          actions: [
            if (user['canManage'])
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRoleAssignmentDialog(user);
                },
                child: Text(AppLocalizations.of(context)!.assignRole),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  /// Hilfsmethode für Detail-Zeilen
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Holt verfügbare Rollen für Filter-Dropdown (ohne SUPERADMIN)
  List<String> _getFilterableRoles() {
    final currentRole = _roleService.getCurrentUserRole();
    List<String> filterRoles = [];

    // Alle Rollen aus roleLevels holen
    for (String role in RoleManagementService.roleLevels.keys) {
      // SUPERADMIN niemals im Filter anzeigen (für niemanden)
      if (role != 'SUPERADMIN') {
        filterRoles.add(role);
      }
    }

    return filterRoles;
  }

  /// Erstellt User-Liste Widget
  Widget _buildUserList() {
    final l10n = AppLocalizations.of(context)!;

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noUsersFound),
            const SizedBox(height: 8),
            Text(
              l10n.possibleReasons,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user['role']),
              child: Text(user['name'].toString().isNotEmpty
                  ? user['name'].toString().substring(0, 1).toUpperCase()
                  : '?'),
            ),
            title: Text(user['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email']),
                Text(
                  _getLocalizedRole(user['role']),
                  style: TextStyle(
                    color: _getRoleColor(user['role']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Debug-Info für Entwicklung
                if (user['canManage'] == false)
                  Text(
                    l10n.notManageable,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showUserDetailsDialog(user),
                  tooltip: l10n.showUserDetails,
                ),
                if (user['canManage'])
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRoleAssignmentDialog(user),
                    tooltip: l10n.editRole,
                  ),
                if (!user['canManage'])
                  IconButton(
                    icon: const Icon(Icons.lock),
                    onPressed: null,
                    tooltip: l10n.notManageable,
                  ),
              ],
            ),
            onTap: () => _showUserDetailsDialog(user),
          ),
        );
      },
    );
  }

  /// Hilfsmethode für Rollen-Farben
  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPERADMIN':
        return Colors.red;
      case 'tfcAdmin':
        return Colors.orange;
      case 'registrarCoordinator':
        return Colors.blue;
      case RoleManagementService.NO_ROLE:
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  /// Hilfsmethode um lokalisierte Rollenbezeichnung zu erhalten
  String _getLocalizedRole(String role) {
    final l10n = AppLocalizations.of(context)!;
    if (role == RoleManagementService.NO_ROLE) {
      return '${l10n.noRole} (${l10n.close})';
    }

    // Verwende lokalisierte Rollennamen
    switch (role) {
      case 'SUPERADMIN':
        return l10n.roleSuperAdmin;
      case 'tfcAdmin':
        return l10n.roleTfcAdmin;
      case 'registrarCoordinator':
        return l10n.roleRegistrarCoordinator;
      case 'Trader':
        return l10n.roleTrader;
      case 'Farmer':
        return l10n.roleFarmer;
      case 'Processor':
        return l10n.roleProcessor;
      case 'Importer':
        return l10n.roleImporter;
      case 'Transporter':
        return l10n.roleTransporter;
      case 'Seller':
        return l10n.roleSeller;
      case 'Buyer':
        return l10n.roleBuyer;
      case 'FarmManager':
        return l10n.roleFarmManager;
      default:
        return role; // Fallback für unbekannte Rollen
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.userManagement),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkPermissionsAndLoad,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.userManagement),
        actions: [
          // Debug Button für Rollenverwaltung
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: _showDebugInfo,
          //   tooltip: 'Debug Info',
          // ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Such- und Filter-Bereich
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Suchfeld
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.searchUsers,
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // Rollen-Filter
                Row(
                  children: [
                    Text('${AppLocalizations.of(context)!.filterByRole}: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRoleFilter = newValue!;
                          });
                          _applyFilters();
                        },
                        items: [
                          DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(AppLocalizations.of(context)!.allRoles),
                          ),
                          DropdownMenuItem<String>(
                            value: 'no_role',
                            child: Text(AppLocalizations.of(context)!.noRole),
                          ),
                          ..._getFilterableRoles()
                              .map<DropdownMenuItem<String>>((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(_getLocalizedRole(role)),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),

                // Info-Text
                Text(
                  '${_filteredUsers.length} / ${_users.length} users',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // User-Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  /// Zeigt Debug-Informationen für Rollenverwaltung
  Future<void> _showDebugInfo() async {
    final l10n = AppLocalizations.of(context)!;
    final debugInfo = await RoleDebugHelper.getFullUserRoleDebugInfo();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.roleManagementDebugInfo),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDebugSection(
                      'Firebase User', debugInfo['firebaseUser']),
                  const Divider(),
                  _buildDebugSection('appUserDoc', debugInfo['appUserDoc']),
                  const Divider(),
                  if (debugInfo.containsKey('appUserDocDetails'))
                    _buildDebugSection(
                        'appUserDoc Details', debugInfo['appUserDocDetails']),
                  const Divider(),
                  if (debugInfo.containsKey('firestoreUser'))
                    _buildDebugSection(
                        'Firestore User', debugInfo['firestoreUser']),
                  if (debugInfo.containsKey('firestoreError'))
                    Text(
                        '${l10n.firestoreError}: ${debugInfo['firestoreError']}',
                        style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final success = await RoleDebugHelper.repairAppUserDoc();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.appUserDocRepairedSuccessfully),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                  _checkPermissionsAndLoad(); // Neuladen
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.repairFailed),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(l10n.repairAppUserDoc),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDebugSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          data.toString(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

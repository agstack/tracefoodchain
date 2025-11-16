// NOTFALL: Manuelle Rollenzuweisung über Flutter Console
// Fügen Sie diese Zeilen in main.dart hinzu und führen Sie die App aus:

import 'package:trace_foodchain_app/helpers/role_debug_helper.dart';

// In einer async Funktion:
void assignEmergencyRole() async {
  // Zeige alle Benutzer
  final users = await RoleDebugHelper.getAllUsersWithRoles();
  print('Alle Benutzer: $users');

  // Weise einem Benutzer eine Rolle zu (VORSICHTIG verwenden!)
  // await RoleDebugHelper.manualRoleAssignment('USER_UID_HIER', 'SUPERADMIN');
}

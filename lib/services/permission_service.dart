import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';

/// Service für Permission-basierte Zugriffskontrolle
/// Nutzt openRAL Role-Templates für hierarchische Berechtigung
class PermissionService {
  /// Standard Permissions für verschiedene Funktionen
  static const Map<String, List<String>> featurePermissions = {
    // User Management Permissions
    'user_management': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],
    'view_users': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],
    'manage_roles': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],

    // Field Registry Permissions
    'field_registry': [
      'SUPERADMIN',
      'tfcAdmin',
      'registrarCoordinator',
      'Farmer'
    ],
    'create_fields': [
      'SUPERADMIN',
      'tfcAdmin',
      'registrarCoordinator',
      'Farmer'
    ],
    'export_fields': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],

    // System Settings
    'system_settings': ['SUPERADMIN'],
    'view_audit_logs': ['SUPERADMIN', 'tfcAdmin'],
    'backup_data': ['SUPERADMIN'],

    // Trading Functions
    'create_trades': [
      'SUPERADMIN',
      'tfcAdmin',
      'Trader',
      'Farmer',
      'Processor',
      'Importer'
    ],
    'view_trades': [
      'SUPERADMIN',
      'tfcAdmin',
      'Trader',
      'Farmer',
      'Processor',
      'Importer'
    ],
    'approve_trades': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],

    // QC Review
    'qc_review': ['SUPERADMIN', 'registrarCoordinator'],

    // Data Management
    'export_data': ['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator'],
    'import_data': ['SUPERADMIN', 'tfcAdmin'],
    'delete_data': ['SUPERADMIN'],
  };

  /// Singleton Instance
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Cached User Role für Performance
  String? _cachedUserRole;

  /// Holt die aktuelle User-Rolle (mit Caching)
  String getCurrentUserRole() {
    if (_cachedUserRole != null) {
      return _cachedUserRole!;
    }

    if (appUserDoc == null) {
      return '';
    }

    final role = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
    _cachedUserRole = (role != "" && role != "-no data found-") ? role : '';
    return _cachedUserRole!;
  }

  /// Invalidiert den Role Cache (nach Rollenänderungen)
  void invalidateRoleCache() {
    _cachedUserRole = null;
  }

  /// Prüft ob der aktuelle User eine bestimmte Permission hat
  bool hasPermission(String permission) {
    final userRole = getCurrentUserRole();
    if (userRole.isEmpty) {
      return false;
    }

    // Prüfe Feature-spezifische Permissions
    if (featurePermissions.containsKey(permission)) {
      final allowedRoles = featurePermissions[permission]!;
      final hasAccess = allowedRoles.contains(userRole);

      if (!hasAccess) {}

      return hasAccess;
    }

    // Fallback: Nur SUPERADMIN hat Zugang zu unbekannten Permissions

    return userRole == 'SUPERADMIN';
  }

  /// Prüft ob der User eine der angegebenen Rollen hat
  bool hasAnyRole(List<String> roles) {
    final userRole = getCurrentUserRole();
    return roles.contains(userRole);
  }

  /// Prüft ob der User eine spezifische Rolle hat
  bool hasRole(String role) {
    return getCurrentUserRole() == role;
  }

  /// Prüft ob der User Admin-Rechte hat (SUPERADMIN, tfcAdmin, registrarCoordinator)
  bool isAdmin() {
    return hasAnyRole(['SUPERADMIN', 'tfcAdmin', 'registrarCoordinator']);
  }

  /// Prüft ob der User SuperAdmin ist
  bool isSuperAdmin() {
    return hasRole('SUPERADMIN');
  }

  /// Prüft hierarchische Berechtigung (kann User A User B verwalten?)
  bool canManageUser(String targetUserRole) {
    final roleManagementService = RoleManagementService();
    return roleManagementService.canManageRole(
        getCurrentUserRole(), targetUserRole);
  }

  /// Holt alle verfügbaren Permissions für die aktuelle Rolle
  List<String> getAvailablePermissions() {
    final userRole = getCurrentUserRole();
    final permissions = <String>[];

    for (final entry in featurePermissions.entries) {
      if (entry.value.contains(userRole)) {
        permissions.add(entry.key);
      }
    }

    return permissions;
  }

  /// Formatiert Permissions für Debug-Ausgabe
  String formatPermissionsForDebug() {
    final userRole = getCurrentUserRole();
    final permissions = getAvailablePermissions();

    return 'User Role: $userRole\nAvailable Permissions: ${permissions.join(', ')}';
  }

  /// Prüft ob User Zugang zu spezifischen Screens hat
  bool canAccessScreen(String screenName) {
    switch (screenName) {
      case 'UserManagementScreen':
        return hasPermission('user_management');

      case 'FieldRegistryScreen':
        return hasPermission('field_registry');

      case 'SystemSettingsScreen':
        return hasPermission('system_settings');

      case 'AuditLogScreen':
        return hasPermission('view_audit_logs');

      default:
        // Für unbekannte Screens nur Basis-Berechtigungen prüfen
        return getCurrentUserRole().isNotEmpty;
    }
  }

  /// Prüft ob User bestimmte Aktionen ausführen kann
  bool canPerformAction(String action, {Map<String, dynamic>? context}) {
    switch (action) {
      case 'create_field':
        return hasPermission('create_fields');

      case 'export_field_data':
        return hasPermission('export_fields');

      case 'change_user_role':
        if (context != null && context.containsKey('targetRole')) {
          return canManageUser(context['targetRole']);
        }
        return hasPermission('manage_roles');

      case 'delete_user':
        return isSuperAdmin(); // Nur SUPERADMIN kann User löschen

      case 'view_user_details':
        return hasPermission('view_users');

      case 'export_user_data':
        return hasPermission('export_data');

      case 'backup_system':
        return hasPermission('backup_data');

      default:
        return isAdmin();
    }
  }

  /// Utility: Erstellt Permission-Filter für Listen
  List<T> filterByPermission<T>(List<T> items, String permission,
      {T Function(T)? transformer}) {
    if (!hasPermission(permission)) {
      return [];
    }

    return transformer != null ? items.map(transformer).toList() : items;
  }

  /// Prüft Role-Level basierte Hierarchie
  int getRoleLevel() {
    final userRole = getCurrentUserRole();
    return RoleManagementService.roleLevels[userRole] ?? 0;
  }

  /// Prüft ob aktuelle Rolle höher ist als Target-Rolle
  bool hasHigherRoleThan(String targetRole) {
    final myLevel = getRoleLevel();
    final targetLevel = RoleManagementService.roleLevels[targetRole] ?? 0;
    return myLevel > targetLevel;
  }

  /// Validation: Prüft ob eine Permission gültig ist
  bool isValidPermission(String permission) {
    return featurePermissions.containsKey(permission);
  }

  /// Development Helper: Zeigt alle Permissions für alle Rollen
  Map<String, List<String>> getAllRolePermissions() {
    final rolePermissions = <String, List<String>>{};

    for (final role in RoleManagementService.roleLevels.keys) {
      rolePermissions[role] = [];
      for (final entry in featurePermissions.entries) {
        if (entry.value.contains(role)) {
          rolePermissions[role]!.add(entry.key);
        }
      }
    }

    return rolePermissions;
  }
}

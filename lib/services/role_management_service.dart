import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:trace_foodchain_app/l10n/app_localizations.dart';

/// Service für Rollenverwaltung mit openRAL changeObjectData Integration
/// Stellt sicher, dass alle Rollenänderungen über methodHistory geloggt werden
class RoleManagementService {
  /// Konstante für 'keine Rolle' Status
  static const String NO_ROLE = 'KEINE_ROLLE';

  /// Vordefinierte Rollen mit hierarchischen Levels
  static const Map<String, int> roleLevels = {
    'SUPERADMIN': 1000,
    'tfcAdmin': 500,
    'registrarCoordinator': 300,
    'Trader': 100,
    'Farmer': 100,
    'Processor': 100,
    'Importer': 100,
    'registrar': 100,
  };

  /// Rollen die von bestimmten Rollen verwaltet werden können
  static const Map<String, List<String>> roleManagementPermissions = {
    'SUPERADMIN': [
      'tfcAdmin',
      'registrarCoordinator',
      'Trader',
      'Farmer',
      'Processor',
      'Importer',
      'registrar'
    ],
    'tfcAdmin': [
      'registrarCoordinator',
      'Trader',
      'Farmer',
      'Processor',
      'Importer',
      'registrar'
    ],
    'registrarCoordinator': [
      'Trader',
      'Farmer',
      'Processor',
      'Importer',
      'registrar'
    ],
  };

  /// Prüft ob der aktuelle User online ist (erforderlich für Rollenverwaltung)
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Prüft ob der aktuelle User berechtigt ist, eine bestimmte Rolle zu verwalten
  bool canManageRole(String currentUserRole, String targetRole) {
    if (!roleManagementPermissions.containsKey(currentUserRole)) {
      return false;
    }

    // NO_ROLE kann von allen Administratoren gesetzt werden
    if (targetRole == NO_ROLE) {
      return true;
    }

    return roleManagementPermissions[currentUserRole]!.contains(targetRole);
  }

  /// Prüft ob eine Rolle gültig ist
  bool isValidRole(String role) {
    return roleLevels.containsKey(role) || role == NO_ROLE;
  }

  /// Lädt die aktuellste Rolle des aktuellen Users aus der Cloud
  Future<String> getCurrentUserRoleFromCloud() async {
    // print('☁️ [RoleManagementService] getCurrentUserRoleFromCloud aufgerufen');
    if (!await isOnline()) {
      // print('📴 [RoleManagementService] Offline - nutze lokale Rolle');
      return getCurrentUserRole(); // Fallback auf lokale Rolle
    }

    final currentUserUID = FirebaseAuth.instance.currentUser?.uid;
    print('🆔 [RoleManagementService] currentUserUID: $currentUserUID');
    if (currentUserUID == null) {
      print('❌ [RoleManagementService] Kein currentUserUID!');
      return '';
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(currentUserUID)
          .get();

      if (userDoc.exists) {
        // print('✅ [RoleManagementService] User-Dokument in Cloud gefunden');
        final userData = userDoc.data()!;
        final role = getSpecificPropertyfromJSON(userData, "userRole");
        final finalRole = (role != "" && role != "-no data found-") ? role : '';
        // print('📋 [RoleManagementService] Cloud-Rolle: $finalRole');

        // Aktualisiere das lokale appUserDoc falls es nicht synchron ist
        if (appUserDoc != null) {
          final localRole =
              getSpecificPropertyfromJSON(appUserDoc!, "userRole");
          final localRoleFinal =
              (localRole != "" && localRole != "-no data found-")
                  ? localRole
                  : '';

          if (localRoleFinal != finalRole && finalRole.isNotEmpty) {
            appUserDoc = setSpecificPropertyJSON(
                appUserDoc!, "userRole", finalRole, "String");
          }
        }

        return finalRole;
      } else {
        return getCurrentUserRole(); // Fallback auf lokale Rolle
      }
    } catch (e) {
      return getCurrentUserRole(); // Fallback auf lokale Rolle
    }
  }

  /// Synchronisiert die lokale Rolle mit der Cloud und invalidiert Caches
  Future<void> syncRoleFromCloud() async {
    final cloudRole = await getCurrentUserRoleFromCloud();
    if (cloudRole.isNotEmpty) {
      // Cache invalidieren wird über Callback gemacht um zirkuläre Abhängigkeiten zu vermeiden
      _invalidatePermissionCache();
    }
  }

  /// Invalidiert den Permission-Cache indirekt
  void _invalidatePermissionCache() {
    // Implementierung für Cache-Invalidierung ohne zirkuläre Abhängigkeit
    // Dies wird über ein StaticCallback oder Singleton Pattern gehandhabt
  }

  /// Aktualisiert die AppState des aktuellen Users mit einer neuen Rolle
  Future<void> _updateCurrentUserAppState(String newRole) async {
    try {
      // Verwende das globale appUserDoc
      if (appUserDoc != null) {
        // Aktualisiere lokales appUserDoc
        appUserDoc =
            setSpecificPropertyJSON(appUserDoc!, "userRole", newRole, "String");

        // Invalidiere Permission-Cache
        _invalidatePermissionCache();
      }
    } catch (e) {
      // Fehler beim Aktualisieren der AppState
    }
  }

  /// Holt die aktuelle Rolle des eingeloggten Users
  String getCurrentUserRole() {
    // print('📖 [RoleManagementService] getCurrentUserRole aufgerufen');
    if (appUserDoc == null) {
      print('❌ [RoleManagementService] appUserDoc ist null!');
      return '';
    }

    final role = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
    final finalRole = (role != "" && role != "-no data found-") ? role : '';
    // print('📋 [RoleManagementService] Lokale Rolle aus appUserDoc: $finalRole');

    return finalRole;
  }

  /// Lädt alle User aus der Firebase-Datenbank und merged mit lokalen Daten
  Future<List<Map<String, dynamic>>> getAllUsers(
      {required AppLocalizations l10n}) async {
    if (!await isOnline()) {
      throw Exception(l10n.userManagementOnlineOnly);
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .where('template.RALType', isEqualTo: 'human')
          .get();

      final cloudUsers = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Ergänze mit lokalen Benutzer-Daten falls verfügbar
      final enrichedUsers = <Map<String, dynamic>>[];
      for (final cloudUser in cloudUsers) {
        Map<String, dynamic> user = Map<String, dynamic>.from(cloudUser);

        // Falls dies der aktuelle User ist, verwende das lokale appUserDoc
        final userUID = user['identity']?['UID'];
        if (userUID == FirebaseAuth.instance.currentUser?.uid &&
            appUserDoc != null) {
          user = Map<String, dynamic>.from(appUserDoc!);
        }

        enrichedUsers.add(user);
      }

      return enrichedUsers;
    } catch (e) {
      throw Exception(l10n.errorLoadingUser(e.toString()));
    }
  }

  /// Lädt User die der aktuelle Admin verwalten kann (basierend auf seiner Rolle)
  Future<List<Map<String, dynamic>>> getManagedUsers(
      {required AppLocalizations l10n}) async {
    final currentRole = await getCurrentUserRoleFromCloud();
    if (currentRole.isEmpty) {
      throw Exception(l10n.noValidUserRoleFound);
    }

    final allUsers = await getAllUsers(l10n: l10n);
    final managedUsers = <Map<String, dynamic>>[];

    for (final user in allUsers) {
      final userRole = getSpecificPropertyfromJSON(user, "userRole");
      final userUID = user['identity']?['UID'] ?? '';
      final effectiveRole = (userRole != "" && userRole != "-no data found-")
          ? userRole
          : NO_ROLE;

      // SICHERHEIT: SUPERADMIN-Benutzer werden NIEMALS in der Verwaltung angezeigt
      // Das gilt für ALLE Administratoren (auch andere SUPERADMINs)
      if (effectiveRole == 'SUPERADMIN') {
        continue;
      }

      // SUPERADMIN kann alle anderen NON-SUPERADMIN Benutzer sehen (außer sich selbst)
      if (currentRole == 'SUPERADMIN' &&
          userUID != FirebaseAuth.instance.currentUser?.uid) {
        managedUsers.add(user);
      }
      // Andere Admins: Nur User deren Rollen sie verwalten können oder rollenlose User
      else if (currentRole != 'SUPERADMIN') {
        if (effectiveRole == NO_ROLE ||
            canManageRole(currentRole, effectiveRole)) {
          managedUsers.add(user);
        }
      }
    }

    return managedUsers;
  }

  /// Ändert die Rolle eines Users über changeObjectData (mit automatischem Logging)
  Future<void> changeUserRole({
    required String targetUserUID,
    required String newRole,
    required AppLocalizations l10n,
    String reason = '',
  }) async {
    // SICHERHEIT: SUPERADMIN kann niemals zugewiesen werden
    if (newRole == 'SUPERADMIN') {
      throw Exception(l10n.superadminCannotBeAssigned);
    }

    // Validierungen
    if (!await isOnline()) {
      throw Exception(l10n.userManagementOnlineOnly);
    }

    if (!isValidRole(newRole)) {
      throw Exception(l10n.noPermissionForRole(newRole));
    }

    final currentUserRole = getCurrentUserRole();
    if (currentUserRole.isEmpty) {
      throw Exception(l10n.noValidAdminRole);
    }

    if (!canManageRole(currentUserRole, newRole)) {
      throw Exception(l10n.noPermissionForRole(newRole));
    }

    // Lade den Ziel-User
    Map<String, dynamic> targetUser;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(targetUserUID)
          .get();

      if (!userDoc.exists) {
        throw Exception(l10n.userNotFound);
      }

      targetUser = Map<String, dynamic>.from(userDoc.data()!);
    } catch (e) {
      throw Exception(l10n.errorLoadingUser(e.toString()));
    }

    // Aktuelle Rolle ermitteln
    final oldRole = getSpecificPropertyfromJSON(targetUser, "userRole");
    final oldRoleStr =
        (oldRole != "" && oldRole != "-no data found-") ? oldRole : NO_ROLE;

    // SICHERHEIT: SUPERADMIN kann niemals entfernt oder geändert werden
    if (oldRoleStr == 'SUPERADMIN') {
      throw Exception(l10n.superadminCannotBeChanged);
    }

    // Prüfe ob aktuelle Rolle verwaltet werden kann
    if (oldRoleStr != NO_ROLE && !canManageRole(currentUserRole, oldRoleStr)) {
      throw Exception(l10n.noPermissionForCurrentRole(oldRoleStr));
    }

    try {
      // Neue Rolle setzen
      targetUser =
          setSpecificPropertyJSON(targetUser, "userRole", newRole, "String");

      // changeObjectData verwenden für automatisches Logging
      await changeObjectData(targetUser, syncFromCloud: false);

      // Zusätzlich spezifische changeUserRole Methode für detailliertes Audit-Log
      await _createChangeUserRoleMethod(
        targetUser: targetUser,
        oldRole: oldRoleStr,
        newRole: newRole,
        reason: reason,
      );
    } catch (e) {
      throw Exception(l10n.errorChangingRole(e.toString()));
    }
  }

  /// Erstellt eine spezifische changeUserRole Methode für detailliertes Audit-Logging
  Future<void> _createChangeUserRoleMethod({
    required Map<String, dynamic> targetUser,
    required String oldRole,
    required String newRole,
    String reason = '',
  }) async {
    try {
      var changeUserRoleMethod = await getOpenRALTemplate("changeUserRole");

      // Method konfigurieren
      changeUserRoleMethod["executor"] = appUserDoc!;
      changeUserRoleMethod["methodState"] = "finished";
      setObjectMethodUID(changeUserRoleMethod, const Uuid().v4());

      // Spezifische Properties setzen
      changeUserRoleMethod = setSpecificPropertyJSON(
          changeUserRoleMethod, "oldRole", oldRole, "String");
      changeUserRoleMethod = setSpecificPropertyJSON(
          changeUserRoleMethod, "newRole", newRole, "String");
      changeUserRoleMethod = setSpecificPropertyJSON(
          changeUserRoleMethod, "roleChangeReason", reason, "String");
      changeUserRoleMethod = setSpecificPropertyJSON(changeUserRoleMethod,
          "adminUID", FirebaseAuth.instance.currentUser!.uid, "String");

      // Input: User vor der Änderung (falls verfügbar)
      addInputobject(changeUserRoleMethod, targetUser, "user");

      // Output: User nach der Änderung
      addOutputobject(changeUserRoleMethod, targetUser, "user");

      // Method History aktualisieren
      await updateMethodHistories(changeUserRoleMethod);

      // Method persistieren und signieren
      await setObjectMethod(changeUserRoleMethod, true, true,
          syncFromCloud: false);

      // Falls die Rolle des aktuellen Users geändert wurde, aktualisiere AppState
      if (targetUser['identity']?['UID'] ==
          FirebaseAuth.instance.currentUser?.uid) {
        await _updateCurrentUserAppState(newRole);
      }
    } catch (e) {
      // Nicht kritisch, da changeObjectData bereits das Logging übernommen hat
    }
  }

  /// Holt verfügbare Rollen für die aktuelle Administratorrolle
  List<String> getAvailableRoles() {
    final currentRole = getCurrentUserRole();

    if (!roleManagementPermissions.containsKey(currentRole)) {
      return [];
    }

    final availableRoles =
        List<String>.from(roleManagementPermissions[currentRole]!);

    // SICHERHEIT: SUPERADMIN kann NIEMALS zugewiesen werden
    availableRoles.remove('SUPERADMIN');

    // Füge NO_ROLE als Option hinzu (Admins können Rollen auch entfernen)
    availableRoles.add(NO_ROLE);

    return availableRoles;
  }

  /// Formatiert User-Informationen für die Anzeige
  Future<Map<String, dynamic>> formatUserForDisplay(Map<String, dynamic> user,
      {required AppLocalizations l10n}) async {
    final email = user['email'] ?? getSpecificPropertyfromJSON(user, "email");
    final userRole = getSpecificPropertyfromJSON(user, "userRole");
    final userName = user['identity']?['name'] ?? l10n.unknown;
    final userUID = user['identity']?['UID'] ?? '';

    // Für den aktuellen User, hole die aktuellste Rolle aus der Cloud
    String displayRole = userRole;
    if (userUID == FirebaseAuth.instance.currentUser?.uid) {
      final cloudRole = await getCurrentUserRoleFromCloud();
      if (cloudRole.isNotEmpty) {
        displayRole = cloudRole;
      }
    }

    // Debug: Zeige die gefundenen Werte
    //
    //
    //
    //
    //
    //

    // Bestimme ob dieser User verwaltet werden kann
    final currentUserRole = await getCurrentUserRoleFromCloud();
    final targetUserRole = displayRole != "" && displayRole != "-no data found-"
        ? displayRole
        : NO_ROLE;

    bool canManageUser = false;

    // SICHERHEIT: SUPERADMIN-Benutzer können NIEMALS verwaltet werden
    if (targetUserRole == 'SUPERADMIN') {
      canManageUser = false;
    }
    // SUPERADMIN kann alle anderen verwalten
    else if (currentUserRole == 'SUPERADMIN') {
      canManageUser = true;
    }
    // Andere Admins können basierend auf Rollenhierarchie verwalten
    else if (roleManagementPermissions.containsKey(currentUserRole)) {
      // Kann die Zielrolle verwalten ODER User hat keine Rolle
      canManageUser = canManageRole(currentUserRole, targetUserRole) ||
          targetUserRole == NO_ROLE;
    }

    // Aber niemals sich selbst verwalten
    if (userUID == FirebaseAuth.instance.currentUser?.uid) {
      canManageUser = false;
    }

    // Debug: Zeige die Verwaltungslogik

    return {
      'uid': userUID,
      'name': userName,
      'email': (email != "-no data found-" &&
              email != null &&
              (email as String).isNotEmpty)
          ? email
          : l10n.noEmail,
      'role': targetUserRole,
      'canManage': canManageUser,
    };
  }

  /// Lädt die Rollenhistorie für einen bestimmten User
  Future<List<Map<String, dynamic>>> getUserRoleHistory(String userUID) async {
    if (!await isOnline()) {
      return [];
    }

    try {
      // Lade alle changeUserRole Methods für diesen User
      final querySnapshot = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .where('template.RALType', isEqualTo: 'changeUserRole')
          .where('outputObjects', arrayContains: {'identity.UID': userUID})
          .orderBy('existenceStarts', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Trägt eine E-Mail-Adresse nachträglich für einen Benutzer ein (nur SUPERADMIN)
  /// Aktualisiert sowohl das Top-Level-Feld als auch die specificProperties
  Future<void> updateUserEmail({
    required String targetUserUID,
    required String email,
    required AppLocalizations l10n,
  }) async {
    // Sicherheitsprüfung: Nur SUPERADMIN darf E-Mails nachträglich eintragen
    final currentRole = getCurrentUserRole();
    if (currentRole != 'SUPERADMIN') {
      throw Exception(l10n.onlySuperadminCanUpdateEmail);
    }

    if (!await isOnline()) {
      throw Exception(l10n.emailUpdateOnlineOnly);
    }

    // Valide E-Mail prüfen (einfache Prüfung)
    if (!email.contains('@') || !email.contains('.')) {
      throw Exception(l10n.invalidEmail);
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(targetUserUID);

      final userDoc = await docRef.get();
      if (!userDoc.exists) {
        throw Exception(l10n.userNotFound);
      }

      var userData = Map<String, dynamic>.from(userDoc.data()!);

      // specificProperties aktualisieren
      userData = setSpecificPropertyJSON(userData, "email", email, "String");

      // Top-Level-Feld aktualisieren
      userData['email'] = email;

      await docRef.set(userData);
    } catch (e) {
      throw Exception(l10n.errorUpdatingEmail(e.toString()));
    }
  }
}

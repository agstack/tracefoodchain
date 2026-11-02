import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/models/user_scope.dart';
import 'package:trace_foodchain_app/repositories/initial_data.dart';
import 'package:trace_foodchain_app/services/country_config_service.dart';
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
    'countryCoordinator': 400,
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
      'countryCoordinator',
      'registrarCoordinator',
      'Trader',
      'Farmer',
      'Processor',
      'Importer',
      'registrar'
    ],
    'tfcAdmin': [
      'countryCoordinator',
      'registrarCoordinator',
      'Trader',
      'Farmer',
      'Processor',
      'Importer',
      'registrar'
    ],
    'countryCoordinator': [
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

  /// Rollen ohne Gebietsbeschränkung.
  static const Set<String> globalRoles = {'SUPERADMIN', 'tfcAdmin'};

  /// Rollen, die ein zugewiesenes Gebiet brauchen.
  static const Set<String> scopedRoles = {
    'countryCoordinator',
    'registrarCoordinator',
    'registrar',
  };

  String? _resolveCountry(String? stored) =>
      countryConfigService.resolve(stored)?.code;

  /// Gebiet eines Nutzerobjekts - zugewiesen oder, ohne Zuweisung, das Land
  /// aus der Adresse.
  UserScope scopeOf(Map<String, dynamic> user) =>
      UserScope.ofUser(user, resolveCountry: _resolveCountry);

  /// Gebiet, in dem der angemeldete Nutzer verwalten darf; null heißt
  /// unbeschränkt. Zählt nur die ausdrückliche Zuweisung, nie die Adresse.
  UserScope? currentUserScope() {
    if (globalRoles.contains(getCurrentUserRole())) return null;
    if (appUserDoc == null) return UserScope.empty;
    return UserScope.fromJson(
        UserScope.rawProperty(appUserDoc!, UserScope.propertyKey));
  }

  /// Ob [user] im Gebiet des angemeldeten Nutzers liegt.
  bool canSeeUser(Map<String, dynamic> user) {
    final own = currentUserScope();
    return own == null || own.overlaps(scopeOf(user));
  }

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
        // Maßgeblich ist die Rolle im Token (von manageUser gesetzt); das
        // Nutzerobjekt kann jeder Client beschreiben. Ohne Claim - vor der
        // Migration - zählt weiter das Nutzerobjekt.
        final finalRole = await _roleFromToken() ??
            ((role != "" && role != "-no data found-") ? role : '');
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
          _adoptOwnAssignment(userData);
        }

        return finalRole;
      } else {
        return getCurrentUserRole(); // Fallback auf lokale Rolle
      }
    } catch (e) {
      return getCurrentUserRole(); // Fallback auf lokale Rolle
    }
  }

  static DateTime? _tokenRefreshedAt;

  /// Rolle aus den Custom Claims des eigenen Tokens, null ohne Claim.
  ///
  /// Das Token wird höchstens alle fünf Minuten neu geholt - eine neue Rolle
  /// steht erst in einem frisch ausgestellten Token.
  Future<String?> _roleFromToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final refresh = _tokenRefreshedAt == null ||
          DateTime.now().difference(_tokenRefreshedAt!) >
              const Duration(minutes: 5);
      final token = await user.getIdTokenResult(refresh);
      if (refresh) _tokenRefreshedAt = DateTime.now();
      final role = token.claims?['tfcRole'];
      return role is String && role.isNotEmpty ? role : null;
    } catch (e) {
      debugPrint('Role claim not readable: $e');
      return null;
    }
  }

  /// Übernimmt Gebiet und Team aus der Cloud-Fassung des eigenen
  /// Nutzerobjekts - gesetzt werden sie von Koordinatoren auf anderen
  /// Geräten. Die lokale Kopie wird mitgeschrieben, damit Registrare ihr
  /// Gebiet auch ohne Netz kennen.
  void _adoptOwnAssignment(Map<String, dynamic> cloudUser) {
    if (appUserDoc == null) return;
    var changed = false;
    for (final (key, unit) in [
      (UserScope.propertyKey, 'json'),
      (UserScope.coordinatorKey, 'String'),
    ]) {
      final cloudValue = UserScope.rawProperty(cloudUser, key);
      if (cloudValue == null) continue;
      final localValue = UserScope.rawProperty(appUserDoc!, key);
      if (jsonEncode(cloudValue) == jsonEncode(localValue)) continue;
      appUserDoc = setSpecificPropertyJSON(appUserDoc!, key, cloudValue, unit);
      changed = true;
    }

    final uid = appUserDoc!['identity']?['UID']?.toString() ?? '';
    if (changed && uid.isNotEmpty && localStorage != null) {
      unawaited(localStorage!.put(uid, appUserDoc!));
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
      // Andere Admins: Nur User deren Rollen sie verwalten können oder rollenlose User,
      // und - bei Koordinatoren - nur im eigenen Gebiet
      else if (currentRole != 'SUPERADMIN') {
        if ((effectiveRole == NO_ROLE ||
                canManageRole(currentRole, effectiveRole)) &&
            canSeeUser(user)) {
          managedUsers.add(user);
        }
      }
    }

    return managedUsers;
  }

  /// Ändert die Rolle eines Users über changeObjectData (mit automatischem Logging)
  ///
  /// [scope] und [coordinatorUID] setzen Gebiet und Team gleich mit;
  /// null lässt den bisherigen Wert stehen.
  Future<void> changeUserRole({
    required String targetUserUID,
    required String newRole,
    required AppLocalizations l10n,
    String reason = '',
    UserScope? scope,
    String? coordinatorUID,
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
      final result = await _callManageUser(
        targetUserUID: targetUserUID,
        role: newRole,
        scope: scope,
        coordinatorUID: coordinatorUID,
        l10n: l10n,
      );
      final updatedUser = await _reloadUser(targetUserUID) ?? targetUser;

      // Zusätzlich spezifische changeUserRole Methode für detailliertes Audit-Log
      await _createChangeUserRoleMethod(
        targetUser: updatedUser,
        oldRole: oldRoleStr,
        newRole: newRole,
        reason: reason,
      );
      if (result.assignmentChanged) {
        await _createChangeUserAssignmentMethod(
          oldUser: targetUser,
          newUser: updatedUser,
          result: result,
          reason: reason,
        );
      }
    } on ManageUserRejection {
      rethrow;
    } catch (e) {
      throw Exception(l10n.errorChangingRole(e.toString()));
    }
  }

  /// Ändert nur Gebiet und/oder Team eines Nutzers, die Rolle bleibt.
  /// null lässt den bisherigen Wert stehen.
  Future<void> changeUserAssignment({
    required String targetUserUID,
    required AppLocalizations l10n,
    UserScope? scope,
    String? coordinatorUID,
    String reason = '',
  }) async {
    final targetUser = await _loadManageableUser(targetUserUID, l10n);
    await _applyAssignment(
      targetUser: targetUser,
      scope: scope,
      coordinatorUID: coordinatorUID,
      reason: reason,
      l10n: l10n,
    );
  }

  /// Holt einen Registrar ins eigene Team (Registrar Coordinator).
  ///
  /// Hat er noch kein zugewiesenes Gebiet, bekommt er den Teil des eigenen
  /// Gebiets, der in seinem Land liegt.
  Future<void> addToMyTeam({
    required String targetUserUID,
    required AppLocalizations l10n,
  }) async {
    final myUID = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetUser = await _loadManageableUser(targetUserUID, l10n);

    UserScope? scope;
    if (!UserScope.isAssigned(targetUser)) {
      final countries = scopeOf(targetUser).countries;
      final own = currentUserScope() ?? UserScope.empty;
      scope = UserScope(
          own.entries.where((e) => countries.contains(e.country)).toList());
    }

    await _applyAssignment(
      targetUser: targetUser,
      scope: scope,
      coordinatorUID: myUID,
      reason: '',
      l10n: l10n,
    );
  }

  /// Lädt einen Nutzer aus der Cloud und prüft, ob der angemeldete Nutzer
  /// ihn verwalten darf (Rolle, Gebiet, Team). Nur für eine schnelle
  /// Rückmeldung - entschieden wird in manageUser.
  Future<Map<String, dynamic>> _loadManageableUser(
      String targetUserUID, AppLocalizations l10n) async {
    if (!await isOnline()) {
      throw Exception(l10n.userManagementOnlineOnly);
    }

    final targetUser = await _reloadUser(targetUserUID);
    if (targetUser == null) {
      throw Exception(l10n.userNotFound);
    }

    final display = await formatUserForDisplay(targetUser, l10n: l10n);
    if (display['canManage'] != true) {
      throw Exception(l10n.noPermissionForCurrentRole(display['role']));
    }
    return targetUser;
  }

  Future<Map<String, dynamic>?> _reloadUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('TFC_objects')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? Map<String, dynamic>.from(doc.data()!) : null;
  }

  Future<void> _applyAssignment({
    required Map<String, dynamic> targetUser,
    required UserScope? scope,
    required String? coordinatorUID,
    required String reason,
    required AppLocalizations l10n,
  }) async {
    final uid = targetUser['identity']['UID'] as String;
    final result = await _callManageUser(
      targetUserUID: uid,
      scope: scope,
      coordinatorUID: coordinatorUID,
      l10n: l10n,
    );
    if (!result.assignmentChanged) return;

    final updatedUser = await _reloadUser(uid) ?? targetUser;
    await _createChangeUserAssignmentMethod(
      oldUser: targetUser,
      newUser: updatedUser,
      result: result,
      reason: reason,
    );
  }

  static const String _manageUserUrl =
      'https://europe-west3-tracefoodchain.cloudfunctions.net/manageUser';

  /// Ändert Rolle, Gebiet und/oder Team über die Cloud Function manageUser.
  ///
  /// Nur sie prüft verbindlich und setzt die Custom Claims; die Prüfungen in
  /// der App dienen allein der schnellen Rückmeldung. null lässt den
  /// bisherigen Wert stehen.
  Future<_ManageUserResult> _callManageUser({
    required String targetUserUID,
    required AppLocalizations l10n,
    String? role,
    UserScope? scope,
    String? coordinatorUID,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw Exception(l10n.noValidAdminRole);
    }

    final response = await http
        .post(
          Uri.parse(_manageUserUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'targetUid': targetUserUID,
            if (role != null) 'role': role,
            if (scope != null) 'scope': scope.toJson(),
            if (coordinatorUID != null) 'coordinatorUid': coordinatorUID,
          }),
        )
        .timeout(const Duration(seconds: 30));

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 200 && body is Map && body['result'] is Map) {
      return _ManageUserResult.fromJson(body['result'] as Map);
    }
    if (response.statusCode == 403 && body is Map && body['code'] is String) {
      final details = body['details'] is Map ? body['details'] as Map : {};
      throw ManageUserRejection(
          _rejectionMessage(body['code'] as String, details, l10n));
    }
    throw Exception(
        l10n.errorChangingRole('${response.statusCode}: ${response.body}'));
  }

  String _rejectionMessage(
      String code, Map<dynamic, dynamic> details, AppLocalizations l10n) {
    return switch (code) {
      'notAuthorized' => l10n.manageUserNotAuthorized,
      'cannotManageSelf' => l10n.manageUserCannotManageSelf,
      'superadminImmutable' => l10n.superadminCannotBeChanged,
      'roleNotManageable' ||
      'invalidRole' =>
        l10n.noPermissionForRole(details['role']?.toString() ?? ''),
      'targetNotVisible' => l10n.manageUserOutsideTerritory,
      'otherTeam' => l10n.manageUserOtherTeam,
      'scopeRequired' => l10n.scopeRequired,
      'countryInactive' =>
        l10n.scopeCountryInactive(details['country']?.toString() ?? ''),
      'scopeOutsideOwn' => l10n.scopeOutsideOwn,
      'onlyOwnTeam' => l10n.scopeOnlyOwnTeam,
      'coordinatorMismatch' => l10n.scopeCoordinatorMismatch,
      _ => code,
    };
  }

  /// Signierte changeUserAssignment-Methode: dokumentiert die Änderung,
  /// statt bestehende Methoden oder Objekte stillschweigend zu verändern.
  Future<void> _createChangeUserAssignmentMethod({
    required Map<String, dynamic> oldUser,
    required Map<String, dynamic> newUser,
    required _ManageUserResult result,
    required String reason,
  }) async {
    try {
      var method = await getOpenRALTemplate("changeUserAssignment");
      if (method.isEmpty) {
        // Hive-Box stammt aus einer Version ohne dieses Template.
        method = deepCopyMap(initialMethodTemplateChangeUserAssignment);
      }

      method["executor"] = appUserDoc!;
      method["methodState"] = "finished";
      setObjectMethodUID(method, const Uuid().v4());

      method = setSpecificPropertyJSON(
          method, "oldScope", result.oldScope.toJson(), "json");
      method = setSpecificPropertyJSON(
          method, "newScope", result.newScope.toJson(), "json");
      method = setSpecificPropertyJSON(
          method, "oldCoordinatorUID", result.oldCoordinator, "String");
      method = setSpecificPropertyJSON(
          method, "newCoordinatorUID", result.newCoordinator, "String");
      method = setSpecificPropertyJSON(
          method, "assignmentChangeReason", reason, "String");
      method = setSpecificPropertyJSON(method, "adminUID",
          FirebaseAuth.instance.currentUser!.uid, "String");

      addInputobject(method, oldUser, "user");
      addOutputobject(method, newUser, "user");

      await updateMethodHistories(method);
      await setObjectMethod(method, true, true, syncFromCloud: false);
    } catch (e) {
      // Die Änderung selbst ist gespeichert; nur der Audit-Eintrag fehlt.
      debugPrint('changeUserAssignment: audit method not created: $e');
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
      {required AppLocalizations l10n, String? currentUserRole}) async {
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
    final resolvedCurrentUserRole =
        currentUserRole ?? await getCurrentUserRoleFromCloud();
    final targetUserRole = displayRole != "" && displayRole != "-no data found-"
        ? displayRole
        : NO_ROLE;

    bool canManageUser = false;

    // SICHERHEIT: SUPERADMIN-Benutzer können NIEMALS verwaltet werden
    if (targetUserRole == 'SUPERADMIN') {
      canManageUser = false;
    }
    // SUPERADMIN kann alle anderen verwalten
    else if (resolvedCurrentUserRole == 'SUPERADMIN') {
      canManageUser = true;
    }
    // Andere Admins können basierend auf Rollenhierarchie verwalten
    else if (roleManagementPermissions.containsKey(resolvedCurrentUserRole)) {
      // Kann die Zielrolle verwalten ODER User hat keine Rolle
      canManageUser = (canManageRole(resolvedCurrentUserRole, targetUserRole) ||
              targetUserRole == NO_ROLE) &&
          canSeeUser(user);
    }

    // Registrar Coordinators verwalten keine Registrare aus fremden Teams -
    // umhängen darf nur der Country Coordinator.
    final coordinatorUID = UserScope.coordinatorOf(user);
    final myUID = FirebaseAuth.instance.currentUser?.uid;
    if (resolvedCurrentUserRole == 'registrarCoordinator' &&
        coordinatorUID.isNotEmpty &&
        coordinatorUID != myUID) {
      canManageUser = false;
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
      'scope': scopeOf(user),
      'scopeAssigned': UserScope.isAssigned(user),
      'coordinatorUID': coordinatorUID,
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

/// Abgelehnte Änderung - die Meldung ist bereits übersetzt.
class ManageUserRejection implements Exception {
  ManageUserRejection(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Alter und neuer Stand nach manageUser.
class _ManageUserResult {
  const _ManageUserResult({
    required this.oldRole,
    required this.newRole,
    required this.oldScope,
    required this.newScope,
    required this.oldCoordinator,
    required this.newCoordinator,
  });

  factory _ManageUserResult.fromJson(Map<dynamic, dynamic> json) =>
      _ManageUserResult(
        oldRole: json['oldRole']?.toString() ?? '',
        newRole: json['newRole']?.toString() ?? '',
        oldScope: UserScope.fromJson(json['oldScope']),
        newScope: UserScope.fromJson(json['newScope']),
        oldCoordinator: json['oldCoordinatorUid']?.toString() ?? '',
        newCoordinator: json['newCoordinatorUid']?.toString() ?? '',
      );

  final String oldRole;
  final String newRole;
  final UserScope oldScope;
  final UserScope newScope;
  final String oldCoordinator;
  final String newCoordinator;

  bool get assignmentChanged =>
      oldScope != newScope || oldCoordinator != newCoordinator;
}

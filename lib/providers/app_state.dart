import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';

class AppState extends ChangeNotifier {
  String? _userRole;
  String? _userId;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isEmailVerified = false;
  bool _hasCamera = false;
  bool _hasNFC = false;
  bool _hasGPS = false;

  String? get userRole => _userRole;
  String? get userId => _userId;
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get isEmailVerified => _isEmailVerified;
  bool get hasCamera => _hasCamera;
  bool get hasNFC => _hasNFC;
  bool get hasGPS => _hasGPS;

  // Initialize locale as null to use system default
  Locale? _locale = window.locale; // Initialize with system locale
  Locale? get locale => _locale;

  // Bevorzugte Flächeneinheit (symbol, z.B. "ha" oder "mz")
  String _preferredAreaUnitSymbol = 'ha';
  String get preferredAreaUnitSymbol => _preferredAreaUnitSymbol;

  Future<void> setPreferredAreaUnit(String symbol) async {
    _preferredAreaUnitSymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredAreaUnit', symbol);
    notifyListeners();
  }

  Future<void> loadAreaUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _preferredAreaUnitSymbol = prefs.getString('preferredAreaUnit') ?? 'ha';
  }

  void setLocale(Locale? newLocale) {
    _locale = newLocale;
    notifyListeners();
  }

  Future<void> initializeApp() async {
    // Initialize with system locale, but ensure it's supported
    final systemLocale = window.locale;
    final languageCode = systemLocale.languageCode;

    // Check if the system language is supported, otherwise default to English
    if (['en', 'es', 'de', 'fr'].contains(languageCode)) {
      _locale = Locale(languageCode);
    } else {
      _locale = const Locale('en');
    }

    // Lade gespeicherte Flächeneinheit-Präferenz
    await loadAreaUnitPreference();

    notifyListeners();
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  void setEmailVerified(bool value) {
    _isEmailVerified = value;
    notifyListeners();
  }

  Future<void> setUserRole(String role) async {
    print('👤 [AppState] setUserRole aufgerufen');
    print('👤 [AppState] - Alte Rolle: $_userRole');
    print('👤 [AppState] - Neue Rolle: $role');
    _userRole = role;
    notifyListeners();
    print('👤 [AppState] - Rolle gesetzt und notifyListeners() aufgerufen');
  }

  void setUserId(String id) {
    _userId = id;
    notifyListeners();
  }

  void setConnected(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  void startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((dynamic result) {
      if (result is List<ConnectivityResult>) {
        _updateConnectionStatus(result);
      } else if (result is ConnectivityResult) {
        _updateConnectionStatus([result]);
      } else {
        setConnected(false);
      }
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (results.isEmpty) {
      setConnected(false);
    } else {
      // Consider the device connected if any result is not 'none'
      bool oldConnectionState = _isConnected;

      bool hasConnection =
          results.any((result) => result != ConnectivityResult.none);
      setConnected(hasConnection);
      if ((oldConnectionState == false) && (hasConnection == true)) {
        //If state changes from offline to online, sync data to cloud!
        isSyncing.value = true;

        final databaseHelper = DatabaseHelper();
        // Upload pending photos first to avoid internal loops
        await cloudSyncService.uploadPendingPhotos();

        for (final cloudKey in cloudConnectors.keys) {
          if (cloudKey != "open-ral.io") {
            syncStatusNotifier.value = "Synchronisierung mit $cloudKey";
            await cloudSyncService.syncMethods(cloudKey);
          }
        }
        //Repaint Container list
        repaintContainerList.value = true;
        //Repaint Inbox count
        if (FirebaseAuth.instance.currentUser != null) {
          String ownerUID = FirebaseAuth.instance.currentUser!.uid;
          inbox = await databaseHelper.getInboxItems(ownerUID);
          inboxCount.value = inbox.length;
        }

        isSyncing.value = false;
        syncStatusNotifier.value = null;
      }
    }
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    if (userId != null) {
      if (FirebaseAuth.instance.currentUser == null) {
        signOut();
        //In this case, we should make sure that old data is kept on the device and not deleted
        //However, all old processes will keep the old user as executor and owner and might need manual assignment later
      } else {
        _isAuthenticated = true;
        _isEmailVerified =
            FirebaseAuth.instance.currentUser?.emailVerified ?? false;

        // KRITISCH: Bei Reload muss der user-spezifische localStorage initialisiert werden
        if (!isLocalStorageInitialized()) {
          await initializeUserLocalStorage(
              FirebaseAuth.instance.currentUser!.uid);
        }

        // Lade appUserDoc aus localStorage
        if (isLocalStorageInitialized() && appUserDoc == null) {
          for (var doc in localStorage!.values) {
            if (doc['template'] != null &&
                doc['template']["RALType"] == "human") {
              final doc2 = Map<String, dynamic>.from(doc);
              if (getObjectMethodUID(doc2) ==
                  FirebaseAuth.instance.currentUser!.uid) {
                appUserDoc = doc2;
                break;
              }
            }
          }
        }

        // Lade Benutzerrolle
        if (appUserDoc != null) {
          print('🔍 [AppState.checkAuthStatus] Lade Benutzerrolle');
          print(
              '🔍 [AppState.checkAuthStatus] - appUserDoc vorhanden: ${appUserDoc != null}');
          print('🔍 [AppState.checkAuthStatus] - isConnected: $_isConnected');
          String finalRole = '';

          if (_isConnected) {
            try {
              // Hole die aktuellste Rolle aus der Cloud
              final roleService = RoleManagementService();
              final cloudRole = await roleService.getCurrentUserRoleFromCloud();

              if (cloudRole.isNotEmpty) {
                print(
                    '✅ [AppState.checkAuthStatus] Cloud-Rolle gefunden: $cloudRole');
                finalRole = cloudRole;

                // Aktualisiere das lokale appUserDoc mit der Cloud-Rolle
                if (cloudRole !=
                    getSpecificPropertyfromJSON(appUserDoc!, "userRole")) {
                  print(
                      '🔄 [AppState.checkAuthStatus] Aktualisiere lokale Rolle von ${getSpecificPropertyfromJSON(appUserDoc!, "userRole")} auf $cloudRole');
                  appUserDoc = setSpecificPropertyJSON(
                      appUserDoc!, "userRole", cloudRole, "String");
                }
              } else {
                // Fallback auf lokale Rolle
                print(
                    '⚠️ [AppState.checkAuthStatus] Keine Cloud-Rolle, nutze lokale Rolle');
                final localRole =
                    getSpecificPropertyfromJSON(appUserDoc!, "userRole");
                finalRole = (localRole != "" && localRole != "-no data found-")
                    ? localRole
                    : '';
                print('📋 [AppState.checkAuthStatus] Lokale Rolle: $finalRole');
              }
            } catch (e) {
              final localRole =
                  getSpecificPropertyfromJSON(appUserDoc!, "userRole");
              finalRole = (localRole != "" && localRole != "-no data found-")
                  ? localRole
                  : '';
            }
          } else {
            // Offline - nutze lokale Rolle
            print('📴 [AppState.checkAuthStatus] Offline - nutze lokale Rolle');
            final localRole =
                getSpecificPropertyfromJSON(appUserDoc!, "userRole");
            finalRole = (localRole != "" && localRole != "-no data found-")
                ? localRole
                : '';
            print(
                '📋 [AppState.checkAuthStatus] Lokale Rolle (offline): $finalRole');
          }

          if (finalRole.isNotEmpty) {
            print(
                '✅ [AppState.checkAuthStatus] Setze finale Rolle: $finalRole');
            await setUserRole(finalRole);
          } else {
            print('❌ [AppState.checkAuthStatus] KEINE Rolle gefunden!');
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    // KRITISCH: Schließe die benutzerspezifische Hive-Datenbank
    await closeUserLocalStorage();

    _isAuthenticated = false;
    _isEmailVerified = false;
    notifyListeners();
  }

  void setHasCamera(bool hasCamera) {
    _hasCamera = hasCamera;
    notifyListeners();
  }

  void setHasNFC(bool hasNFC) {
    _hasNFC = hasNFC;
    notifyListeners();
  }

  void setHasGPS(bool hasGPS) {
    //ToDo: make work
    _hasGPS = hasGPS;
    notifyListeners();
  }
}

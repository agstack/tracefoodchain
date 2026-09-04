import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/background_sync_service.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/services/sync_settings_service.dart';

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
    final savedUnit = prefs.getString('preferredAreaUnit');
    if (savedUnit != null && savedUnit.isNotEmpty) {
      _preferredAreaUnitSymbol = savedUnit;
      return;
    }

    final availableUnits = getAreaUnits(country);
    final hasMzUnit = availableUnits.any((u) => u['symbol'] == 'mz');
    final isSpanishLocale = _locale?.languageCode == 'es';

    if (isSpanishLocale && hasMzUnit) {
      _preferredAreaUnitSymbol = 'mz';
      return;
    }

    _preferredAreaUnitSymbol = availableUnits.isNotEmpty
        ? (availableUnits.first['symbol'] as String)
        : 'ha';
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

  //! ---------------------------------------------- WP A2: upload pause switch

  /// True while the user has suspended all cloud traffic. Local capture keeps
  /// working and items stay flagged `needsSync`.
  bool get uploadPaused => syncSettings.isUploadPaused;

  ValueListenable<bool> get uploadPausedListenable => syncSettings.uploadPaused;
  ValueListenable<int> get pendingItemCountListenable =>
      syncSettings.pendingItemCount;
  ValueListenable<DateTime?> get lastSuccessfulSyncListenable =>
      syncSettings.lastSuccessfulSync;

  /// Pauses or resumes cloud traffic. Resuming immediately kicks off a sync so
  /// the user does not have to wait for the next timer tick.
  Future<void> setUploadPaused(bool paused) async {
    await syncSettings.setUploadPaused(paused);
    notifyListeners();
    if (!paused && _isConnected && _isAuthenticated) {
      await syncNow();
    } else {
      refreshPendingItemCount();
    }
  }

  /// "Sync now" - the manual trigger behind the button.
  ///
  /// Returns what actually happened so the caller can tell the user; a button
  /// press that silently does nothing is indistinguishable from a broken app.
  /// [ignorePause] defaults to true: this is the deliberate trigger the pause
  /// switch exists for - pausing stops the automatic traffic so the user can
  /// pick the moment, it does not lock syncing away.
  Future<SyncSummary> syncNow({
    bool force = true,
    bool ignorePause = true,
  }) async {
    if (!_isConnected || !_isAuthenticated) return const SyncSummary();

    isSyncing.value = true;
    String currentCloud = '';
    try {
      final summary = await runFullSync(
        syncFromCloud: !isWebLandscape,
        force: force,
        ignorePause: ignorePause,
        onStatus: (cloudKey) {
          currentCloud = cloudKey;
          syncStatusNotifier.value = "Synchronisierung mit $cloudKey";
        },
        onDetail: (detail) => syncStatusNotifier.value =
            "Synchronisierung mit $currentCloud $detail",
      );
      repaintContainerList.value = true;
      if (FirebaseAuth.instance.currentUser != null) {
        final databaseHelper = DatabaseHelper();
        inbox = await databaseHelper
            .getInboxItems(FirebaseAuth.instance.currentUser!.uid);
        inboxCount.value = inbox.length;
      }
      return summary;
    } finally {
      refreshPendingItemCount();
      isSyncing.value = false;
      syncStatusNotifier.value = null;
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
        // A public key that could not be registered at app start (offline
        // launch) must be repaired BEFORE anything is pushed - otherwise the
        // cloud rejects every signature. This runs regardless of the upload
        // pause switch because it uploads no user data.
        if (_isAuthenticated && keyManager.publicKeyRegistrationPending) {
          final registered =
              await keyManager.retryPendingPublicKeyRegistration();
          secureCommunicationEnabled = true;
          debugPrint('AppState: deferred public key registration retried,'
              ' success: $registered');
        }

        //If state changes from offline to online, sync data to cloud!
        //WP A2: unless the user has deliberately paused uploads.
        if (syncSettings.isUploadPaused) {
          debugPrint(
              'Connectivity restored, but uploads are paused - staying local');
          return;
        }
        isSyncing.value = true;

        final databaseHelper = DatabaseHelper();
        // Upload pending photos first to avoid internal loops
        await runFullSync(
          syncFromCloud: !isWebLandscape,
          onStatus: (cloudKey) =>
              syncStatusNotifier.value = "Synchronisierung mit $cloudKey",
        );
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

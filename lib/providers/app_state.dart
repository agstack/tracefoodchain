import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';

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
    _userRole = role;
    notifyListeners();
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
        final databaseHelper = DatabaseHelper();
        for (final cloudKey in cloudConnectors.keys) {
          if (cloudKey != "open-ral.io") {
            
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

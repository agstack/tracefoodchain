import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/fade_route.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/screens/sign_up_screen.dart';
import 'package:trace_foodchain_app/screens/home_screen.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:trace_foodchain_app/widgets/data_loading_indicator.dart';
import 'package:trace_foodchain_app/widgets/status_bar.dart';
import 'package:trace_foodchain_app/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/scheduler.dart'; // Falls benötigt
import '../services/get_device_id.dart';
import '../widgets/safe_asset_widgets.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';

bool canResendEmail = true;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _disposed = false;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();

    // Debug: Asset-Verfügbarkeit prüfen
    _checkAssetAvailability();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    _initializeApp();
  }

  Future<void> _checkAssetAvailability() async {
    try {
      await rootBundle.load('assets/images/background.png');
    } catch (e) {
      // Asset nicht verfügbar
    }

    try {
      await rootBundle.load('assets/images/diasca_logo.png');
    } catch (e) {
      // Asset nicht verfügbar
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final appState = Provider.of<AppState>(context, listen: false);

    await Future.delayed(_controller.duration ?? Duration.zero);

    if (_disposed) return;

    // Check internet connectivity
    dynamic connectivityResult;
    try {
      // await (Connectivity().checkConnectivity())
      //     .then((connectivityResult) async {
      //   appState.setConnected(connectivityResult != ConnectivityResult.none);
      // Check authentication status
      await appState.checkAuthStatus().then((onValue) async {
        if (appState.isAuthenticated) {
          //* AUTHENTICATED
          if (appState.isEmailVerified) {
            //* VERIFIED
            // Führe immer die vollständige Initialisierung durch
            await _navigateToNextScreen();
          } else {
            //*NOT VERIFIED
            // Show email verification overlay
            _showEmailVerificationOverlay();
          }
        } else {
          //* NOT AUTHENTICATED YET
          if (!appState.isConnected) {
            await fshowInfoDialog(context,
                "To activate the app the first time, please connect to the internet for authentication!");
            //ToDo You might want to add a retry mechanism here
            return;
          }
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthScreen()));
        }
        // });
      });
    } catch (e) {
      // Fehler aufgetreten
    }
  }

  void _showEmailVerificationOverlay() {
    if (_disposed) return;

    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerification();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        if (l10n == null) {
          return AlertDialog(
            title: const Text("Email Verification"),
            content: const SizedBox(
                height: 150,
                child: Center(
                    child: Text(
                        "Localization Error - please check main.dart configuration"))),
            actions: <Widget>[
              TextButton(
                child: const Text("Resend Email"),
                onPressed: () async {
                  await sendVerificationEmail();
                },
              ),
              TextButton(
                child: const Text("Sign Out"),
                onPressed: () async {
                  _signOut();
                },
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(l10n.emailVerification),
          content: SizedBox(
              height: 150,
              child: DataLoadingIndicator(
                  text:
                      "${FirebaseAuth.instance.currentUser!.email} \n ${l10n.waitingForEmailVerification}",
                  textColor: Colors.black54,
                  spinnerColor: const Color(0xFF35DB00))),
          actions: <Widget>[
            if (canResendEmail)
              TextButton(
                child: Text(l10n.resendEmail),
                onPressed: () async {
                  await sendVerificationEmail();
                },
              ),
            TextButton(
              child: Text(l10n.signOut),
              onPressed: () async {
                _signOut();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    _verificationTimer?.cancel();

    // Verwende die zentrale signOut-Methode aus AppState
    // Diese schließt automatisch die Hive-Datenbank
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.signOut();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _checkEmailVerification() async {
    if (_disposed) return;

    await FirebaseAuth.instance.currentUser?.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
      _verificationTimer?.cancel();
      Navigator.of(context).pop(); // Close the dialog
      await _navigateToNextScreen();
    }
  }

  Future sendVerificationEmail() async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Localization error - cannot send verification email")));
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();
      setState(() {
        canResendEmail = false;
      });
      await Future.delayed(const Duration(seconds: 5));
      setState(() {
        canResendEmail = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.errorSendingEmailWithError} $e")));
    }
  }

  Future<void> _navigateToNextScreen() async {
    AppLocalizations? l10n;
    int attempts = 0;
    while (l10n == null && attempts < 50) {
      // Max 5 seconds wait
      await Future.delayed(const Duration(milliseconds: 100));
      l10n = AppLocalizations.of(context);
      attempts++;
    }

    if (l10n == null) {
      return;
    }
    //successful auth, initialize Hive
    await initializeUserLocalStorage(FirebaseAuth.instance.currentUser!.uid);

    // At this stage, we have to sync first with the cloud, e.g. to download an existing user doc!

    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isConnected) {
      // Starte Synchronisierung - zeige persistentes Banner
      isSyncing.value = true;

      // openRAL: Update Templates
      syncStatusNotifier.value =
          "${l10n?.syncingWith ?? 'Synchronizing with'} open-ral.io";
      await cloudSyncService.syncOpenRALTemplates(
        'open-ral.io',
        onProgress: (current, total) {
          syncStatusNotifier.value =
              "${l10n?.syncingWith ?? 'Synchronizing with'} open-ral.io ($current/$total)";
        },
      );

      // sync all non-open-ral methods with it's clouds on startup
      for (final cloudKey in cloudConnectors.keys) {
        if (cloudKey != "open-ral.io") {
          syncStatusNotifier.value =
              "${l10n?.syncingWith ?? 'Synchronizing with'} $cloudKey";
          await cloudSyncService.syncMethods(
            cloudKey,
            onProgress: (current, total) {
              syncStatusNotifier.value =
                  "${l10n?.syncingWith ?? 'Synchronizing with'} $cloudKey ($current/$total)";
            },
          );
        }
      }
      final databaseHelper = DatabaseHelper();
      //Repaint Container list
      repaintContainerList.value = true;
      //Repaint Inbox count
      if (FirebaseAuth.instance.currentUser != null) {
        String ownerUID = FirebaseAuth.instance.currentUser!.uid;
        inbox = await databaseHelper.getInboxItems(ownerUID);
        inboxCount.value = inbox.length;
      }
      cloudConnectors =
          await getCloudConnectors(); //refresh cloud connectors (if updates where downloaded)

      // Beende Synchronisierung
      isSyncing.value = false;
      syncStatusNotifier.value = null;
    }

    for (var doc in localStorage!.values) {
      if (doc['template'] != null && doc['template']["RALType"] == "human") {
        final doc2 = Map<String, dynamic>.from(doc);

        if (getObjectMethodUID(doc2) ==
            FirebaseAuth.instance.currentUser!.uid) {
          appUserDoc = doc2;
          break;
        }
      }
    }

    // DEBUG: Anderen User für Testzwecke laden

    // Check if private key exists, if not generate new keypair
    final privateKey = await keyManager.getPrivateKey();
    if (privateKey == null) {
      snackbarMessageNotifier.value = l10n.newKeypairNeeded;
      "No private key found - generating new keypair...";
      final success = await keyManager.generateAndStoreKeys();
      if (!success) {
        snackbarMessageNotifier.value = l10n.failedToInitializeKeyManagement;
        secureCommunicationEnabled = false;
      } else {
        secureCommunicationEnabled = true;
      }
    } else {
      secureCommunicationEnabled = true;
    }

    // if (1 == 1) {//! DEBUG ONLY, REMOVE!!!
    if (appUserDoc == null) {
      //User profile does not yet exist
      if (secureCommunicationEnabled) {
        //Do we get one from cloud?
        await cloudSyncService.syncMethods("tracefoodchain.org");
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

      snackbarMessageNotifier.value = l10n.newUserProfileNeeded;
      Map<String, dynamic> newUser = await getOpenRALTemplate("human");
      newUser["identity"]["UID"] = FirebaseAuth.instance.currentUser?.uid;
      setSpecificPropertyJSON(
          newUser, "email", FirebaseAuth.instance.currentUser?.email, "String");
      newUser["email"] = FirebaseAuth.instance.currentUser
          ?.email; // Necessary to find the user later by email!

      final addItem = await getOpenRALTemplate("generateDigitalSibling");
      //Add Executor
      addItem["executor"] = newUser;
      addItem["methodState"] = "finished";
      //Step 1: get method an uuid (for method history entries)
      setObjectMethodUID(addItem, const Uuid().v4());
      //Step 2: save the objects a first time to get it the method history change
      await setObjectMethod(newUser, false, false);
      //Step 3: add the output objects with updated method history to the method
      addOutputobject(addItem, newUser, "item");
      //Step 4: update method history in all affected objects (will also tag them for syncing)
      await updateMethodHistories(addItem);
      //Step 5: again add Outputobjects to generate valid representation in the method
      newUser = await getLocalObjectMethod(getObjectMethodUID(newUser));
      addOutputobject(addItem, newUser, "item");
      //Step 6: persist process
      await setObjectMethod(addItem, true, true); //sign it!

      appUserDoc = await getLocalObjectMethod(getObjectMethodUID(newUser));
    } else {
      //User mit dieser deviceId schon vorhanden.
    }

//DEBUG CHANGE: CHECK IF THE APPUSERDOC CAN BE FOUND IN CLOUD DATABASE. IF NOT WRITE IT DIRECTLY TO THE CLOUD,IF ONLINE
    if (appState.isConnected && appUserDoc != null) {
      try {
        final userDocRef = FirebaseFirestore.instance
            .collection('TFC_objects')
            .doc(FirebaseAuth.instance.currentUser!.uid);

        final userDocSnapshot = await userDocRef.get();

        if (!userDocSnapshot.exists) {
          snackbarMessageNotifier.value =
              "DEBUG: Uploading user profile to the cloud...";

          await userDocRef.set(appUserDoc!);
        }
      } catch (e) {
        // Fehler beim Cloud-Upload
      }
    }

    //Get user role - synchronize with cloud first if connected
    String finalRole = '';

    if (appState.isConnected) {
      try {
        // Hole die aktuellste Rolle aus der Cloud
        final roleService = RoleManagementService();
        final cloudRole = await roleService.getCurrentUserRoleFromCloud();

        if (cloudRole.isNotEmpty) {
          finalRole = cloudRole;

          // Aktualisiere das lokale appUserDoc mit der Cloud-Rolle
          if (cloudRole !=
              getSpecificPropertyfromJSON(appUserDoc!, "userRole")) {
            appUserDoc = setSpecificPropertyJSON(
                appUserDoc!, "userRole", cloudRole, "String");
          }
        } else {
          // Fallback auf lokale Rolle
          final localRole =
              getSpecificPropertyfromJSON(appUserDoc!, "userRole");
          finalRole = (localRole != "" && localRole != "-no data found-")
              ? localRole
              : '';
        }
      } catch (e) {
        final localRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
        finalRole = (localRole != "" && localRole != "-no data found-")
            ? localRole
            : '';
      }
    } else {
      // Offline - nutze lokale Rolle
      final localRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
      finalRole =
          (localRole != "" && localRole != "-no data found-") ? localRole : '';
    }

    if (finalRole.isNotEmpty) {
      appState.setUserRole(finalRole);
    } else {
      // Neuer User ohne Rolle - setze Standard-Rolle "Trader"
      final newUser =
          setSpecificPropertyJSON(appUserDoc!, "userRole", 'Trader', "String");
      await changeObjectData(newUser); // Nutze changeObjectData für Logging
      appState.setUserRole("Trader");
      finalRole = "Trader";
    }

    // Invalidiere Permission-Cache nach Rollenupdate
    final permissionService = PermissionService();
    permissionService.invalidateRoleCache();

    if (secureCommunicationEnabled == false) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final l10n = AppLocalizations.of(context);
          if (l10n == null) {
            return AlertDialog(
              title: const Text("Security Error"),
              content: const Text(
                  "Failed to initialize key management - app cannot continue securely."),
              actions: <Widget>[
                TextButton(
                  child: const Text("Close App"),
                  onPressed: () =>
                      Navigator.of(context).pop(() => SystemNavigator.pop()),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(l10n.securityError),
            content: Text(l10n.securityErrorMessage),
            actions: <Widget>[
              TextButton(
                child: Text(l10n.closeApp),
                onPressed: () =>
                    Navigator.of(context).pop(() => SystemNavigator.pop()),
              ),
            ],
          );
        },
      );
    } else {
      // Navigiere basierend auf Benutzerrolle
      final userRole = appState.userRole?.toLowerCase() ?? '';
      if (userRole == 'registrar' 
// || userRole == 'superadmin'
) {
        Navigator.of(context).pushReplacementNamed('/registrar');
      } else {
        Navigator.of(context).pushReplacement(
          FadeRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
    // }
  }

  @override
  Widget build(BuildContext context) {
    // Sicherheitsprüfung für AppLocalizations
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Localization Configuration Error',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text(
                'AppLocalizations.delegate is missing in main.dart\nlocalizationsDelegates configuration',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeBackgroundContainer(
            backgroundAsset: 'assets/images/background.png',
            fallbackColor: Colors.white,
            opacity: 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _animation,
                    child: SafeAssetImage(
                      assetPath: 'assets/images/diasca_logo.png',
                      width: 200,
                      height: 200,
                      fallbackWidget: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business,
                          size: 100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.traceTheFoodchain,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'powered by openRAL by permarobotics',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      APP_VERSION,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 16,
            left: 16,
            child: StatusBar(isSmallScreen: false),
          ),
          // Persistentes Banner für Synchronisierung:
          ValueListenableBuilder<bool>(
            valueListenable: isSyncing,
            builder: (context, syncing, child) {
              if (!syncing) return const SizedBox.shrink();

              final l10n = AppLocalizations.of(context);

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Material(
                    color: const Color(0xFF35DB00),
                    elevation: 4,
                    child: ValueListenableBuilder<String?>(
                      valueListenable: syncStatusNotifier,
                      builder: (context, message, _) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  message ??
                                      l10n?.syncInProgress ??
                                      'Synchronization in progress...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          // Snackbar für kurze Meldungen:
          ValueListenableBuilder<String?>(
            valueListenable: snackbarMessageNotifier,
            builder: (context, message, child) {
              if (message != null && message.isNotEmpty && !isSyncing.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final snackBar = SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 2),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  snackbarMessageNotifier.value = "";
                });
              }
              return Container();
            },
          ),
        ],
      ),
    );
  }
}

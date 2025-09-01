import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint("🔍 SplashScreen initState() called");
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
      debugPrint(e.toString());
    }
  }

  void _showEmailVerificationOverlay() {
    debugPrint("🔍 _showEmailVerificationOverlay() called");
    if (_disposed) return;

    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerification();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        debugPrint("🔍 Email verification dialog builder called");
        final l10n = AppLocalizations.of(context);
        if (l10n == null) {
          debugPrint(
              "❌ CRITICAL: AppLocalizations is null in email verification dialog!");
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
    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    final appState = Provider.of<AppState>(context, listen: false);
    appState.setAuthenticated(false);
    appState.setEmailVerified(false);

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
    debugPrint("🔍 sendVerificationEmail() called");
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint("❌ AppLocalizations is null in sendVerificationEmail!");
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
    debugPrint("🔍 _navigateToNextScreen() called");
    AppLocalizations? l10n;
    int attempts = 0;
    while (l10n == null && attempts < 50) {
      // Max 5 seconds wait
      await Future.delayed(const Duration(milliseconds: 100));
      l10n = AppLocalizations.of(context);
      attempts++;
      if (attempts % 10 == 0) {
        debugPrint("🔍 Waiting for AppLocalizations... attempt $attempts");
      }
    }

    if (l10n == null) {
      debugPrint(
          "❌ CRITICAL: AppLocalizations still null after waiting 5 seconds!");
      return;
    }

    debugPrint(
        "✅ AppLocalizations loaded successfully in _navigateToNextScreen");
    //successful auth, initialize Hive
    await initializeUserLocalStorage(FirebaseAuth.instance.currentUser!.uid);

    // At this stage, we have to sync first with the cloud, e.g. to download an existing user doc!

    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isConnected) {
      //ToDo: Display screenblocker "syncing data with cloud - please wait"
      // openRAL: Update Templates
      debugPrint("syncing openRAL");
      snackbarMessageNotifier.value = "${l10n.syncingWith} open-ral.io";
      await cloudSyncService.syncOpenRALTemplates('open-ral.io');

      // sync all non-open-ral methods with it's clouds on startup
      for (final cloudKey in cloudConnectors.keys) {
        if (cloudKey != "open-ral.io") {
          debugPrint("syncing $cloudKey");
          snackbarMessageNotifier.value = "${l10n.syncingWith} $cloudKey";
          await cloudSyncService.syncMethods(cloudKey);
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

  

    // Check if private key exists, if not generate new keypair
    final privateKey = await keyManager.getPrivateKey();
    if (privateKey == null) {
      debugPrint("No private key found - generating new keypair...");
      snackbarMessageNotifier.value = l10n.newKeypairNeeded;
      "No private key found - generating new keypair...";
      final success = await keyManager.generateAndStoreKeys();
      if (!success) {
        debugPrint("WARNING: Failed to initialize key management!");
        snackbarMessageNotifier.value = l10n.failedToInitializeKeyManagement;
        secureCommunicationEnabled = false;
      } else {
        secureCommunicationEnabled = true;
      }
    } else {
      debugPrint("Found existing private key");

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

      debugPrint(
          "user profile not found in local database - creating new one...");
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
      debugPrint("user profile found in local database");
    }

//DEBUG CHANGE: CHECK IF THE APPUSERDOC CAN BE FOUND IN CLOUD DATABASE. IF NOT WRITE IT DIRECTLY TO THE CLOUD,IF ONLINE
    if (appState.isConnected && appUserDoc != null) {
      try {
        final userDocRef = FirebaseFirestore.instance
            .collection('TFC_objects')
            .doc(FirebaseAuth.instance.currentUser!.uid);

        final userDocSnapshot = await userDocRef.get();

        if (!userDocSnapshot.exists) {
          debugPrint("User doc not found in cloud, uploading local doc...");
          snackbarMessageNotifier.value =
              "DEBUG: Uploading user profile to the cloud...";

          await userDocRef.set(appUserDoc!);
          debugPrint("User doc successfully uploaded to cloud");
        } else {
          debugPrint("User doc already exists in cloud");
        }
      } catch (e) {
        debugPrint("Error checking/uploading user doc to cloud: $e");
      }
    }

    //Schaun ob user role vorhanden ist
    //! atm we skip role selection - everybody can do everything
    //! Role is set to trader for all users
    // final userRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
    // if (userRole != "" && userRole != "-no data found-") {
    appState.setUserRole("Trader");
    // }

    if (appState.userRole == null) {
      //! atm we skip role selection - everybody can do everything
      //! Role is set to trader for all users
      // Navigator.of(context).pushReplacement(
      //   FadeRoute(builder: (_) => const
      // RoleSelectionScreen()),
      // );
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setUserRole('Trader');
      appUserDoc = await getLocalObjectMethod(getObjectMethodUID(appUserDoc!));
      appUserDoc =
          setSpecificPropertyJSON(appUserDoc!, "userRole", 'Trader', "String");

      //ToDo: addEditItem Method instead of just setObjectMethod
      appUserDoc = await setObjectMethod(appUserDoc!, false, true);
    }

    //  else {

    if (secureCommunicationEnabled == false) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final l10n = AppLocalizations.of(context);
          if (l10n == null) {
            debugPrint("❌ AppLocalizations is null in security error dialog!");
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
      Navigator.of(context).pushReplacement(
        FadeRoute(builder: (_) => const HomeScreen()),
      );
    }
    // }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔍 SplashScreen build() called");

    // Sicherheitsprüfung für AppLocalizations
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint(
          "❌ CRITICAL ERROR: AppLocalizations.of(context) returned null!");
      debugPrint(
          "❌ This means AppLocalizations.delegate is missing from main.dart localizationsDelegates");
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

    debugPrint("✅ AppLocalizations successfully loaded");
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.5), // Adjust the opacity as needed
                  BlendMode.dstATop,
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _animation,
                    child: Image.asset(
                      'assets/images/diasca_logo.png',
                      width: 200,
                      height: 200,
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
          // Neuer ValueListenableBuilder zur Anzeige des Snackbars:
          ValueListenableBuilder<String?>(
            valueListenable: snackbarMessageNotifier,
            builder: (context, message, child) {
              if (message != null && message.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final snackBar = SnackBar(
                    content: Text(message), //ToDo: localise
                    duration: const Duration(
                        seconds:
                            1), // Snackbar will auto-dismiss after 3 seconds
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

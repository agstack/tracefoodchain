import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/repositories/roles.dart';
import 'package:trace_foodchain_app/screens/inbox_screen.dart';
import 'package:trace_foodchain_app/screens/trader_screen.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/widgets/language_selector.dart';
import 'package:trace_foodchain_app/widgets/role_based_speed_dial.dart';
import 'package:trace_foodchain_app/widgets/status_bar.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart'; // Falls benötigt
import '../services/get_device_id.dart';

import 'package:trace_foodchain_app/widgets/tracked_value_notifier.dart';

String displayContext = "action";
TrackedValueNotifier<bool> rebuildList =
    TrackedValueNotifier<bool>(false, "rebuildList");
TrackedValueNotifier<String?> snackbarMessageNotifier =
    TrackedValueNotifier<String?>(null, "snackbarMessageNotifier");

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer =
        Timer.periodic(Duration(seconds: cloudSyncFrequency), (_) async {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.isConnected && appState.isAuthenticated) {
        for (final cloudKey in cloudConnectors.keys) {
          if (cloudKey != "open-ral.io") {
            
            final l10n = AppLocalizations.of(context)!;
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
          // if (accountUID!="") ownerUID = accountUID; // TESTACCOUNT
          inbox = await databaseHelper.getInboxItems(ownerUID);
          inboxCount.value = inbox.length;
        }
      }
    });
  }

  // Neue Methode zum manuellen Synchronisieren der Cloud.
  void _manualSync() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    if (appState.isConnected && appState.isAuthenticated) {
      for (final cloudKey in cloudConnectors.keys) {
        if (cloudKey != "open-ral.io") {
          
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
        // if (accountUID!="") ownerUID = accountUID; // TESTACCOUNT
        inbox = await databaseHelper.getInboxItems(ownerUID);
        inboxCount.value = inbox.length;
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: customTheme,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: const LanguageSelector(),
          title: const Text("TraceFoodChain"),
          actions: [
            ValueListenableBuilder(
                valueListenable: inboxCount,
                builder: (context, int value, child) {
                  if (!mounted) return Container();
                  return Badge(
                    offset: const Offset(-3, 5),
                    isLabelVisible: inboxCount.value > 0,
                    label: Text('${inboxCount.value}'),
                    child: Tooltip(
                      message: l10n.inbox,
                      child: IconButton(
                        icon: const Icon(Icons.inbox),
                        onPressed: () => _navigateToInbox(context),
                      ),
                    ),
                  );
                }),
            Tooltip(
              message: l10n.sendFeedback, //"Send Feedback",
              child: IconButton(
                icon: const Icon(Icons.feedback),
                onPressed: () => _launchFeedbackEmail(context),
              ),
            ),
            // Neuer IconButton für manuelle Synchronisierung
            Tooltip(
              message: "Manuelle Synchronisierung",
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _manualSync,
              ),
            ),
            Tooltip(
              message: l10n.settings, //"Settings",
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _navigateToSettings(context),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (isTestmode)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    l10n.testModeActive, // Lokalisierter Text, z. B. "Testmodus aktiv"
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            const StatusBar(isSmallScreen: true),
            Expanded(
              child: Row(
                children: [
                  // if (!isSmallScreen) _buildSideMenu(context),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder(
                              valueListenable: rebuildList,
                              builder: (context, bool value, child) {
                                if (!mounted) return Container();
                                rebuildList.value = false;
                                Widget? screen;
                                switch (appState.userRole) {
                                  // case 'Farmer':
                                  //   screen = const FarmerActionsScreen();
                                  //   break;
                                  // case 'Farm Manager':
                                  //   screen = const FarmManagerScreen();
                                  // break;
                                  case 'Trader':
                                    screen = const TraderScreen();
                                    break;
                                  case 'Processor':
                                    screen = const TraderScreen();
                                    break;
                                  // case 'Transporter':
                                  //   screen = const TransporterScreen();
                                  //   break;
                                  // case 'Importer':
                                  //   screen = const ImporterScreen();
                                  //   break;
                                  default:
                                    screen = const TraderScreen();
                                }
                                return Expanded(child: screen);
                              }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: snackbarMessageNotifier,
              builder: (context, message, child) {
                if (!mounted) return Container();
                if (message != null && message.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(message),
                      duration: const Duration(
                          seconds:
                              1), // Snackbar will auto-dismiss after 3 seconds
                    ));
                    snackbarMessageNotifier.value = "";
                  });
                }
                return Container();
              },
            ),
          ],
        ),
        floatingActionButton: ValueListenableBuilder(
            valueListenable: rebuildList,
            builder: (context, bool value, child) {
              if (!mounted) return Container();
              rebuildList.value = false;
              return RoleBasedSpeedDial(displayContext: displayContext);
            }),
        // bottomNavigationBar: isSmallScreen ? _buildBottomMenu(context) : null,
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 200,
      color: Colors.grey[200],
      child: Column(
        children: [
          Expanded(child: _buildMenuItems(context)),
          const StatusBar(isSmallScreen: false),
        ],
      ),
    );
  }

  Widget _buildBottomMenu(BuildContext context) {
    return (Container());
    // final l10n = AppLocalizations.of(context)!;
    // return BottomNavigationBar(
    //   items: [
    //     BottomNavigationBarItem(
    //         icon: const Icon(Icons.play_arrow), label: l10n.actions),
    //     BottomNavigationBarItem(
    //         icon: const Icon(Icons.storage), label: l10n.storage),
    //     BottomNavigationBarItem(
    //         icon: const Icon(Icons.settings), label: l10n!.settings),
    //   ],
    //   onTap: (index) {
    //     switch (index) {
    //       case 0:
    //         displayContext = "action";
    //         rebuildList.value = true;
    //         break;
    //       case 1:
    //         displayContext = "storage";
    //         rebuildList.value = true;
    //         break;
    //       case 2:
    //         _navigateToSettings(context);
    //         break;
    //     }
    //   },
    // );
  }

  Widget _buildMenuItems(BuildContext context) {
    final databaseHelper = DatabaseHelper();
    final l10n = AppLocalizations.of(context)!;
    String selectedContext = "action";
    return StatefulBuilder(builder: (context, setState) {
      return ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: Text(l10n.actions, style: const TextStyle(fontSize: 16)),
            selected: selectedContext == "action",
            selectedTileColor: const Color(0xFF35DB00),
            tileColor: selectedContext == "action"
                ? const Color(0xFF35DB00)
                : Colors.white,
            onTap: () {
              displayContext = "action";
              selectedContext = "action";
              rebuildList.value = true;
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text(l10n.storage, style: const TextStyle(fontSize: 16)),
            selected: selectedContext == "storage",
            selectedTileColor: const Color(0xFF35DB00),
            tileColor: selectedContext == "storage"
                ? const Color(0xFF35DB00)
                : Colors.white,
            onTap: () {
              displayContext = "storage";
              selectedContext = "storage";
              rebuildList.value = true;
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.settings, style: const TextStyle(fontSize: 16)),
            selected: selectedContext == "settings",
            selectedTileColor: const Color(0xFF35DB00),
            tileColor: selectedContext == "settings"
                ? const Color(0xFF35DB00)
                : Colors.white,
            onTap: () {
              selectedContext = "settings";
              rebuildList.value = true;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) async {
                setState(() {});
                //Repaint Container list
                repaintContainerList.value = true;
                //Repaint Inbox count
                if (FirebaseAuth.instance.currentUser != null) {
                  String ownerUID = FirebaseAuth.instance.currentUser!.uid;
                  inbox = await databaseHelper.getInboxItems(ownerUID);
                  inboxCount.value = inbox.length;
                }
              });
            },
          ),
        ],
      );
    });
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) async {
      // setState(() {});

      //Repaint Container list
      repaintContainerList.value = true;
      //Repaint Inbox count
      if (FirebaseAuth.instance.currentUser != null) {
        final databaseHelper = DatabaseHelper();
        String ownerUID = FirebaseAuth.instance.currentUser!.uid;
        inbox = await databaseHelper.getInboxItems(ownerUID);
        inboxCount.value = inbox.length;
      }
    });
  }

  void _navigateToInbox(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InboxScreen()),
    );
  }

  void _launchFeedbackEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // For web, open in a new tab
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'feedback@tracefoodchain.org',
      queryParameters: {
        'subject': l10n.feedbackEmailSubject,
        'body': l10n.feedbackEmailBody,
      },
    );

    if (await canLaunch(emailLaunchUri.toString())) {
      await launch(emailLaunchUri.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToLaunchEmail)),
      );
    }
    return;
  }
}

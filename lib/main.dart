//! Generate new localisation: flutter gen-l10n
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Google Maps Web support
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:nfc_manager/nfc_manager.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/firebase_options.dart';
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:trace_foodchain_app/helpers/digital_signature.dart';
import 'package:trace_foodchain_app/helpers/key_management.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/repositories/initial_data.dart';
import 'package:trace_foodchain_app/screens/splash_screen.dart';
import 'package:trace_foodchain_app/screens/registrar_screen.dart';
import 'package:trace_foodchain_app/screens/sign_up_screen.dart';
import 'package:trace_foodchain_app/services/background_sync_service.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
import 'package:trace_foodchain_app/services/cloud_log_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';
import 'package:trace_foodchain_app/services/sync_settings_service.dart';
import 'package:trace_foodchain_app/services/google_maps_initializer.dart';

import 'package:trace_foodchain_app/widgets/tracked_value_notifier.dart';
import 'package:trace_foodchain_app/widgets/items_list_widget.dart';

String country = "Honduras"; //TODO: enable other contries if needed;
int cloudSyncFrequency =
    600; //in case internet is connected, this will sync with the cloud every xxx seconds
Box<Map<dynamic, dynamic>>? localStorage;
late Box<Map<dynamic, dynamic>> openRALTemplates;
late Map<String, Map<String, dynamic>> cloudConnectors;
Map<String, dynamic>? appUserDoc;
TrackedValueNotifier<bool> repaintContainerList =
    TrackedValueNotifier<bool>(false, "repaintContainerList");
TrackedValueNotifier<bool> rebuildSpeedDial =
    TrackedValueNotifier<bool>(false, "rebuildSpeedDial");
TrackedValueNotifier<bool> rebuildDDS =
    TrackedValueNotifier<bool>(false, "rebuildDDS");

// ValueNotifier für Synchronisierungsstatus
TrackedValueNotifier<String?> syncStatusNotifier =
    TrackedValueNotifier<String?>(null, "syncStatusNotifier");
TrackedValueNotifier<bool> isSyncing =
    TrackedValueNotifier<bool>(false, "isSyncing");

// ValueNotifier für Upload-Fortschritt
TrackedValueNotifier<double> uploadProgress =
    TrackedValueNotifier<double>(0.0, "uploadProgress");

// ValueNotifier für den Namen des aktuell hochgeladenen Fotos
TrackedValueNotifier<String> currentUploadPhotoName =
    TrackedValueNotifier<String>('', "currentUploadPhotoName");

// Debug-Wrapper für ValueNotifiers
class DebugValueNotifier<T> extends ValueNotifier<T> {
  final String name;

  DebugValueNotifier(super.value, this.name);

  @override
  set value(T newValue) {
// Check for listeners
    if (hasListeners) {
    } else {}

    super.value = newValue;
  }

  @override
  void notifyListeners() {
    try {
      super.notifyListeners();
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}

bool secureCommunicationEnabled = false;

List<Map<String, dynamic>> inbox = [];
TrackedValueNotifier<int> inboxCount =
    TrackedValueNotifier<int>(0, "inboxCount");

bool batchSalePossible = false;
bool isWebLandscape = false;
CloudSyncService cloudSyncService = CloudSyncService('tracefoodchain.org');
CloudLogService cloudLogService = CloudLogService();
late KeyManager keyManager;
late DigitalSignature digitalSignature;

ThemeData customTheme = ThemeData(
  useMaterial3: true,
  visualDensity: VisualDensity.adaptivePlatformDensity,

  //* TEXT
  // The 2018 geometry styles carry `inherit: false`. TextStyle.merge returns
  // such a style UNCHANGED, so merging them into the theme's default text
  // theme throws its colors away - and a TextStyle with `inherit: false` and
  // no color paints WHITE. That is why every widget reading the text theme
  // directly (AlertDialog title and content, AppBar titles, ...) rendered
  // white on white. Supplying the colors here restores them; `bodyColor`
  // covers headlineSmall/title/body/label, `displayColor` the display and
  // large headline styles.
  textTheme: Typography.englishLike2018.apply(
    fontSizeFactor: 1,
    bodyColor: Colors.black87,
    displayColor: Colors.black87,
  ),
  //  const TextTheme(//
  //   displayLarge: TextStyle(
  //       fontSize: 72.0, fontWeight: FontWeight.bold, color: Colors.black),
  //   titleLarge: TextStyle(
  //       fontSize: 36.0, fontStyle: FontStyle.italic, color: Colors.black),
  //   bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black),
  //   labelLarge: TextStyle(color: Colors.white),
  //   labelMedium: TextStyle(color: Colors.black),
  //   labelSmall: TextStyle(color: Colors.black),
  // ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Color(0xFF35DB00),
    selectionColor: Color(0xFF35DB00),
    selectionHandleColor: Color(0xFF35DB00),
  ),

  //* CHECKBOX

  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5.0),
    ),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFF35DB00); // Farbe wenn ausgewählt
      }
      return Colors.grey; // Farbe wenn nicht ausgewählt
    }),
    checkColor: WidgetStateProperty.all(Colors.white),
  ),

  //* APPBAR
  appBarTheme: const AppBarTheme(
    surfaceTintColor: Colors.white,

    elevation: 0.0, // Shadow the AppBar casts
    iconTheme:
        IconThemeData(color: Colors.black54), // Color of icons in the AppBar
  ),

  //* SWITCH
  switchTheme: SwitchThemeData(
    trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors
              .white; // Farbe der Umrandung, wenn der Schalter deaktiviert ist
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(
              0xFF35DB00); //  Farbe der Umrandung, wenn der Schalter aktiviert ist
        }
        return Colors.white; // Standardfarbe  Farbe der Umrandung
      },
    ),
    thumbColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors
              .grey; // Farbe des Schaltknopfes, wenn der Schalter deaktiviert ist
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(
              0xFF35DB00); // Farbe des Schaltknopfes, wenn der Schalter aktiviert ist
        }
        return Colors.white; // Standardfarbe des Schaltknopfes
      },
    ),
    trackColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.black26;
          // Color.fromARGB(94, 55, 219,
          //     0); // Farbe der Schalterspur, wenn der Schalter deaktiviert ist
        }
        if (states.contains(WidgetState.selected)) {
          return Colors
              .white; // Farbe der Schalterspur, wenn der Schalter aktiviert ist
        }
        return Colors.black26;
        // Color.fromARGB(94, 55, 219, 0); // Standardfarbe der Schalterspur
      },
    ),
  ),
  //* CARD
  cardTheme: const CardThemeData(surfaceTintColor: Colors.white),

  colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.white,
      primary: const Color(0xFF35DB00), // Color for active step
      onPrimary: Colors.white, // Text color for active step
      secondary: Colors.grey),
  primaryColor: const Color(0xFF35DB00),

  cardColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  //* BUTTONS
  buttonTheme: const ButtonThemeData(
    hoverColor: Colors.white24,
    buttonColor: Color(0xFF35DB00), // Background color (blue in this case)
    textTheme: ButtonTextTheme
        .primary, // Use the primary color for text (white by default)
  ),
  // Style for text in buttons

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF35DB00); // Color when hovered
          }
          return const Color(0xFF35DB00); // Default color
        },
      ),
      // Set the foreground color (text color)
      foregroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.white; // Color when hovered
          }
          return Colors.white; // Default color
        },
      ),
      // Set the overlay color (hover color)
      overlayColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF35DB00).withAlpha(124); // Hover color
          }
          return Colors.transparent; // Default (no color)
        },
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      // Set the foreground color (text color)
      foregroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.black; // Color when hovered
          }
          return Colors.black87; // Default color
        },
      ),
      // Set the overlay color (hover color)
      overlayColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.black12; // Hover color
          }
          return Colors.transparent; // Default (no color)
        },
      ),
    ),
  ),
);

extension CustomColorScheme on ColorScheme {
  // Tertiary Scheme
  Color get primary1 => const Color(0xFFFF8118);
  Color get primary2 => const Color(0xFFFF8118);
  Color get primary3 => const Color(0xFFAA6C39);
  Color get primary4 => const Color(0xFF513E2E);
  Color get primary5 => const Color(0xFF42372D);

  Color get secondary1_1 => const Color(0xFF191B18);
  Color get secondary1_2 => const Color(0xFF42563C);
  Color get secondary1_3 => const Color(0xFF479030);
  Color get secondary1_4 => const Color(0xFF31CA00);
  Color get secondary1_5 => const Color(0xFF35DB00);

  Color get secondary2_1 => const Color(0xFF6A000F);
  Color get secondary2_2 => const Color(0xFF860819);
  Color get secondary2_3 => const Color(0xFFA23645);
  Color get secondary2_4 => const Color(0xFFBE747E);
  Color get secondary2_5 => const Color(0xFFDAC1C4);

  Color get complement1 => const Color(0xFF19C4C4);
  Color get complement2 => const Color(0xFF208A8A);
  Color get complement3 => const Color(0xFF226666);
  Color get complement4 => const Color(0xFF1D4242);
  Color get complement5 => const Color(0xFF101E1E);
}

/// Prints every LayoutBuilder currently in the tree together with the widget
/// chain that created it (including source locations).
///
/// The "_RenderLayoutBuilder was mutated in performLayout" assertion names two
/// render objects by hash but not by origin. This walks the element tree and
/// reports exactly those two, so the next occurrence points straight at the
/// offending widget instead of requiring a full render tree dump.
void _dumpLayoutBuilderCreators() {
  int found = 0;

  void visit(Element element) {
    final renderObject = element.renderObject;
    if (renderObject != null &&
        renderObject.runtimeType.toString().contains('RenderLayoutBuilder')) {
      found++;
      debugPrint('  [$found] ${renderObject.runtimeType}'
          '#${renderObject.hashCode.toRadixString(16)}');
      // 12 links up the chain is enough to reach our own widget above the
      // framework wrappers.
      debugPrint('      ${element.debugGetCreatorChain(12)}');
    }
    element.visitChildren(visit);
  }

  try {
    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    if (found == 0) debugPrint('  (kein LayoutBuilder im Baum gefunden)');
  } catch (e) {
    debugPrint('  LayoutBuilder-Suche fehlgeschlagen: $e');
  }
}

void main() async {
  // Enable detailed stack traces for debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    // DEBUG: Gezieltes Logging für den "_RenderLayoutBuilder was mutated"-Fehler.
    // Gibt die ungekürzte Stacktrace und den Render-Tree aus, damit wir sehen,
    // welches Widget den betroffenen LayoutBuilder erzeugt.
    final String message = details.exceptionAsString();
    if (message.contains('_RenderLayoutBuilder was mutated') ||
        message.contains('was mutated in') ||
        message.contains('_debugCanPerformMutations')) {
      try {
        debugPrint('\n════════ LAYOUT-MUTATION DEBUG ════════');
        debugPrint('Exception: $message');

        // Vollständige, ungekürzte Stacktrace (jede Zeile einzeln, damit die
        // Konsole nichts abschneidet). Wichtig: der interessante Teil liegt
        // NACH der von Flutter normalerweise elidierten Framework-Sektion.
        final StackTrace? stack = details.stack;
        if (stack != null) {
          final List<String> lines = stack.toString().split('\n');

          // Zuerst nur die App-eigenen Frames: der Auslöser einer Mutation
          // während des Layouts ist immer eine unserer Zeilen zwischen lauter
          // package:flutter-Frames - die geht im vollen Trace unter.
          final List<String> appFrames = lines
              .where((String line) =>
                  line.contains('package:trace_foodchain_app/') ||
                  line.contains('package:device_preview/'))
              .toList();
          debugPrint('---- APP FRAMES (Verursacher) ----');
          if (appFrames.isEmpty) {
            debugPrint('  (keine - der Auslöser liegt komplett im Framework)');
          } else {
            for (final String line in appFrames) {
              debugPrint(line);
            }
          }

          debugPrint('---- FULL STACK (untruncated) ----');
          for (final String line in lines) {
            debugPrint(line);
          }
        }

        // Alle beteiligten Diagnose-Knoten (enthalten u.a. den debugCreator der
        // RenderObjects, d.h. den Quellort des jeweiligen LayoutBuilder).
        debugPrint('---- DIAGNOSTICS ----');
        for (final DiagnosticsNode node
            in details.informationCollector?.call() ??
                const <DiagnosticsNode>[]) {
          debugPrint(node.toStringDeep());
        }

        // Nur die LayoutBuilder mit ihrer Widget-Herkunft. Ein kompletter
        // Render-Tree-Dump enthält die Antwort zwar auch, ist aber tausende
        // Zeilen lang und damit praktisch unbrauchbar.
        debugPrint('---- LAYOUTBUILDERS IM BAUM ----');
        _dumpLayoutBuilderCreators();
        debugPrint('════════ END LAYOUT-MUTATION DEBUG ════════\n');
      } catch (e) {
        debugPrint('LAYOUT-MUTATION DEBUG failed to collect info: $e');
      }
    }
  };
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Google Maps API für Web (lädt API Key aus .env)
  if (kIsWeb) {
    await GoogleMapsInitializer.initialize();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  // final deviceId = await getDeviceId();
  await Hive.initFlutter();

  //Removed: *Start accessing local data storage
  // localStorage = await Hive.openBox<Map<dynamic, dynamic>>(
  //     'localStorage');
  // await localStorage.deleteFromDisk(); //DEBUG: DELETE DATABASE

  //*Start accessing local template storage
  openRALTemplates =
      await Hive.openBox<Map<dynamic, dynamic>>('openRALTemplates');
  // await openRALTemplates.deleteFromDisk(); //DEBUG: DELETE TEMPLATE DATABASE

  //FIRST-EVER STARTUP OF APP: Add initial templates if they are not in the local database
  for (final ot in initialTemplates) {
    //add inital templates from static storage to hive if not in local database
    if (!openRALTemplates.containsKey(ot["template"]["RALType"])) {
      Map<String, dynamic> mot = deepCopyMap(ot);
      openRALTemplates.put(ot["template"]["RALType"], mot);
    }
  }

  // cloudConnectors =
  //     await getCloudConnectors(); //get available cloudConnectors to talk to clouds if available from localStorage

  //*Load the persistent sync preferences (WP A2) before anything can sync
  await syncSettings.load();

  //*WP A3: register the periodic, connectivity-gated background sync.
  // workmanager was already a dependency but was never registered, so a device
  // that came back online while backgrounded never caught up on its own.
  await BackgroundSyncService.register();

  final appState = AppState();
  await appState.initializeApp(); // Initialize locale

  // Set isWebLandscape BEFORE _initializeAppState so camera check works correctly
  if (kIsWeb) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    isWebLandscape = size.width > size.height;
  }

  await _initializeAppState(appState);

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      // device_preview hängt die gesamte App unter einen GlobalKey (_appKey),
      // der je nach Preview-/Toolbar-Zustand die Position im Baum wechselt.
      // Das dabei ausgelöste Reparenting reaktiviert jedes OverlayPortal im
      // App-Baum - seit Flutter 3.27 ist jeder Tooltip eines - und hängt dessen
      // Deferred Child neu ins Overlay ein. Passiert das innerhalb des
      // Layout-Callbacks von device_preview's eigenem LayoutBuilder, wirft
      // Flutter "_RenderLayoutBuilder was mutated in performLayout".
      //
      // Ob es kracht, entscheidet ein Race: nur wenn ein setState aus einem
      // aufgelösten Future zwischen Build- und Layout-Phase desselben Frames
      // landet, wird der Rebuild ins Layout hineingezogen. Darum trat der
      // Fehler bevorzugt auf Screens mit vielen asynchronen setState auf
      // (QC-Screen) und nur manchmal.
      //
      // Deshalb standardmässig aus. Bei Bedarf einschalten mit:
      //   flutter run --dart-define=DEVICE_PREVIEW=true
      child: DevicePreview(
        enabled: !kReleaseMode &&
            const bool.fromEnvironment('DEVICE_PREVIEW', defaultValue: false),
        builder: (context) =>
            const MyApp(), // MyApp wird nun vom GlobalSnackBarListener umschlossen
      ),
    ),
  );
}

// Neue Funktion zum Initialisieren des User-spezifischen LocalStorage
Future<void> initializeUserLocalStorage(String userId) async {
  final boxName = 'localStorage_$userId';

  // Prüfe ob Box bereits für diesen User geöffnet ist
  if (Hive.isBoxOpen(boxName)) {
    // Box ist bereits geöffnet, hole Referenz ohne erneutes Öffnen
    localStorage = Hive.box<Map<dynamic, dynamic>>(boxName);
    // Die Sync-Outboxen teilen den Lebenszyklus von localStorage (WP A1/A3/A4)
    await openUserSyncBoxes(userId);
    debugPrint('localStorage for $userId already open, reusing existing box');
    return;
  }

  // Schließe vorherige Box falls vorhanden (anderer User)
  if (localStorage != null && localStorage!.isOpen) {
    await localStorage!.close();
  }

  // Öffne neue Box für den spezifischen User
  debugPrint('Opening new localStorage box for $userId');
  localStorage = await Hive.openBox<Map<dynamic, dynamic>>(boxName);
  // await localStorage!.deleteFromDisk(); //DEBUG: DELETE DATABASE

  // Media-Outbox (WP A1) sowie Retry-/Staging-Boxen (WP A3/A4) öffnen
  await openUserSyncBoxes(userId);

  // WP A4: einen abgebrochenen Pull entweder komplett übernehmen oder verwerfen -
  // niemals einen halb aktualisierten Zustand stehen lassen.
  await cloudSyncService.recoverInterruptedPull();
  refreshPendingItemCount();

  // Lade cloudConnectors für diesen User
  cloudConnectors = await getCloudConnectors();
}

// Funktion zum Schließen des User LocalStorage (bei Logout)
Future<void> closeUserLocalStorage() async {
  // Sync-Outboxen zusammen mit localStorage schließen, damit keine Medien oder
  // Retry-Zustände eines Users in die Session des nächsten überlaufen.
  await closeUserSyncBoxes();
  syncSettings.pendingItemCount.value = 0;

  if (localStorage != null && localStorage!.isOpen) {
    await localStorage!.close();
    localStorage = null;
    cloudConnectors.clear();
  }

  // KRITISCH: Alle globalen Variablen zurücksetzen, die Benutzerdaten enthalten
  appUserDoc = null;
  inbox.clear();
  inboxCount.value = 0;

  // Cache des PermissionService invalidieren
  final permissionService = PermissionService();
  permissionService.invalidateRoleCache();

  // Ausgewählte Items zurücksetzen (aus items_list_widget.dart)
  selectedItems.clear();

  // Cloud-Log-Session zurücksetzen
  cloudLogService.reset();

  // UI-Update erzwingen
  repaintContainerList.value = true;
  rebuildSpeedDial.value = true;
  rebuildDDS.value = true;
}

// Helper Funktion um sicherzustellen, dass localStorage verfügbar ist
bool isLocalStorageInitialized() {
  return localStorage != null && localStorage!.isOpen;
}

Future<void> _initializeAppState(AppState appState) async {
  keyManager = KeyManager();
  digitalSignature = DigitalSignature();

  // Check internet connectivity at startup

  var connectivityResult = await (Connectivity().checkConnectivity());
  bool cr = false;

  appState.setConnected(connectivityResult != [ConnectivityResult.none]);

  // Start the connectivity listener to see changes in connectivity

  appState.startConnectivityListener();

  // Check camera availability
  // String userAgent = html.window.navigator.userAgent.toLowerCase();

  try {
    if (!isWebLandscape) {
      // if (!userAgent.contains('macintosh')) {
      final cameras = await availableCameras();

      appState.setHasCamera(cameras.isNotEmpty);
    } else {
      appState.setHasCamera(false);

//! Does not work in Flutter Web on MacOS!
    }
  } catch (_) {
    appState.setHasCamera(false);
  }

  // Check NFC availability

  bool hasNFC = false;
  NFCAvailability availability = await FlutterNfcKit.nfcAvailability;
  try {
    if (availability == NFCAvailability.available) {
      hasNFC = true;
    } else {
      hasNFC = false;
    }
  } catch (e) {
    hasNFC = false;
  }

  appState.setHasNFC(hasNFC);

  // Check GPS availability

  bool hasGPS = await Geolocator.isLocationServiceEnabled();

  appState.setHasGPS(hasGPS);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return MaterialApp(

          // locale: DevicePreview.locale(context),
          locale: appState
              .locale, // Re-enable this line to use the locale from the appState
          builder: DevicePreview.appBuilder,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('es', ''), // Spanish
            Locale('de', ''), // German
            Locale('fr', ''), // French
          ],
          title: 'TraceFoodChain App',
          theme: customTheme,
          initialRoute: '/',
          onGenerateRoute: _generateRoute);
    });
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/registrar':
        return MaterialPageRoute(builder: (_) => const RegistrarScreen());
      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}

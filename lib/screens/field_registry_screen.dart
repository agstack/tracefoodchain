import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/asset_registry_api_service.dart';
import 'package:trace_foodchain_app/services/user_registry_api_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/utils/file_download.dart';

/// Eine einfache LatLng Klasse für Koordinaten
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
  List<double> toJson() => [latitude, longitude];

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class FieldRegistryScreen extends StatefulWidget {
  const FieldRegistryScreen({super.key});

  @override
  State<FieldRegistryScreen> createState() => _FieldRegistryScreenState();
}

class _FieldRegistryScreenState extends State<FieldRegistryScreen> {
  List<Map<String, dynamic>> registeredFields = [];
  List<Map<String, dynamic>> filteredFields = [];
  bool isLoading = false;
  bool isRegistering = false;
  String selectedDateFilter =
      'all'; // 'all', 'today', 'week', 'month', 'year', 'specific'
  DateTime? selectedSpecificDate;

  // Progress tracking variables
  bool showProgressOverlay = false;
  String currentProgressStep = '';
  String currentFieldName = '';
  int currentFieldIndex = 0;
  int totalFields = 0;
  List<String> progressSteps = [];

  /// Prüft, ob alle erforderlichen globalen Variablen initialisiert sind
  bool _isAppFullyInitialized() {
    try {
      // Prüfe localStorage
      if (!localStorage!.isOpen) {
        debugPrint('localStorage is not open');
        return false;
      }

      // Prüfe ob localStorage tatsächlich funktioniert
      localStorage!.values.length; // Test access

      // Weitere Prüfungen können hier hinzugefügt werden
      return true;
    } catch (e) {
      debugPrint('Error checking app initialization: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    filteredFields = []; // Initialisiere die gefilterte Liste
    _loadRegisteredFields();
  }

  Future<void> _loadRegisteredFields() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Lade registrierte Felder aus der Cloud-Datenbank
      final fields = await _getFieldsFromCloudDatabase();

      if (!mounted) return; // Prüfe erneut vor setState

      setState(() {
        registeredFields = fields;
        _applyDateFilter(); // Wende den aktuellen Filter an
      });
    } catch (e) {
      debugPrint('Error loading fields: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getFieldsFromCloudDatabase() async {
    final List<Map<String, dynamic>> fields = [];

    try {
      // Verwende getMyObjectsStream aus open_ral_service
      late StreamSubscription streamSubscription;
      final completer = Completer<void>();

      streamSubscription = getMyObjectsStream().listen(
        (querySnapshot) {
          fields.clear(); // Lösche vorherige Einträge

          for (final doc in querySnapshot.docs) {
            final fieldData = doc.data() as Map<String, dynamic>;

            // Filtere nur "field" Objekte
            if (fieldData['template']?["RALType"] != "field") {
              continue;
            }

            // Prüfe ob es sich um ein testmode-Objekt handelt, wenn wir nicht im Testmodus sind
            if (!isTestmode &&
                fieldData.containsKey("isTestmode") &&
                fieldData["isTestmode"] == true) {
              continue;
            }
            if (isTestmode && !fieldData.containsKey("isTestmode")) {
              continue;
            }

            // Extrahiere relevante Informationen
            final String fieldName = fieldData["identity"]?["name"] ??
                "Unnamed Field"; // Will be localized later
            final String fieldUID = fieldData["identity"]?["UID"] ?? "";
            String geoId = "";

            // Versuche geoID aus alternateIDs zu extrahieren
            if (fieldData["identity"]?["alternateIDs"] != null) {
              for (final altId in fieldData["identity"]["alternateIDs"]) {
                if (altId["issuedBy"] == "Asset Registry") {
                  geoId = altId["UID"];
                  break;
                }
              }
            }

            // Extrahiere Fläche
            String area =
                getSpecificPropertyfromJSON(fieldData, "area")?.toString() ??
                    "";

            fields.add({
              "name": fieldName,
              "uid": fieldUID,
              "geoId": geoId,
              "area": area,
              "methodHistoryRef": fieldData["methodHistoryRef"] ?? [],
            });
          }

          // Schließe den Stream nach dem ersten Datenempfang
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          debugPrint('Error in stream: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Warte auf die ersten Daten oder Timeout
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 5)), // Timeout nach 5 Sekunden
      ]);

      // Stream sofort schließen
      await streamSubscription.cancel();

      // Für jedes Feld das Registrierungsdatum laden
      for (final field in fields) {
        final registrationDate =
            await _getRegistrationDate(field["methodHistoryRef"]);
        field["registrationDate"] = registrationDate;
      }

      // Sortiere die Felder nach Registrierungsdatum (neueste zuerst)
      fields.sort((a, b) {
        final dateA = a["registrationDate"] as DateTime?;
        final dateB = b["registrationDate"] as DateTime?;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA); // Neueste zuerst
      });
    } catch (e) {
      debugPrint('Error getting fields from stream: $e');
    }
    return fields;
  }

  /// Ermittelt das Registrierungsdatum durch das Suchen der generateDigitalSibling Methode
  Future<DateTime?> _getRegistrationDate(List<dynamic> methodHistoryRef) async {
    if (methodHistoryRef.isEmpty) return null;

    try {
      // Finde die generateDigitalSibling Methode in der methodHistoryRef
      Map<String, dynamic>? generateDigitalSiblingRef;
      for (final methodRef in methodHistoryRef) {
        if (methodRef is Map<String, dynamic> &&
            methodRef["RALType"] == "generateDigitalSibling") {
          generateDigitalSiblingRef = methodRef;
          break;
        }
      }

      if (generateDigitalSiblingRef == null) {
        debugPrint(
            'No generateDigitalSibling method found in methodHistoryRef');
        return null;
      }

      final methodUID = generateDigitalSiblingRef["UID"];
      if (methodUID == null) {
        debugPrint('No UID found in generateDigitalSibling method ref');
        return null;
      }

      // Lade die Methode aus der TNF_methods Sammlung
      final methodSnapshot = await FirebaseFirestore.instance
          .collection('TFC_methods')
          .doc(methodUID)
          .get();

      if (methodSnapshot.exists) {
        final methodData = methodSnapshot.data();
        final existenceStarts = methodData!['existenceStarts'];

        if (existenceStarts != null) {
          if (existenceStarts is Timestamp) {
            return existenceStarts.toDate();
          } else if (existenceStarts is String) {
            return DateTime.tryParse(existenceStarts);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting registration date: $e');
    }

    return null;
  }

  /// Formatiert ein DateTime als echtes Datum (dd.MM.yyyy)
  String _formatRealDate(DateTime? date) {
    if (date == null) return 'Unbekannt';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Wendet den ausgewählten Datumsfilter an
  void _applyDateFilter() {
    final now = DateTime.now();

    switch (selectedDateFilter) {
      case 'today':
        filteredFields = registeredFields.where((field) {
          final regDate = field["registrationDate"] as DateTime?;
          if (regDate == null) return false;
          return regDate.year == now.year &&
              regDate.month == now.month &&
              regDate.day == now.day;
        }).toList();
        break;
      case 'week':
        final oneWeekAgo = now.subtract(const Duration(days: 7));
        filteredFields = registeredFields.where((field) {
          final regDate = field["registrationDate"] as DateTime?;
          if (regDate == null) return false;
          return regDate.isAfter(oneWeekAgo);
        }).toList();
        break;
      case 'month':
        final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
        filteredFields = registeredFields.where((field) {
          final regDate = field["registrationDate"] as DateTime?;
          if (regDate == null) return false;
          return regDate.isAfter(oneMonthAgo);
        }).toList();
        break;
      case 'year':
        final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
        filteredFields = registeredFields.where((field) {
          final regDate = field["registrationDate"] as DateTime?;
          if (regDate == null) return false;
          return regDate.isAfter(oneYearAgo);
        }).toList();
        break;
      case 'specific':
        if (selectedSpecificDate != null) {
          filteredFields = registeredFields.where((field) {
            final regDate = field["registrationDate"] as DateTime?;
            if (regDate == null) return false;
            return regDate.year == selectedSpecificDate!.year &&
                regDate.month == selectedSpecificDate!.month &&
                regDate.day == selectedSpecificDate!.day;
          }).toList();
        } else {
          filteredFields = List.from(registeredFields);
        }
        break;
      case 'all':
      default:
        filteredFields = List.from(registeredFields);
        break;
    }
  }

  /// Öffnet einen Datumspicker zur Auswahl eines spezifischen Datums
  Future<void> _selectSpecificDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedSpecificDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedSpecificDate) {
      setState(() {
        selectedSpecificDate = picked;
        selectedDateFilter = 'specific';
        _applyDateFilter();
      });
    }
  }

  Future<void> _uploadCsvFile() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      debugPrint("Uploading CSV file...");
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(withReadStream: true, allowMultiple: false);

      if (result != null) {
        String csvContent = "";

        if (kIsWeb) {
          debugPrint("Reading CSV file in web...");
          for (PlatformFile file in result.files) {
            csvContent = "";
            await file.readStream
                ?.transform(utf8.decoder)
                .listen((chunk) {
                  csvContent += chunk;
                })
                .asFuture()
                .then((value) async {
                  await _processCsvData(csvContent);
                });
            // csvContent = String.fromCharCodes(result.files.single.bytes!);
          }
        } else {
          // Für mobile Plattformen
          File file = File(result.files.single.path!);
          csvContent = await file.readAsString();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.csvUploadError}: $e')),
      );
    }
  }

  /// Konvertiert Koordinaten vom CSV-Format in WKT-Format
  String _convertCoordinatesToWKT(String csvCoordinates) {
    try {
      // Entferne Leerzeichen und teile bei Semikolon
      final coordinatePairs = csvCoordinates.trim().split(';');

      List<String> wktCoordinates = [];

      for (String pair in coordinatePairs) {
        // Entferne eckige Klammern und teile bei Komma
        final cleanPair = pair.replaceAll('[', '').replaceAll(']', '').trim();
        final coords = cleanPair.split(',');

        if (coords.length == 2) {
          final lon = coords[0].trim();
          final lat = coords[1].trim();
          // WKT Format: lon lat (mit Leerzeichen, nicht Komma)
          wktCoordinates.add('$lon $lat');
        }
      }

      if (wktCoordinates.isNotEmpty) {
        // Stelle sicher, dass das Polygon geschlossen ist
        if (wktCoordinates.first != wktCoordinates.last) {
          wktCoordinates.add(wktCoordinates.first);
        }

        return 'POLYGON ((${wktCoordinates.join(', ')}))';
      }
    } catch (e) {
      debugPrint('Error converting coordinates: $e');
    }

    // Fallback: Gib die ursprünglichen Koordinaten zurück
    return csvCoordinates;
  }

  /// Konvertiert WKT-Koordinaten zu GeoJSON-Format (LatLng-Liste)
  List<List<double>> _convertWKTToGeoJSON(String wktCoordinates) {
    try {
      // Extrahiere die Koordinaten aus dem WKT-Format
      // Format: POLYGON ((-93.698 41.975, -93.692 41.975, ...))
      if (wktCoordinates.startsWith('POLYGON ')) {
        // Entferne "POLYGON ((" und "))" und teile die Koordinaten
        String coordsOnly =
            wktCoordinates.replaceAll('POLYGON ((', '').replaceAll('))', '');

        final coordinatePairs = coordsOnly.split(', ');
        List<List<double>> switchedPoints = [];

        for (String pair in coordinatePairs) {
          final coords = pair.trim().split(' ');
          if (coords.length == 2) {
            final lon = double.tryParse(coords[0].trim()) ?? 0.0;
            final lat = double.tryParse(coords[1].trim()) ?? 0.0;
            // Erstelle LatLng-Objekte mit vertauschten Koordinaten (lon wird zu lat, lat wird zu lon)
            final latLng = LatLng(lon,
                lat); // longitude wird zu latitude, latitude wird zu longitude
            switchedPoints.add(latLng.toJson());
          }
        }

        return switchedPoints;
      }
    } catch (e) {
      debugPrint('Error converting WKT to GeoJSON: $e');
    }

    // Fallback: Leere Koordinaten
    return <List<double>>[];
  }

  Future<void> _processCsvData(String csvContent) async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      isRegistering = true;
      showProgressOverlay = true;
    });

    try {
      List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvContent);

      if (csvData.isEmpty) {
        throw Exception(l10n.invalidCsvFormat);
      }

      int successCount = 0;
      int alreadyExistsCount = 0;
      int errorCount = 0;
      List<String> errors = []; // Set total fields count for progress tracking
      totalFields = csvData.length - 1; // Exclude header row
      setState(() {
        currentProgressStep = l10n.processingCsvFile;
      });
      for (int i = 1; i < csvData.length; i++) {
        //Skip header row
        final row = csvData[i];

        // Update progress - set current field index
        setState(() {
          currentFieldIndex = i;
        });

        // Erwarte mindestens 3 Spalten: Name, Beschreibung, Koordinaten
        if (row.length < 3) {
          errors.add(
              l10n.csvLineError((i + 1).toString(), l10n.invalidCsvFormat));
          errorCount++;
          continue;
        }
        final String registrar = row[0]?.toString().trim() ?? '';
        final String fieldNameDNI = row[1]?.toString().trim() ?? '';
        //Intermediary
        //Municipality
        //Community
        //Logo
        final String coordinatesRaw = row[6]?.toString().trim() ?? '';

        // Konvertiere Koordinaten vom CSV-Format zu WKT-Format
        final String coordinates = _convertCoordinatesToWKT(coordinatesRaw);

        if (fieldNameDNI.isEmpty || coordinatesRaw.isEmpty) {
          errors.add(l10n.csvLineNameCoordinatesRequired((i + 1).toString()));
          errorCount++;
          continue;
        }

        try {
          setState(() {
            currentFieldName = fieldNameDNI;
          });
          final returnCode =
              await _registerSingleField(fieldNameDNI, coordinates);

          if (returnCode == 'successfullyRegistered') {
            debugPrint('Field "$fieldNameDNI" successfully registered');
            successCount++;
          } else if (returnCode == 'alreadyRegistered') {
            debugPrint('Field "$fieldNameDNI" already exists');
            alreadyExistsCount++;
          } else {
            errors.add(l10n.csvLineError((i + 1).toString(), returnCode));
            errorCount++;
          }
        } catch (e) {
          errors.add(
              l10n.csvLineRegistrationError((i + 1).toString(), e.toString()));
          errorCount++;
        }
      }

      // Zeige Ergebnisse in einem Dialog
      String title = l10n.csvProcessingComplete;
      String message = '';
      if (successCount > 0) {
        message += '$successCount ${l10n.fieldsSuccessfullyRegistered}\n';
      }
      if (alreadyExistsCount > 0) {
        message += '$alreadyExistsCount ${l10n.fieldsAlreadyExisted}\n';
      }
      if (errorCount > 0) {
        message += '$errorCount ${l10n.fieldsWithErrors}';
      }

      // Zeige Info-Dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );

      if (errors.isNotEmpty && errors.length <= 5) {
        // Zeige erste paar Fehler
        _showErrorDialog(errors.take(5).join('\n'));
      } // Aktualisiere die Liste
      await _loadRegisteredFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.csvUploadError}: $e')),
      );
    } finally {
      setState(() {
        isRegistering = false;
        showProgressOverlay = false;
        currentProgressStep = '';
        currentFieldName = '';
        currentFieldIndex = 0;
        totalFields = 0;
      });
    }
  }

  Future<String> _registerSingleField(
      String fieldName, String coordinates) async {
    final l10n = AppLocalizations.of(context)!;
    bool alreadyExists = false;
    // Sicherheitsprüfungen für globale Variablen
    if (!localStorage!.isOpen) {
      return ("registrationError: localStorage is not open");
    }

    UserRegistryService? userRegistryService;
    try {
      // Schritt 1: Asset Registry Services initialisieren
      setState(() {
        currentProgressStep = l10n.progressStep1InitializingServices;
      });

      userRegistryService = UserRegistryService();
      await userRegistryService.initialize();

      // Anmeldedaten aus der .env-Datei lesen
      final userEmail = dotenv.env['USER_REGISTRY_EMAIL'] ?? '';
      final userPassword = dotenv.env['USER_REGISTRY_PASSWORD'] ?? '';

      if (userEmail.isEmpty || userPassword.isEmpty) {
        return ("registrationError: User Registry credentials not configured in .env file");
      }

      // Anmelden mit User Registry
      setState(() {
        currentProgressStep = l10n.progressStep1UserRegistryLogin;
      });

      final loginSuccess = await userRegistryService.login(
        email: userEmail,
        password: userPassword,
      );

      if (!loginSuccess) {
        return ('registrationError: User Registry Login fehlgeschlagen');
      }

      // Asset Registry Service erstellen
      final assetRegistryService = await AssetRegistryService.withUserRegistry(
        userRegistryService: userRegistryService,
      ); // Schritt 2: Feld bei Asset Registry registrieren
      setState(() {
        currentProgressStep = l10n.progressStep2RegisteringField;
      });

      final registerResponse = await assetRegistryService.registerFieldBoundary(
        s2Index:
            '8, 13', // Beispiel S2 Index, könnte aus Koordinaten berechnet werden
        wkt:
            coordinates, // Erwartet WKT-Format für Polygon (z.B. POLYGON ((-93.69805256358295 41.9757745318825, -93.69249086165937 41.97576056598778, -93.69245431117128 41.96883250535657, -93.69804142643369 41.97220658289061, -93.69805256358295 41.9757745318825)))
      );

      String? geoId;
      if (registerResponse.statusCode == 200) {
        // Erfolgreiche Registrierung
        setState(() {
          currentProgressStep = l10n.progressStep2FieldRegisteredSuccessfully;
        });

        debugPrint(
            'New field successfully registered: ${registerResponse.body}');
        try {
          final responseData =
              jsonDecode(registerResponse.body) as Map<String, dynamic>;
          final extractedGeoId = responseData['geoid'] as String?;

          if (extractedGeoId != null) {
            geoId = extractedGeoId;
            // Erfolgreiche GeoID-Extraktion für neues Feld anzeigen
            await _showRegistrationResult(
                l10n.fieldRegistrationNewGeoIdExtracted(extractedGeoId), true);
            //Neue GeoID wurde registriert, nun in TFC Persisteren
            Map<String, dynamic> newField = await getOpenRALTemplate("field");
            //Name
            newField["identity"]["name"] = fieldName; //GeoID
            newField["identity"]["alternateIDs"] = [
              {"UID": geoId, "issuedBy": "Asset Registry"}
            ];
            //Feldgrenzen - konvertiere WKT zu GeoJSON Format
            final coordinates_geojson = json.encode({
              "coordinates": _convertWKTToGeoJSON(coordinates),
            });
            setSpecificPropertyJSON(newField, "boundaries",
                json.encode(coordinates_geojson), "geoJSON");
            //Registrator UID => currentOwners
            newField["currentOwners"] = [
              {
                "UID": appUserDoc!["identity"]["UID"],
              }
            ];
            final newFieldUID = await generateDigitalSibling(newField);
            debugPrint(
                "New field with new GeoID registered in TFC with UID: $newFieldUID");
          } else {
            // GeoID-Extraktion fehlgeschlagen
            return ('registrationError: Could not extract geoID from response: No geoID in response');
          }
        } catch (e) {
          await _showRegistrationResult(
              l10n.fieldRegistrationNewGeoIdFailed(e.toString()), false);
          return ('registrationError: Could not extract geoID from response: $e');
        }
      } else if (registerResponse.statusCode == 400) {
        // Feld existiert bereits
        setState(() {
          currentProgressStep = l10n.progressStep2FieldAlreadyExists;
        });

        try {
          debugPrint('Field already exists, trying to extract geoID...');
          final responseData =
              jsonDecode(registerResponse.body) as Map<String, dynamic>;
          debugPrint(registerResponse.body);
          final matchedGeoIds =
              responseData['matched geo ids'] as List<dynamic>?;
          if (matchedGeoIds != null && matchedGeoIds.isNotEmpty) {
            alreadyExists = true;
            final extractedGeoId = matchedGeoIds.first as String;
            geoId = extractedGeoId;
            // Erfolgreiche GeoID-Extraktion für existierendes Feld anzeigen
            await _showRegistrationResult(
                l10n.fieldAlreadyExistsGeoIdExtracted(extractedGeoId), true);
          } else {
            return ('registrationError: No matched geo ids found in response');
          }
        } catch (e) {
          await _showRegistrationResult(
              l10n.fieldAlreadyExistsGeoIdFailed(e.toString()), false);
          return ('registrationError: Field already exists, but could not extract geoID: $e');
        }
      } else {
        return ('registrationError: Asset Registry ERROR: ${registerResponse.statusCode} - ${registerResponse.body}');
      } // An diesem Punkt sollte geoId immer gesetzt sein

      //! We got a finalGeoId, can be newly registered or already existing
      final finalGeoId = geoId;

      // Schritt 3: Prüfen ob Feld mit dieser GeoID bereits in der zentralen Firebase-Datenbank existiert
      setState(() {
        currentProgressStep =
            l10n.progressStep3CheckingCentralDatabase(finalGeoId);
      });

      debugPrint(
          'checking if GeoID $finalGeoId already exists in TFC database...');

      final existingFirebaseObjects =
          await getFirebaseObjectsByAlternateUID(finalGeoId);

      if (existingFirebaseObjects.isNotEmpty) {
        debugPrint(
            'Field with GeoID $finalGeoId is already registered in the central database (${existingFirebaseObjects.first["identity"]["UID"]}) - adding user as owner');
        //Add the appuser UID as owner to currentOwners list
        final existingField = existingFirebaseObjects.first;
        //Check the currentOwners list and add the appUserDoc UID if not already present
        final currentOwners = existingField["currentOwners"] ?? [];
        final appUserUID = appUserDoc!["identity"]["UID"];
        if (!currentOwners.any((owner) => owner["UID"] == appUserUID)) {
          currentOwners.add({"UID": appUserUID});
          existingField["currentOwners"] = currentOwners;
          // Update the field in the database
          await changeObjectData(existingField);
        }
        return ('alreadyRegistered');
      }
      setState(() {
        currentProgressStep = l10n.progressStep3FieldNotFoundInCentralDb;
      });
      debugPrint(
          'Field with GeoID $finalGeoId does not exist in the central database - proceeding with TFC registration');

      Map<String, dynamic> newField = await getOpenRALTemplate("field");
      //Name
      newField["identity"]["name"] = fieldName; //GeoID
      newField["identity"]["alternateIDs"] = [
        {"UID": geoId, "issuedBy": "Asset Registry"}
      ];
      //Feldgrenzen - konvertiere WKT zu GeoJSON Format
      final coordinates_geojson = json.encode({
        "coordinates": _convertWKTToGeoJSON(coordinates),
      });

      setSpecificPropertyJSON(
          newField, "boundaries", json.encode(coordinates_geojson), "geoJSON");
      //Registrator UID => currentOwners
      newField["currentOwners"] = [
        {
          "UID": appUserDoc!["identity"]["UID"],
        }
      ];
      final newFieldUID = await generateDigitalSibling(newField);
      debugPrint("New field registered in TFC with UID: $newFieldUID");
      if (!alreadyExists)
        await _showRegistrationResult(
            l10n.fieldRegistrationSuccessMessage(fieldName), true);

      if (alreadyExists) return ('alreadyRegistered');
      return 'successfullyRegistered';
    } catch (e) {
      // Fehlerbehandlung
      debugPrint('Error in _registerSingleField: $e');
      await _showRegistrationResult(
          l10n.fieldRegistrationErrorMessage(fieldName, e.toString()), false);
      rethrow;
    } finally {
      // Abmelden (falls userRegistryService initialisiert wurde)
      if (userRegistryService != null) {
        try {
          await userRegistryService.logout();
        } catch (e) {
          debugPrint('Error during logout: $e');
        }
      }
    }
  }

  /// Zeigt das Ergebnis der Registrierung für 2 Sekunden an
  Future<void> _showRegistrationResult(String message, bool isSuccess) async {
    setState(() {
      currentProgressStep = message;
    });

    // Warte 2 Sekunden bevor das Overlay geschlossen wird
    await Future.delayed(const Duration(seconds: 2));
  }

  void _showErrorDialog(String errors) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.registrationErrors),
        content: SingleChildScrollView(
          child: Text(errors),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _generateFieldsExcel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Create Excel file
    var excelFile = excel.Excel.createExcel();
    var sheet = excelFile.sheets[excelFile.getDefaultSheet()];

    // Add header row
    final headers = [
      l10n.fieldName,
      l10n.geoId,
      'Registrierungsdatum',
    ];

    // Add headers to first row
    for (var i = 0; i < headers.length; i++) {
      sheet!.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i] as dynamic;
    }

    // Add field data
    for (int i = 0; i < filteredFields.length; i++) {
      final field = filteredFields[i];
      final rowIndex = i + 1; // Start from row 1 (0 is header)

      // Field name
      sheet!.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          field["name"] ?? "Unbenanntes Feld");

      // GeoID
      sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
          field["geoId"] ?? "");

      // Registration Date
      sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
          field["registrationDate"] != null
              ? field["registrationDate"]
                  .toString()
                  .substring(0, 10) // YYYY-MM-DD format
              : "");
    }

    // Encode the file into bytes
    final List<int>? fileBytes = excelFile.encode();
    if (fileBytes != null) {
      try {
        await downloadFile(fileBytes, 'registered_fields.xlsx');
        if (kIsWeb) {
          await fshowInfoDialog(context, l10n.excelFileDownloaded);
        } else {
          await fshowInfoDialog(context, l10n.excelFileSavedAt);
        }
      } catch (e) {
        debugPrint("Error downloading file: $e");
        await fshowInfoDialog(context, l10n.failedToGenerateExcelFile);
      }
    } else {
      debugPrint("Failed to generate Excel file.");
      await fshowInfoDialog(context, l10n.failedToGenerateExcelFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.fieldRegistry),
            if (!isLoading && registeredFields.isNotEmpty)
              Text(
                l10n.fieldsCountSorted(
                  filteredFields.length.toString(),
                  registeredFields.length.toString(),
                  registeredFields.length.toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
          ],
        ),
        actions: [
          // Datum-Filter Dropdown
          if (!isLoading && registeredFields.isNotEmpty)
            PopupMenuButton<String>(
              initialValue: selectedDateFilter,
              onSelected: (value) async {
                if (value == 'specific') {
                  await _selectSpecificDate();
                } else {
                  setState(() {
                    selectedDateFilter = value;
                    if (value != 'specific') {
                      selectedSpecificDate = null;
                    }
                    _applyDateFilter();
                  });
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'all', child: Text(l10n.allFields)),
                PopupMenuItem(
                    value: 'today', child: Text(l10n.registeredToday)),
                PopupMenuItem(value: 'week', child: Text(l10n.lastWeek)),
                PopupMenuItem(value: 'month', child: Text(l10n.lastMonth)),
                PopupMenuItem(value: 'year', child: Text(l10n.lastYear)),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'specific',
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(selectedSpecificDate != null
                          ? _formatRealDate(selectedSpecificDate)
                          : l10n.specificDateLabel),
                    ],
                  ),
                ),
              ],
              icon: Icon(
                Icons.filter_list,
                color: selectedDateFilter != 'all' ? Colors.blue : null,
              ),
              tooltip: l10n.filterByRegistrationDate,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // if (kIsWeb) // Info über CSV-Format nur im Web anzeigen
              //   Container(
              //     width: double.infinity,
              //     padding: const EdgeInsets.all(16),
              //     margin: const EdgeInsets.all(16),
              //     decoration: BoxDecoration(
              //       color: Colors.blue.shade50,
              //       borderRadius: BorderRadius.circular(8),
              //       border: Border.all(color: Colors.blue.shade200),
              //     ),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           l10n.csvFormatInfo,
              //           style: const TextStyle(fontWeight: FontWeight.bold),
              //         ),
              //         const SizedBox(height: 8),
              //         const Text(
              //           'Beispiel:\nRegistrator,Feldname,,,,,\"[-88.364428,14.793867];[-88.364428,14.794047];[-88.364242,14.794047];[-88.364242,14.793867];[-88.364428,14.793867]\"',
              //           style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              //         ),
              //       ],
              //     ),
              //   ),
              if (isRegistering) const LinearProgressIndicator(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredFields.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.map,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  registeredFields.isEmpty
                                      ? l10n.noFieldsRegistered
                                      : l10n.noFieldsForSelectedTimeframe,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRegisteredFields,
                            child: ListView.builder(
                              itemCount: filteredFields.length,
                              itemBuilder: (context, index) {
                                final field = filteredFields[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.green,
                                      child: Icon(
                                        Icons.map,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      field["name"] ?? l10n.unnamedField,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (field["geoId"]?.isNotEmpty == true)
                                          Text(
                                              '${l10n.geoId}: ${field["geoId"]}'),
                                        if (field["area"]?.isNotEmpty == true)
                                          Text(
                                              '${l10n.area}: ${field["area"]} ha'),
                                        if (field["registrationDate"] != null)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.blue[200]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.blue[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${l10n.registeredOnLabel} ${_formatRealDate(field["registrationDate"])}',
                                                  style: TextStyle(
                                                    color: Colors.blue[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.copy),
                                    onTap: () async {
                                      // Copy GeoID to clipboard (works on all platforms)
                                      if (field["geoId"]?.isNotEmpty == true) {
                                        try {
                                          String textToCopy;
                                          String feedbackMessage;

                                          if (kDebugMode) {
                                            // In debug mode, copy the complete field JSON
                                            textToCopy =  field["uid"] as String;
                                            feedbackMessage =
                                                'Field uid copied to clipboard';
                                          } else {
                                            // In production mode, copy only the GeoID
                                            textToCopy =
                                                field["geoId"] as String;
                                            feedbackMessage =
                                                'GeoID copied to clipboard: $textToCopy';
                                          }

                                          await Clipboard.setData(
                                              ClipboardData(text: textToCopy));
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(feedbackMessage),
                                              ),
                                            );
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to copy to clipboard'),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          // Progress Overlay
          if (showProgressOverlay)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show CircularProgressIndicator only if not showing result
                      if (!currentProgressStep.startsWith('✅') &&
                          !currentProgressStep.startsWith('❌'))
                        const CircularProgressIndicator(),
                      // Show success/error icon when showing result
                      if (currentProgressStep.startsWith('✅'))
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 32,
                            color: Colors.green[800],
                          ),
                        ),
                      if (currentProgressStep.startsWith('❌'))
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error,
                            size: 32,
                            color: Colors.red[800],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.fieldRegistrationInProgress,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (totalFields > 0)
                        Column(
                          children: [
                            Text(
                              l10n.fieldXOfTotal(currentFieldIndex.toString(),
                                  totalFields.toString()),
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: currentFieldIndex / totalFields,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.green),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      if (currentFieldName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            l10n.currentField(currentFieldName),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[800],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: currentProgressStep.startsWith('✅')
                              ? Colors.green[50]
                              : currentProgressStep.startsWith('❌')
                                  ? Colors.red[50]
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: currentProgressStep.startsWith('✅')
                              ? Border.all(color: Colors.green[200]!)
                              : currentProgressStep.startsWith('❌')
                                  ? Border.all(color: Colors.red[200]!)
                                  : null,
                        ),
                        child: Text(
                          currentProgressStep,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: currentProgressStep.startsWith('✅')
                                        ? Colors.green[800]
                                        : currentProgressStep.startsWith('❌')
                                            ? Colors.red[800]
                                            : null,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: kIsWeb
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 200, // Feste Breite für beide Buttons
                  child: FloatingActionButton.extended(
                    heroTag: "exportExcel",
                    onPressed: (isRegistering ||
                            !_isAppFullyInitialized() ||
                            filteredFields.isEmpty)
                        ? null
                        : () => _generateFieldsExcel(context),
                    icon: const Icon(Icons.table_chart),
                    label: Text(l10n.exportToExcel),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200, // Feste Breite für beide Buttons
                  child: FloatingActionButton.extended(
                    heroTag: "uploadCsv",
                    onPressed: (isRegistering || !_isAppFullyInitialized())
                        ? null
                        : _uploadCsvFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.uploadCsv),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

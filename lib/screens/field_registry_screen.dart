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
import 'package:trace_foodchain_app/services/permission_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/utils/file_download.dart';
import 'package:trace_foodchain_app/screens/fast_upload_screen.dart';
import 'package:trace_foodchain_app/helpers/field_download_helper.dart';

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
      'week'; // 'all', 'today', 'week', 'month', 'year', 'specific'
  DateTime? selectedSpecificDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination
  static const int _pageSize = 50;
  bool _hasMoreData = false;
  bool _isLoadingMore = false;
  QueryDocumentSnapshot? _lastDocument;

  // Progress tracking variables
  bool showProgressOverlay = false;
  String currentProgressStep = '';
  String currentFieldName = '';
  int currentFieldIndex = 0;
  int totalFields = 0;
  List<String> progressSteps = [];

  // Dynamic loading status text
  String _loadingStatusText = '';

  void _setLoadingStatus(String text) {
    if (mounted) {
      setState(() {
        _loadingStatusText = text;
      });
    }
  }

  /// Prüft, ob alle erforderlichen globalen Variablen initialisiert sind
  bool _isAppFullyInitialized() {
    try {
      // Prüfe localStorage
      if (!localStorage!.isOpen) {
        return false;
      }

      // Prüfe ob localStorage tatsächlich funktioniert
      localStorage!.values.length; // Test access

      // Weitere Prüfungen können hier hinzugefügt werden
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    filteredFields = []; // Initialisiere die gefilterte Liste
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applySearchFilter();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRegisteredFields();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredFields() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _loadingStatusText = '';
      _lastDocument = null;
      _hasMoreData = false;
      registeredFields = [];
      filteredFields = [];
    });

    final l10n = AppLocalizations.of(context)!;
    _setLoadingStatus(l10n.loadingConnectingCloud);

    try {
      final result = await _fetchFieldsPage(
        _setLoadingStatus,
        l10n,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        registeredFields = result.$1;
        _lastDocument = result.$2;
        _hasMoreData = result.$3;
        _applySearchFilter();
      });
    } catch (e) {
      debugPrint('Error loading fields: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreFields() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _fetchFieldsPage(
        _setLoadingStatus,
        l10n,
        limit: _pageSize,
        startAfterDoc: _lastDocument,
      );
      if (!mounted) return;
      setState(() {
        registeredFields.addAll(result.$1);
        _lastDocument = result.$2;
        _hasMoreData = result.$3;
        _applySearchFilter();
      });
    } catch (e) {
      debugPrint('Error loading more fields: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadAllFields() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.loadAllFieldsTitle,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.loadAllFieldsWarning,
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.loadAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      isLoading = true;
      _loadingStatusText = '';
      _lastDocument = null;
      _hasMoreData = false;
      registeredFields = [];
      filteredFields = [];
    });
    _setLoadingStatus(l10n.loadingConnectingCloud);
    try {
      final result = await _fetchFieldsPage(
        _setLoadingStatus,
        l10n,
        limit: null,
      );
      if (!mounted) return;
      setState(() {
        registeredFields = result.$1;
        _lastDocument = result.$2;
        _hasMoreData = false;
        _applySearchFilter();
      });
    } catch (e) {
      debugPrint('Error loading all fields: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Gibt den Datumsbereich (fromDate, toDate) für den aktuellen Filter zurück.
  (DateTime? fromDate, DateTime? toDate) _getDateRangeForFilter() {
    final now = DateTime.now();
    switch (selectedDateFilter) {
      case 'today':
        final from = DateTime(now.year, now.month, now.day);
        return (from, from.add(const Duration(days: 1)));
      case 'week':
        return (now.subtract(const Duration(days: 7)), null);
      case 'month':
        return (DateTime(now.year, now.month - 1, now.day), null);
      case 'year':
        return (DateTime(now.year - 1, now.month, now.day), null);
      case 'specific':
        if (selectedSpecificDate != null) {
          final from = DateTime(selectedSpecificDate!.year,
              selectedSpecificDate!.month, selectedSpecificDate!.day);
          return (from, from.add(const Duration(days: 1)));
        }
        return (null, null);
      default: // 'all'
        return (null, null);
    }
  }

  /// Filtert [registeredFields] nach dem Suchbegriff und setzt [filteredFields].
  void _applySearchFilter() {
    if (_searchQuery.isNotEmpty) {
      filteredFields = registeredFields.where((field) {
        final name = (field["name"] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    } else {
      filteredFields = List.from(registeredFields);
    }
  }

  /// Lädt eine Seite Felder aus Firestore.
  /// Gibt (felder, letztesDokument, gibtWeitere) zurück.
  Future<(List<Map<String, dynamic>>, QueryDocumentSnapshot?, bool)>
      _fetchFieldsPage(
    void Function(String) onStatus,
    AppLocalizations l10n, {
    int? limit,
    QueryDocumentSnapshot? startAfterDoc,
  }) async {
    final List<Map<String, dynamic>> fields = [];
    QueryDocumentSnapshot? lastDocument;
    bool hasMore = false;

    try {
      final permissionService = PermissionService();
      final isSuperAdmin = permissionService.isSuperAdmin();
      final (fromDate, toDate) = _getDateRangeForFilter();

      if (isSuperAdmin) {
        debugPrint(
            'SUPERADMIN: Lade Felder (limit=$limit, fromDate=$fromDate)');
      }

      Query query;
      if (isSuperAdmin) {
        query = FirebaseFirestore.instance
            .collection('TFC_objects')
            .where('template.RALType', isEqualTo: 'field');
      } else {
        final currentUserUID = appUserDoc?["identity"]["UID"];
        if (currentUserUID == null) throw Exception('User not authenticated');
        query = FirebaseFirestore.instance
            .collection('TFC_objects')
            .where('currentOwners', arrayContains: {'UID': currentUserUID});
      }

      if (fromDate != null) {
        query = query.where('existenceStarts',
            isGreaterThanOrEqualTo: fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.where('existenceStarts',
            isLessThan: toDate.toIso8601String());
      }
      query = query.orderBy('existenceStarts', descending: true);

      final effectiveLimit = limit != null ? limit + 1 : null;
      if (effectiveLimit != null) {
        query = query.limit(effectiveLimit);
      }
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await query.get();
      } catch (e) {
        // Fallback ohne orderBy falls composite index fehlt
        debugPrint('Firestore-Query mit orderBy fehlgeschlagen, Fallback: $e');
        Query fallback = isSuperAdmin
            ? FirebaseFirestore.instance
                .collection('TFC_objects')
                .where('template.RALType', isEqualTo: 'field')
            : FirebaseFirestore.instance.collection('TFC_objects').where(
                'currentOwners',
                arrayContains: {'UID': appUserDoc?["identity"]["UID"] ?? ''});
        if (effectiveLimit != null) fallback = fallback.limit(effectiveLimit);
        querySnapshot = await fallback.get();
      }

      final docs = querySnapshot.docs;

      List<QueryDocumentSnapshot> docsToProcess;
      if (limit != null && docs.length > limit) {
        hasMore = true;
        docsToProcess = docs.take(limit).toList();
      } else {
        hasMore = false;
        docsToProcess = docs;
      }
      if (docsToProcess.isNotEmpty) {
        lastDocument = docsToProcess.last;
      }

      onStatus(l10n.loadingProcessingFields(docsToProcess.length.toString()));

      for (final doc in docsToProcess) {
        final fieldData = doc.data() as Map<String, dynamic>;
        try {
          final ralType = fieldData['template']?["RALType"];
          if (ralType != "field") continue;

          final objectState = fieldData["objectState"];
          if (objectState == "qcPending" || objectState == "qcRejected") {
            continue;
          }

          if (!isSuperAdmin) {
            final isFieldTestmode = fieldData.containsKey("isTestmode") &&
                fieldData["isTestmode"] == true;
            if (!isTestmode && isFieldTestmode) continue;
            if (isTestmode && !fieldData.containsKey("isTestmode")) continue;
          }

          try {
            final String fieldName =
                fieldData["identity"]?["name"] ?? "Unnamed Field";
            final String fieldUID = fieldData["identity"]?["UID"] ?? "";

            String geoId = "";
            try {
              if (fieldData["identity"]?["alternateIDs"] != null) {
                for (final altId in fieldData["identity"]["alternateIDs"]) {
                  if (altId["issuedBy"] == "Asset Registry") {
                    geoId = altId["UID"];
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint("ERROR extracting geoID: $e");
            }

            String area = "";
            try {
              final areaValue = getSpecificPropertyfromJSON(fieldData, "area");
              area = areaValue?.toString() ?? "";
            } catch (e) {
              debugPrint("ERROR extracting area: $e");
            }

            String boundaries = "";
            try {
              final boundariesValue =
                  getSpecificPropertyfromJSON(fieldData, "boundaries");
              boundaries = boundariesValue?.toString() ?? "";
            } catch (e) {
              debugPrint("ERROR extracting boundaries: $e");
            }

            final methodHistoryRef = fieldData["methodHistoryRef"] ?? [];
            final existenceStarts = fieldData["existenceStarts"];

            fields.add({
              "name": fieldName,
              "uid": fieldUID,
              "geoId": geoId,
              "area": area,
              "boundaries": boundaries,
              "methodHistoryRef": methodHistoryRef,
              "existenceStarts": existenceStarts,
            });
          } catch (e) {
            debugPrint("❌ ERROR extracting field data: $e");
          }
        } catch (e) {
          debugPrint("❌ CRITICAL ERROR processing field ${doc.id}: $e");
        }
      }

      debugPrint('Felder verarbeitet: ${fields.length}');
      final totalCount = fields.length;
      for (int i = 0; i < fields.length; i++) {
        final field = fields[i];
        final fieldName = field["name"] as String? ?? '';
        onStatus(l10n.loadingFieldDetailsProgress(
            (i + 1).toString(), totalCount.toString(), fieldName));

        DateTime? registrationDate;
        final existenceStartsStr = field["existenceStarts"];
        if (existenceStartsStr != null &&
            existenceStartsStr is String &&
            existenceStartsStr.isNotEmpty) {
          registrationDate = DateTime.tryParse(existenceStartsStr);
        }
        if (registrationDate == null) {
          registrationDate =
              await _getRegistrationDate(field["methodHistoryRef"]);
        }
        field["registrationDate"] = registrationDate;
      }

      // Sortiere nur wenn nicht schon von Firestore geordnet
      // (Fallback-Query liefert u.U. ungeordnete Ergebnisse)
      fields.sort((a, b) {
        final dateA = a["registrationDate"] as DateTime?;
        final dateB = b["registrationDate"] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint('Fehler in _fetchFieldsPage: $e');
    }

    return (fields, lastDocument, hasMore);
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
        return null;
      }

      final methodUID = generateDigitalSiblingRef["UID"];
      if (methodUID == null) {
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
    } catch (e) {}

    return null;
  }

  /// Formatiert ein DateTime als echtes Datum (dd.MM.yyyy)
  String _formatRealDate(DateTime? date) {
    if (date == null) return 'Unbekannt';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Gibt einen lokalisierten Label für den aktuellen Datumsfilter zurück.
  String _getFilterLabel(AppLocalizations l10n) {
    switch (selectedDateFilter) {
      case 'today':
        return l10n.registeredToday;
      case 'week':
        return l10n.lastWeek;
      case 'month':
        return l10n.lastMonth;
      case 'year':
        return l10n.lastYear;
      case 'specific':
        return selectedSpecificDate != null
            ? _formatRealDate(selectedSpecificDate)
            : l10n.specificDateLabel;
      default:
        return l10n.allFields;
    }
  }

  /// Wendet den ausgewählten Datumsfilter an (delegiert jetzt an _applySearchFilter,
  /// da die Datumsfilterung über Firestore erfolgt).
  void _applyDateFilter() {
    _applySearchFilter();
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
      });
      _loadRegisteredFields();
    }
  }

  Future<void> _uploadCsvFile() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      debugPrint('=== CSV Upload gestartet ===');
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(withReadStream: true, allowMultiple: false);

      if (result != null) {
        debugPrint('Datei ausgewählt: ${result.files.first.name}');
        String csvContent = "";

        if (kIsWeb) {
          debugPrint('Web-Plattform erkannt');
          for (PlatformFile file in result.files) {
            // Sammle die Bytes erst
            List<int> bytes = [];
            await file.readStream?.listen((chunk) {
              bytes.addAll(chunk);
            }, onError: (error) {
              debugPrint('FEHLER beim Lesen des Streams: $error');
              debugPrint('Error type: ${error.runtimeType}');
            }).asFuture();

            debugPrint('Bytes gelesen: ${bytes.length}');

            // Versuche verschiedene Encodings
            try {
              // Erst UTF-8 versuchen
              csvContent = utf8.decode(bytes);
              debugPrint('UTF-8 Dekodierung erfolgreich');
            } catch (e) {
              debugPrint('UTF-8 fehlgeschlagen: $e');
              try {
                // Dann Latin1 (ISO-8859-1) versuchen
                csvContent = latin1.decode(bytes);
                debugPrint('Latin1 Dekodierung erfolgreich');
              } catch (e2) {
                debugPrint('Latin1 fehlgeschlagen: $e2');
                // Fallback: UTF-8 mit allowMalformed
                csvContent = utf8.decode(bytes, allowMalformed: true);
                debugPrint(
                    'UTF-8 (allowMalformed) Dekodierung als Fallback verwendet');
              }
            }

            debugPrint(
                'CSV-Inhalt erfolgreich gelesen (${csvContent.length} Zeichen)');
            debugPrint(
                'Erste 200 Zeichen: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}');
            await _processCsvData(csvContent);
          }
        } else {
          debugPrint('Mobile Plattform erkannt');
          // Für mobile Plattformen
          File file = File(result.files.single.path!);

          // Lese Bytes und versuche verschiedene Encodings
          List<int> bytes = await file.readAsBytes();
          debugPrint('Bytes gelesen: ${bytes.length}');

          try {
            csvContent = utf8.decode(bytes);
            debugPrint('UTF-8 Dekodierung erfolgreich');
          } catch (e) {
            debugPrint('UTF-8 fehlgeschlagen: $e');
            try {
              csvContent = latin1.decode(bytes);
              debugPrint('Latin1 Dekodierung erfolgreich');
            } catch (e2) {
              debugPrint('Latin1 fehlgeschlagen: $e2');
              csvContent = utf8.decode(bytes, allowMalformed: true);
              debugPrint(
                  'UTF-8 (allowMalformed) Dekodierung als Fallback verwendet');
            }
          }

          debugPrint(
              'CSV-Inhalt erfolgreich gelesen (${csvContent.length} Zeichen)');
        }
      } else {
        debugPrint('Keine Datei ausgewählt');
      }
    } catch (e, stackTrace) {
      debugPrint('=== FEHLER beim CSV-Upload ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
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
    } catch (e) {}

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
    } catch (e) {}

    // Fallback: Leere Koordinaten
    return <List<double>>[];
  }

  Future<void> _processCsvData(String csvContent) async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      isRegistering = true;
      showProgressOverlay = true;
    });

    UserRegistryService? userRegistryService;
    AssetRegistryService? assetRegistryService;

    try {
      debugPrint('=== CSV Verarbeitung gestartet ===');
      debugPrint('CSV Content Länge: ${csvContent.length}');

      // Erkenne das Trennzeichen automatisch (Semikolon oder Komma)
      // Zähle nur Zeichen außerhalb von Anführungszeichen
      String fieldDelimiter = ',';
      final firstLine = csvContent.split('\n').first;

      int semicolonCount = 0;
      int commaCount = 0;
      bool insideQuotes = false;

      for (int i = 0; i < firstLine.length; i++) {
        final char = firstLine[i];
        if (char == '"') {
          insideQuotes = !insideQuotes;
        } else if (!insideQuotes) {
          if (char == ';') {
            semicolonCount++;
          } else if (char == ',') {
            commaCount++;
          }
        }
      }

      debugPrint('Semikola außerhalb von Quotes: $semicolonCount');
      debugPrint('Kommas außerhalb von Quotes: $commaCount');

      if (semicolonCount > commaCount) {
        fieldDelimiter = ';';
        debugPrint('Trennzeichen erkannt: Semikolon (;)');
      } else {
        debugPrint('Trennzeichen erkannt: Komma (,)');
      }

      // Erkenne Zeilenendezeichen automatisch (Windows: \r\n, Mac/Unix: \n, alte Mac: \r)
      String detectedEol = '\n';
      if (csvContent.contains('\r\n')) {
        detectedEol = '\r\n';
        debugPrint('Zeilenendezeichen erkannt: \\r\\n (Windows)');
      } else if (csvContent.contains('\r')) {
        detectedEol = '\r';
        debugPrint('Zeilenendezeichen erkannt: \\r (alte Mac)');
      } else {
        debugPrint('Zeilenendezeichen erkannt: \\n (Unix/Mac)');
      }

      List<List<dynamic>> csvData = CsvToListConverter(
        fieldDelimiter: fieldDelimiter,
        eol: detectedEol,
      ).convert(csvContent);

      debugPrint(
          'CSV zu Liste konvertiert: ${csvData.length} Zeilen mit Trennzeichen "$fieldDelimiter"');

      if (csvData.isEmpty) {
        debugPrint('FEHLER: CSV-Daten sind leer');
        throw Exception(l10n.invalidCsvFormat);
      }

      debugPrint('Erste Zeile (Header): ${csvData[0]}');
      debugPrint('Anzahl Spalten: ${csvData[0].length}');

      // Analysiere Header-Zeile und finde Spalten-Indizes
      final headerRow = csvData[0];
      Map<String, int> columnIndices = {};

      for (int i = 0; i < headerRow.length; i++) {
        final columnName = headerRow[i].toString().trim().toLowerCase();
        columnIndices[columnName] = i;
        debugPrint('Spalte $i: "$columnName"');
      }

      // Finde die benötigten Spalten (flexibel)
      int? nameIndex = columnIndices['name'];
      int? dniIndex = columnIndices['dni'] ??
          columnIndices['fieldname'] ??
          columnIndices['feldname'];
      int? polygonIndex = columnIndices['polygon'] ??
          columnIndices['coordinates'] ??
          columnIndices['koordinaten'];

      debugPrint('Spalten-Mapping:');
      debugPrint('  Name-Spalte: $nameIndex');
      debugPrint('  DNI/Feldname-Spalte: $dniIndex');
      debugPrint('  Polygon/Koordinaten-Spalte: $polygonIndex');

      if (nameIndex == null || dniIndex == null || polygonIndex == null) {
        debugPrint('FEHLER: Erforderliche Spalten nicht gefunden');
        debugPrint('Verfügbare Spalten: ${columnIndices.keys.toList()}');
        throw Exception(
            'CSV muss mindestens Spalten für Name, DNI/Feldname und Polygon/Koordinaten enthalten');
      }

      // Sicherheitsprüfungen für globale Variablen
      if (!localStorage!.isOpen) {
        throw Exception("localStorage is not open");
      }

      // Einmalige User Registry Initialisierung und Anmeldung
      setState(() {
        currentProgressStep = l10n.progressStep1InitializingServices;
      });

      userRegistryService = UserRegistryService();
      await userRegistryService.initialize();

      // Anmeldedaten aus der .env-Datei lesen
      final userEmail = dotenv.env['USER_REGISTRY_EMAIL'] ?? '';
      final userPassword = dotenv.env['USER_REGISTRY_PASSWORD'] ?? '';

      if (userEmail.isEmpty || userPassword.isEmpty) {
        throw Exception(
            "User Registry credentials not configured in .env file");
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
        throw Exception('User Registry Login fehlgeschlagen');
      }

      // Asset Registry Service erstellen
      assetRegistryService = await AssetRegistryService.withUserRegistry(
        userRegistryService: userRegistryService,
      );

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

        debugPrint('--- Zeile ${i + 1} wird verarbeitet ---');
        debugPrint('Rohdaten: $row');

        // Update progress - set current field index
        setState(() {
          currentFieldIndex = i;
        });

        // Prüfe ob die Zeile genug Spalten hat
        if (row.length <= nameIndex! ||
            row.length <= dniIndex! ||
            row.length <= polygonIndex!) {
          debugPrint(
              'FEHLER: Zeile ${i + 1} hat nur ${row.length} Spalten, aber benötigt mindestens ${[
                    nameIndex,
                    dniIndex,
                    polygonIndex
                  ].reduce((a, b) => a > b ? a : b) + 1}');
          errors.add(
              l10n.csvLineError((i + 1).toString(), l10n.invalidCsvFormat));
          errorCount++;
          continue;
        }

        // Extrahiere Werte basierend auf Header-Mapping
        final String fieldName = row[nameIndex]?.toString().trim() ?? '';
        final String fieldNameDNI = row[dniIndex]?.toString().trim() ?? '';
        final String coordinatesRaw =
            row[polygonIndex]?.toString().trim() ?? '';

        debugPrint('Name: $fieldName');
        debugPrint('DNI: $fieldNameDNI');
        debugPrint('Koordinaten (roh): $coordinatesRaw');

        // Konvertiere Koordinaten vom CSV-Format zu WKT-Format
        final String coordinates = _convertCoordinatesToWKT(coordinatesRaw);
        debugPrint(
            'Koordinaten (WKT): ${coordinates.substring(0, coordinates.length > 100 ? 100 : coordinates.length)}...');

        if (fieldNameDNI.isEmpty || coordinatesRaw.isEmpty) {
          debugPrint('FEHLER: Zeile ${i + 1} - DNI oder Koordinaten fehlen');
          errors.add(l10n.csvLineNameCoordinatesRequired((i + 1).toString()));
          errorCount++;
          continue;
        }

        try {
          setState(() {
            currentFieldName =
                fieldName; // fieldNameDNI;//!!!!! Check and change if needed
          });
          debugPrint('Registriere Feld: $currentFieldName');
          final returnCode = await _registerSingleField(
              currentFieldName, coordinates, assetRegistryService);

          debugPrint('Registrierung returnCode: $returnCode');

          if (returnCode == 'successfullyRegistered') {
            successCount++;
            debugPrint('✅ Feld erfolgreich registriert');
          } else if (returnCode == 'alreadyRegistered') {
            alreadyExistsCount++;
            debugPrint('ℹ️ Feld existiert bereits');
          } else if (returnCode == 'cancelledByUser') {
            debugPrint('⛔ Import vom Benutzer abgebrochen');
            break;
          } else {
            errors.add(l10n.csvLineError((i + 1).toString(), returnCode));
            errorCount++;
            debugPrint('❌ Fehler bei Registrierung: $returnCode');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ EXCEPTION bei Zeile ${i + 1}: $e');
          debugPrint('Stack trace: $stackTrace');
          errors.add(
              l10n.csvLineRegistrationError((i + 1).toString(), e.toString()));
          errorCount++;
        }
      }

      debugPrint('=== CSV Verarbeitung abgeschlossen ===');
      debugPrint('Erfolgreich: $successCount');
      debugPrint('Existieren bereits: $alreadyExistsCount');
      debugPrint('Fehler: $errorCount');

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
        debugPrint('Zeige Fehler-Dialog mit ${errors.length} Fehlern');
        _showErrorDialog(errors.take(5).join('\n'));
      } // Aktualisiere die Liste
      await _loadRegisteredFields();
    } catch (e, stackTrace) {
      debugPrint('=== SCHWERWIEGENDER FEHLER in _processCsvData ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.csvUploadError}: $e')),
      );
    } finally {
      // Abmelden (falls userRegistryService initialisiert wurde)
      if (userRegistryService != null) {
        try {
          await userRegistryService.logout();
        } catch (e) {}
      }

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

  Future<String> _registerSingleField(String fieldName, String coordinates,
      AssetRegistryService assetRegistryService) async {
    final l10n = AppLocalizations.of(context)!;
    bool alreadyExists = false;

    try {
      // Step 2: Register field with Asset Registry
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
        //
        //!   FIELD WAS REGISTERED SUCCESSFULLY IN ASSET REGISTRY - GENERATE OPENRAL OBJECT OF THE FIELD
        //
        setState(() {
          currentProgressStep = l10n.progressStep2FieldRegisteredSuccessfully;
        });

        try {
          final responseData =
              jsonDecode(registerResponse.body) as Map<String, dynamic>;
          // Die API gibt "Geo Id" (mit Leerzeichen und Großbuchstaben) zurück
          final extractedGeoId = responseData['Geo Id'] as String?;

          if (extractedGeoId != null) {
            geoId = extractedGeoId;
            // Erfolgreiche GeoID-Extraktion für neues Feld anzeigen
            await _showRegistrationResult(
                l10n.fieldRegistrationNewGeoIdExtracted(extractedGeoId), true);
            //Neue GeoID wurde registriert, nun in TFC Persisteren
            Map<String, dynamic> newField = await getOpenRALTemplate("field");
            //Name
            newField["identity"]["name"] = fieldName; //GeoID
            newField["existenceStarts"] = DateTime.now().toIso8601String();
            newField["objectState"] = "undefined";
            newField["identity"]["alternateIDs"] = [
              {"UID": geoId, "issuedBy": "Asset Registry"}
            ];
            //Feldgrenzen - konvertiere WKT zu GeoJSON Format
            final coordinates_geojson = json.encode({
              "coordinates": _convertWKTToGeoJSON(coordinates),
            });
            setSpecificPropertyJSON(
                newField, "boundaries", coordinates_geojson, "String");
            //Registrator UID => currentOwners
            newField["currentOwners"] = [
              {
                "UID": appUserDoc!["identity"]["UID"],
              }
            ];
            final newFieldUID = await generateDigitalSibling(newField);
          } else {
            // GeoID-Extraktion fehlgeschlagen
            return ('registrationError: Could not extract geoID from response: No geoID in response. Response body: ${registerResponse.body}');
          }
        } catch (e) {
          await _showRegistrationResult(
              l10n.fieldRegistrationNewGeoIdFailed(e.toString()), false);
          return ('registrationError: Could not extract geoID from response: $e');
        }
      } else if (registerResponse.statusCode == 400) {
        //
        //!   FIELD HAS BEEN ALREADY REGISTERED IN ASSET REGISTRY BEFORE
        //
        setState(() {
          currentProgressStep = l10n.progressStep2FieldAlreadyExists;
        });

        try {
          final responseData =
              jsonDecode(registerResponse.body) as Map<String, dynamic>;
          debugPrint(registerResponse.body);
          //This is important to see return of GeoID registry service
          try {
            final matchedGeoIds =
                responseData['matched geo ids'] as List<dynamic>?;
            if (matchedGeoIds != null && matchedGeoIds.isNotEmpty) {
              alreadyExists = true;
              final extractedGeoId = matchedGeoIds.first as String;
              geoId = extractedGeoId;
              // Show returned existing GeoIDs
              await _showRegistrationResult(
                  l10n.fieldAlreadyExistsGeoIdExtracted(extractedGeoId), true);
            } else {
              return ('registrationError: No matched geo ids found in response');
            }
          } catch (e) {
            return ('registrationError: provider did not return geoIDs: $e');
          }
        } catch (e) {
          await _showRegistrationResult(
              l10n.fieldAlreadyExistsGeoIdFailed(e.toString()), false);
          return ('registrationError: Field already exists, but could not extract geoID: $e');
        }
      } else {
        return ('registrationError: Asset Registry ERROR: ${registerResponse.statusCode} - ${registerResponse.body}');
      }

      //! We got a finalGeoId, can be newly registered or already existing
      final finalGeoId = geoId;

      // Step 3: Check if field with this GeoID already exists in the central Firebase database
      setState(() {
        currentProgressStep =
            l10n.progressStep3CheckingCentralDatabase(finalGeoId);
      });

      final existingFirebaseObjects =
          await getFirebaseObjectsByAlternateUID(finalGeoId);

      if (existingFirebaseObjects.isNotEmpty) {
        //  - adding user as owner');
        //Add the appuser UID as owner to currentOwners list
        Map<String, dynamic> existingField =
            Map<String, dynamic>.from(existingFirebaseObjects.first);
        //Check the currentOwners list and add the appUserDoc UID if not already present
        final currentOwners =
            List<dynamic>.from(existingField["currentOwners"] ?? []);
        final appUserUID = appUserDoc!["identity"]["UID"];
        final hasBoundaries =
            (getSpecificPropertyfromJSON(existingField, "boundaries") ?? "")
                .toString()
                .isNotEmpty;
        final hasStartDate =
            (existingField["existenceStarts"] ?? "").toString().isNotEmpty;

        final coordinatesGeojson = json.encode({
          "coordinates": _convertWKTToGeoJSON(coordinates),
        });

        // Prüfe ob Namens-Diskrepanz vorliegt
        final existingName = existingField["identity"]["name"] as String? ?? "";
        final hasNameDiscrepancy = existingName.isNotEmpty &&
            existingName != "N/A" &&
            existingName.toLowerCase() != fieldName.toLowerCase();

        if (hasNameDiscrepancy) {
          final dialogResult = await showDialog<bool?>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(
                l10n.fieldNameDiscrepancyTitle,
                style: const TextStyle(color: Colors.black),
              ),
              content: Text(
                l10n.fieldNameDiscrepancyMessage(existingName, fieldName),
                style: const TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(
                    l10n.fieldNameDiscrepancyCancel,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    l10n.fieldNameDiscrepancyKeepExisting(existingName),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.fieldNameDiscrepancyUseNew(fieldName)),
                ),
              ],
            ),
          );
          if (dialogResult == null) {
            return ('cancelledByUser');
          }
          if (dialogResult == true) {
            existingField["identity"]["name"] = fieldName;
          }
        }

        if (!currentOwners.any((owner) => owner["UID"] == appUserUID) ||
            !hasBoundaries ||
            !hasStartDate ||
            existingField["identity"]["name"] == "N/A" ||
            hasNameDiscrepancy) {
          if (existingField["identity"]["name"] == "N/A") {
            existingField["identity"]["name"] = fieldName;
          }

          if (!hasBoundaries) {
            existingField = setSpecificPropertyJSON(
                existingField, "boundaries", coordinatesGeojson, "geojson");
          }

          if (!hasStartDate) {
            existingField["existenceStarts"] = DateTime.now().toIso8601String();
          }

          if (!currentOwners.any((owner) => owner["UID"] == appUserUID)) {
            currentOwners.add({"UID": appUserUID});
          }
          existingField["currentOwners"] = currentOwners;
          // Update the field in the database
          await changeObjectData(existingField, syncFromCloud: false);
        }
        return ('alreadyRegistered');
      }

      //There is no openral object in the central database with this geoID, we need to create it now
      setState(() {
        currentProgressStep = l10n.progressStep3FieldNotFoundInCentralDb;
      });

      Map<String, dynamic> newField = await getOpenRALTemplate("field");
      //Name
      newField["identity"]["name"] = fieldName; //GeoID
      newField["existenceStarts"] = DateTime.now().toIso8601String();
      newField["objectState"] = "undefined";
      newField["identity"]["alternateIDs"] = [
        {"UID": geoId, "issuedBy": "Asset Registry"}
      ];
      //Feldgrenzen - konvertiere WKT zu GeoJSON Format
      final coordinates_geojson = json.encode({
        "coordinates": _convertWKTToGeoJSON(coordinates),
      });

      newField = setSpecificPropertyJSON(
          newField, "boundaries", coordinates_geojson, "geojson");
      //Registrator UID => currentOwners
      newField["currentOwners"] = [
        {
          "UID": appUserDoc!["identity"]["UID"],
        }
      ];
      final newFieldUID =
          await generateDigitalSibling(newField, syncFromCloud: false);

      if (!alreadyExists)
        await _showRegistrationResult(
            l10n.fieldRegistrationSuccessMessage(fieldName), true);

      if (alreadyExists) return ('alreadyRegistered');
      return 'successfullyRegistered';
    } catch (e) {
      // Fehlerbehandlung

      await _showRegistrationResult(
          l10n.fieldRegistrationErrorMessage(fieldName, e.toString()), false);
      rethrow;
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
        await fshowInfoDialog(context, l10n.failedToGenerateExcelFile);
      }
    } else {
      await fshowInfoDialog(context, l10n.failedToGenerateExcelFile);
    }
  }

  void _showFieldActions(Map<String, dynamic> field) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    field["name"] as String? ?? l10n.unnamedField,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if ((field["geoId"] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      '${l10n.geoId}: ${field["geoId"]}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blue),
                  title: Text(l10n.copyGeoId,
                      style: const TextStyle(color: Colors.black87)),
                  enabled: (field["geoId"] as String?)?.isNotEmpty == true,
                  onTap: () {
                    Navigator.pop(ctx);
                    final geoId = field["geoId"] as String? ?? '';
                    Clipboard.setData(ClipboardData(text: geoId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('GeoID copied: $geoId')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.green),
                  title: Text(l10n.downloadGeoJSON,
                      style: const TextStyle(color: Colors.black87)),
                  subtitle: Text('*.geojson',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final l10n = AppLocalizations.of(context)!;
                    FieldDownloadHelper.downloadGeoJSON(
                      context,
                      name: field['name'] as String? ?? 'field',
                      boundariesJson: field['boundaries'] as String?,
                      l10n: l10n,
                      geoId: field['geoId'] as String?,
                      area: field['area'] as String?,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: Colors.orange),
                  title: Text(l10n.downloadKML,
                      style: const TextStyle(color: Colors.black87)),
                  subtitle: Text('*.kml  (Google Earth, QGIS, …)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final l10n = AppLocalizations.of(context)!;
                    FieldDownloadHelper.downloadKML(
                      context,
                      name: field['name'] as String? ?? 'Field',
                      boundariesJson: field['boundaries'] as String?,
                      l10n: l10n,
                      area: field['area'] as String?,
                      geoId: field['geoId'] as String?,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
            Text(
              () {
                final filterLabel = _getFilterLabel(l10n);
                final limitLabel = _hasMoreData
                    ? '${registeredFields.length}+'
                    : registeredFields.length.toString();
                return '$filterLabel · $limitLabel';
              }(),
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
                  });
                  _loadRegisteredFields();
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
              if (!isLoading && registeredFields.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: l10n.searchFields,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            if (_loadingStatusText.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _loadingStatusText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
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
                                      : _searchQuery.isNotEmpty
                                          ? l10n.noFieldsForSearch(_searchQuery)
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
                                    trailing: const Icon(Icons.more_vert),
                                    onTap: () => _showFieldActions(field),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
              // Load More / Load All Buttons
              if (!isLoading && _hasMoreData && _searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingMore ? null : _loadMoreFields,
                          icon: _isLoadingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more),
                          label: Text(
                            l10n.loadMore,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingMore ? null : _loadAllFields,
                          icon: const Icon(Icons.download),
                          label: Text(
                            l10n.loadAll,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
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
                  width: 200,
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
                  width: 200,
                  child: FloatingActionButton.extended(
                    heroTag: "uploadCsv",
                    onPressed: (isRegistering || !_isAppFullyInitialized())
                        ? null
                        : _uploadCsvFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.uploadCsv),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: FloatingActionButton.extended(
                    heroTag: "fastUpload",
                    onPressed: (isRegistering || !_isAppFullyInitialized())
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FastUploadScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.bolt),
                    label: Text(l10n.fastUpload),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

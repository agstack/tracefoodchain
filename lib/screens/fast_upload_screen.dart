import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:trace_foodchain_app/l10n/app_localizations.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/user_registry_api_service.dart';
import 'package:trace_foodchain_app/utils/file_download.dart';

/// Hält das aufbereitete Ergebnis pro Feld für die DB-Persistierung.
class _FieldResult {
  final String fieldName;
  final String geoId;
  final bool isCreated;
  final bool isAlreadyRegistered;
  final List<List<double>> coordinates; // [lon, lat]-Paare (GeoJSON-Ring)

  const _FieldResult({
    required this.fieldName,
    required this.geoId,
    required this.isCreated,
    required this.isAlreadyRegistered,
    required this.coordinates,
  });
}

/// Fast-Upload-Screen: CSV → GeoJSON FeatureCollection → AgStack Bulk-Upload
///
/// Linke Seite  : Dateiauswahl + Aktions-Buttons
/// Rechte Seite : Terminal-Style Debug-Log (auto-scroll)
class FastUploadScreen extends StatefulWidget {
  const FastUploadScreen({super.key});

  @override
  State<FastUploadScreen> createState() => _FastUploadScreenState();
}

class _FastUploadScreenState extends State<FastUploadScreen> {
  // ── l10n Cache ───────────────────────────────────────────────────────────
  late AppLocalizations _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
  }

  // ── State ────────────────────────────────────────────────────────────────
  final List<_LogEntry> _logEntries = [];
  final ScrollController _scrollController = ScrollController();

  bool _isProcessing = false;
  String? _selectedFileName;
  String? _csvContent;

  // Feldnamen aus der CSV in Reihenfolge (Index=0 → result[0])
  final List<String> _parsedFieldNames = [];

  // Koordinaten pro Feld, parallel zu _parsedFieldNames (GeoJSON-Ring: [[lon,lat],...])
  final List<List<List<double>>> _parsedFieldCoords = [];

  // Gesammelte GeoIDs aus der Server-Antwort (befüllt nach erfolgreichem Upload)
  final List<String> _collectedGeoIds = [];

  // Aufbereitete Ergebnisse für DB-Persistierung (befüllt nach Antwortanalyse)
  final List<_FieldResult> _persistableResults = [];
  bool _isPersisting = false;
  bool _persistenceComplete = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  void _reset() {
    _logEntries.clear();
    _parsedFieldNames.clear();
    _parsedFieldCoords.clear();
    _collectedGeoIds.clear();
    _persistableResults.clear();
    setState(() {
      _selectedFileName = null;
      _csvContent = null;
      _isPersisting = false;
      _persistenceComplete = false;
    });
  }

  // ── Logging ──────────────────────────────────────────────────────────────

  void _log(String message, {_LogLevel level = _LogLevel.info}) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = _LogEntry(timestamp: ts, message: message, level: level);

    debugPrint('[$ts] $message');

    if (mounted) {
      setState(() => _logEntries.add(entry));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _logSection(String title) => _log(
      '── $title ${('─' * (44 - title.length)).substring(0, (44 - title.length).clamp(0, 44))}',
      level: _LogLevel.section);

  void _logDivider() => _log('═══════════════════════════════════════════════',
      level: _LogLevel.section);

  // ── Datei auswählen ──────────────────────────────────────────────────────

  Future<void> _pickCsvFile() async {
    _log(_l10n.fuLogOpeningFilePicker);
    try {
      final result = await FilePicker.platform.pickFiles(
        withReadStream: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null) {
        _log(_l10n.fuLogCancelled, level: _LogLevel.warning);
        return;
      }

      final file = result.files.first;
      _log(_l10n.fuLogFileSelected(file.name, _formatBytes(file.size)));

      // Bytes lesen
      String csvContent = '';
      if (kIsWeb) {
        _log(_l10n.fuLogWebPlatform);
        final List<int> bytes = [];
        await file.readStream
            ?.listen((chunk) => bytes.addAll(chunk))
            .asFuture();
        _log(_l10n.fuLogBytesReceived(_formatBytes(bytes.length)));
        csvContent = _decodeBytes(bytes);
      } else {
        _log(_l10n.fuLogNativePlatform);
        final bytes = await File(file.path!).readAsBytes();
        _log(_l10n.fuLogBytesRead(_formatBytes(bytes.length)));
        csvContent = _decodeBytes(bytes);
      }

      setState(() {
        _selectedFileName = file.name;
        _csvContent = csvContent;
      });

      final lineCount = csvContent.split('\n').length;
      _log(_l10n.fuLogCsvLoaded, level: _LogLevel.success);
      _log(_l10n.fuLogTotalLines(lineCount));
      _log(_l10n.fuLogTotalChars(csvContent.length));
      _log(_l10n.fuLogFirst120);
      _log(csvContent.substring(0, csvContent.length.clamp(0, 120)));
      _log('');
      _log(_l10n.fuLogCsvReady);
    } catch (e, st) {
      _log(_l10n.fuLogFileLoadError(e.toString()), level: _LogLevel.error);
      _log('   ${st.toString().split('\n').first}', level: _LogLevel.error);
    }
  }

  // ── CSV → GeoJSON → Upload ───────────────────────────────────────────────

  Future<void> _processAndUpload() async {
    if (_csvContent == null) {
      _log(_l10n.fuLogNoCsvLoaded, level: _LogLevel.warning);
      return;
    }

    setState(() => _isProcessing = true);
    _logDivider();
    _log(_l10n.fuLogUploadStarted, level: _LogLevel.info);
    _logDivider();

    try {
      // ── Schritt 1: CSV parsen → GeoJSON Features ──────────────────────
      _log('');
      _logSection(_l10n.fuLogStep1);
      final features = _parseCsvToGeoJsonFeatures(_csvContent!);

      if (features.isEmpty) {
        _log(_l10n.fuLogNoPolygons, level: _LogLevel.error);
        return;
      }
      _log(_l10n.fuLogPolygonsExtracted(features.length),
          level: _LogLevel.success);
      _log(_l10n.fuLogFieldNamesCached(_parsedFieldNames.length));

      // ── Schritt 2: GeoJSON FeatureCollection bauen ────────────────────
      _log('');
      _logSection(_l10n.fuLogStep2);
      final featureCollection = {
        'type': 'FeatureCollection',
        'features': features,
      };
      final geoJsonString = jsonEncode(featureCollection);
      final geoJsonBytes = utf8.encode(geoJsonString);

      _log(_l10n.fuLogFeatureCollectionCreated, level: _LogLevel.success);
      _log(_l10n.fuLogFeatures(features.length));
      _log(_l10n.fuLogSize(_formatBytes(geoJsonBytes.length)));

      // Erstes Feature zur Kontrolle ausgeben
      if (features.isNotEmpty) {
        final coords =
            (features[0]['geometry']['coordinates'] as List)[0] as List;
        _log(_l10n.fuLogFeature0Points(coords.length));
        _log('   Erster Punkt: ${coords.first}');
        _log('   Letzter Punkt: ${coords.last}');
      }

      // ── Schritt 3: API-Authentifizierung ──────────────────────────────
      _log('');
      _logSection(_l10n.fuLogStep3);

      final userEmail = dotenv.env['USER_REGISTRY_EMAIL'] ?? '';
      final userPassword = dotenv.env['USER_REGISTRY_PASSWORD'] ?? '';

      if (userEmail.isEmpty || userPassword.isEmpty) {
        _log(_l10n.fuLogCredentialsMissing, level: _LogLevel.error);
        _log(_l10n.fuLogCredentialsNeeded('USER_REGISTRY_EMAIL'));
        _log(_l10n.fuLogCredentialsNeeded('USER_REGISTRY_PASSWORD'));
        return;
      }

      _log(_l10n.fuLogEmail(_maskEmail(userEmail)));
      _log(_l10n.fuLogConnecting, level: _LogLevel.info);
      _log('   POST https://user-registry.agstack.org/login');

      final userRegistryService = UserRegistryService();
      await userRegistryService.initialize();
      _log(_l10n.fuLogServiceInitialized);

      final loginSuccess = await userRegistryService.login(
        email: userEmail,
        password: userPassword,
      );

      if (!loginSuccess) {
        _log(_l10n.fuLogLoginFailed, level: _LogLevel.error);
        return;
      }

      final tokenPreview =
          userRegistryService.accessToken?.substring(0, 20) ?? '(leer)';
      _log(_l10n.fuLogLoginSuccess, level: _LogLevel.success);
      _log(_l10n.fuLogTokenPreview(tokenPreview));

      // ── Schritt 4: GeoJSON hochladen per Multipart ────────────────────
      _log('');
      _logSection(_l10n.fuLogStep4);

      // Timeout dynamisch berechnen: 2 Sekunden pro Polygon + 60 Sekunden Puffer.
      // Hintergrund: Die Cloud benötigt ca. 1 s/Polygon; mit Faktor 2 haben wir
      // genug Reserve. Minimum 120 s, Maximum 7200 s (2 Stunden).
      final int timeoutSeconds = (features.length * 2 + 60).clamp(120, 7200);
      final String timeoutLabel = timeoutSeconds >= 3600
          ? '${(timeoutSeconds / 3600).toStringAsFixed(1)} h'
          : timeoutSeconds >= 60
              ? '${(timeoutSeconds / 60).toStringAsFixed(0)} min'
              : '$timeoutSeconds s';

      const uploadUrl =
          'https://api-ar.agstack.org/register-field-boundaries-geojson';
      _log(_l10n.fuLogSendingMultipart, level: _LogLevel.info);
      _log('   URL      : POST $uploadUrl');
      _log('   Dateiname: fields.geojson');
      _log(_l10n.fuLogSize(_formatBytes(geoJsonBytes.length)));
      _log(_l10n.fuLogTimeout(timeoutLabel, timeoutSeconds, features.length));

      final uri = Uri.parse(uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${userRegistryService.accessToken}'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          geoJsonBytes,
          filename: 'fields.geojson',
        ));

      _log(_l10n.fuLogWaitingForServer, level: _LogLevel.info);

      final streamed =
          await request.send().timeout(Duration(seconds: timeoutSeconds));
      final response = await http.Response.fromStream(streamed);

      // ── Schritt 5: Antwort auswerten ──────────────────────────────────
      _log('');
      _logSection(_l10n.fuLogStep5);
      _log(_l10n.fuLogHttpStatus(
          response.statusCode, _httpStatusText(response.statusCode)));
      _log(_l10n.fuLogContentType(response.headers['content-type'] ?? ''));
      _log(_l10n.fuLogResponseSize(_formatBytes(response.bodyBytes.length)));
      _log('');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log(_l10n.fuLogUploadSuccess(response.statusCode),
            level: _LogLevel.success);
      } else {
        _log(_l10n.fuLogServerError(response.statusCode),
            level: _LogLevel.error);
      }

      _log('');
      _analyzeAndLogBulkResponse(response.body);

      // Logout
      try {
        await userRegistryService.logout();
        _log('');
        _log(_l10n.fuLogLoggedOut);
      } catch (_) {
        _log(_l10n.fuLogLogoutFailed, level: _LogLevel.warning);
      }
    } catch (e, st) {
      _log('');
      _logDivider();
      _log(_l10n.fuLogException(e.toString()), level: _LogLevel.error);
      _log('   ${st.toString().split('\n').first}', level: _LogLevel.error);
      _logDivider();
    } finally {
      setState(() => _isProcessing = false);
      _log('');
      _logDivider();
      _log(_l10n.fuLogProcessDone);
      _logDivider();
    }
  }

  // ── GeoID-Export ─────────────────────────────────────────────────────────

  Future<void> _saveGeoIds() async {
    if (_collectedGeoIds.isEmpty) return;

    // Dateiinhalt: eine GeoID pro Zeile
    final content = _collectedGeoIds.join('\n');
    final bytes = utf8.encode(content);

    final ts = DateTime.now();
    final filename =
        'geoids_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.txt';

    _log('');
    _log(_l10n.fuLogSavingGeoIds(_collectedGeoIds.length, filename));

    try {
      await downloadFile(bytes, filename);
      _log(_l10n.fuLogGeoIdsSaved(filename), level: _LogLevel.success);
    } catch (e) {
      _log(_l10n.fuLogSaveError(e.toString()), level: _LogLevel.error);
    }
  }

  // ── Response-Analyse ─────────────────────────────────────────────────────

  /// Analysiert die Antwort des Bulk-Endpunkts detailliert im Terminal.
  ///
  /// Erwartetes Format:
  /// ```json
  /// {
  ///   "message": "...",
  ///   "results": [
  ///     {
  ///       "geo_id": "abc...",
  ///       "message": "Field Boundary registered successfully",
  ///       "status": "created",         // oder "already_registered" o.ä.
  ///       "s2_cell_tokens": { "8": [...], "13": [...], "wkt": "POLYGON (...)" },
  ///       "geo_json": { "geometry": {...}, "properties": {...} }
  ///     }, ...
  ///   ]
  /// }
  /// ```

  /// Extrahiert die GeoID aus einem Result-Objekt.
  ///
  /// Probiert alle bekannten Felder des AgStack-APIs (Einzel + Bulk):
  ///   - `geo_id`            → Bulk-Endpunkt, neu registriert
  ///   - `Geo Id`            → Einzel-Endpunkt (mit Leerzeichen + Großbuchstaben)
  ///   - `matched_geo_ids`   → Bulk-Endpunkt, bereits vorhanden (Array)
  ///   - `matched geo ids`   → Einzel-Endpunkt Status 400 (Array mit Leerzeichen)
  String _extractGeoId(Map r) {
    // 1. Direktes geo_id-Feld (Bulk-Endpunkt Standardfall)
    final direct = r['geo_id'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }

    // 2. "Geo Id" mit Leerzeichen (Einzel-Endpunkt Erfolg)
    final geoIdSpace = r['Geo Id'];
    if (geoIdSpace != null && geoIdSpace.toString().isNotEmpty) {
      return geoIdSpace.toString();
    }

    // 3. matched_geo_ids Array (Bulk-Endpunkt "already registered")
    final matchedUnderscore = r['matched_geo_ids'];
    if (matchedUnderscore is List && matchedUnderscore.isNotEmpty) {
      final first = matchedUnderscore.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    // 4. "matched geo ids" mit Leerzeichen (Einzel-Endpunkt Status 400)
    final matchedSpace = r['matched geo ids'];
    if (matchedSpace is List && matchedSpace.isNotEmpty) {
      final first = matchedSpace.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    // 5. Fallback: geo_id tief in geo_json.properties (falls dort abgelegt)
    final geoJson = r['geo_json'];
    if (geoJson is Map) {
      final props = geoJson['properties'];
      if (props is Map) {
        final propGeoId = props['geo_id'] ?? props['Geo Id'];
        if (propGeoId != null && propGeoId.toString().isNotEmpty) {
          return propGeoId.toString();
        }
      }
    }

    return '';
  }

  void _analyzeAndLogBulkResponse(String body) {
    _logSection(_l10n.fuLogRawPreview);
    // Ersten 500 Zeichen als Rohtext für schnellen Überblick
    final preview = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    _log(preview);
    _log('');
    _logSection(_l10n.fuLogDetailedAnalysis);

    try {
      final parsed = jsonDecode(body);

      if (parsed is! Map) {
        _log(_l10n.fuLogNotJsonObject, level: _LogLevel.warning);
        _log(body);
        return;
      }

      // Top-Level Nachricht
      final topMsg = parsed['message']?.toString() ?? '(keine Nachricht)';
      _log(_l10n.fuLogServerMessage(topMsg));

      // Kein results-Array → unerwartetes Format
      if (!parsed.containsKey('results')) {
        _log('');
        _log(_l10n.fuLogNoResultsArray, level: _LogLevel.warning);
        _log(_l10n.fuLogFullResponse);
        final pretty = const JsonEncoder.withIndent('  ').convert(parsed);
        for (final line in pretty.split('\n')) {
          _log('  $line');
        }
        return;
      }

      final results = parsed['results'] as List;
      _log(_l10n.fuLogTotalResults(results.length));
      _log('');

      // GeoID-Sammlung und Persistier-Ergebnisse zurücksetzen (neue Antwort)
      _collectedGeoIds.clear();
      _persistableResults.clear();

      int created = 0;
      int alreadyRegistered = 0;
      int errorCount = 0;
      final List<String> errorMessages = [];

      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        if (r is! Map) {
          _log(_l10n.fuLogEntryNotObject(i, r.toString()),
              level: _LogLevel.warning);
          errorCount++;
          continue;
        }

        // Feldname aus CSV (falls vorhanden)
        final fieldName = i < _parsedFieldNames.length
            ? _parsedFieldNames[i]
            : 'Feld_${i + 1}';

        final geoId = _extractGeoId(r);
        final itemMsg = r['message']?.toString() ?? '';
        final status = r['status']?.toString() ?? '';

        // Status bestimmen – die API verwendet unterschiedliche Status-Strings
        final isCreated = status == 'created';
        final isAlreadyRegistered = status == 'already_registered' ||
            status == 'already_exists' ||
            status == 'existing' ||
            itemMsg.toLowerCase().contains('already') ||
            itemMsg.toLowerCase().contains('exists');

        if (isCreated) {
          created++;
        } else if (isAlreadyRegistered) {
          alreadyRegistered++;
        } else if (status.isNotEmpty && !isCreated && !isAlreadyRegistered) {
          errorCount++;
          errorMessages.add('[${i + 1}] $fieldName: $status – $itemMsg');
        }

        // ── Pro-Eintrag Ausgabe ───────────────────────────────────────
        _log('┌─ [${(i + 1).toString().padLeft(3, '0')}] $fieldName',
            level: isCreated
                ? _LogLevel.success
                : isAlreadyRegistered
                    ? _LogLevel.info
                    : _LogLevel.error);

        // Status mit Icon
        final statusIcon = isCreated
            ? '✅ NEU REGISTRIERT'
            : isAlreadyRegistered
                ? 'ℹ️  BEREITS VORHANDEN'
                : '❌ FEHLER ($status)';
        _log(
            isCreated
                ? _l10n.fuLogStatusNew
                : isAlreadyRegistered
                    ? _l10n.fuLogStatusExisting
                    : _l10n.fuLogStatusError(status),
            level: isCreated
                ? _LogLevel.success
                : isAlreadyRegistered
                    ? _LogLevel.info
                    : _LogLevel.error);

        // GeoID – Quellfeld anzeigen damit Debugging einfacher wird
        if (geoId.isNotEmpty) {
          _collectedGeoIds.add(geoId); // für Export sammeln
          // Für DB-Persistierung merken
          _persistableResults.add(_FieldResult(
            fieldName: fieldName,
            geoId: geoId,
            isCreated: isCreated,
            isAlreadyRegistered: isAlreadyRegistered,
            coordinates: i < _parsedFieldCoords.length
                ? _parsedFieldCoords[i]
                : <List<double>>[],
          ));
          // Quelle bestimmen für Debug-Info
          final src = r['geo_id'] != null && r['geo_id'].toString().isNotEmpty
              ? 'geo_id'
              : r['Geo Id'] != null && r['Geo Id'].toString().isNotEmpty
                  ? 'Geo Id'
                  : (r['matched_geo_ids'] is List &&
                          (r['matched_geo_ids'] as List).isNotEmpty)
                      ? 'matched_geo_ids[0]'
                      : (r['matched geo ids'] is List &&
                              (r['matched geo ids'] as List).isNotEmpty)
                          ? 'matched geo ids[0]'
                          : 'geo_json.properties';
          _log(_l10n.fuLogGeoIdSource(geoId, src));
        } else {
          _log(_l10n.fuLogGeoIdMissing, level: _LogLevel.warning);
        }

        // API-Nachricht
        if (itemMsg.isNotEmpty) {
          _log(_l10n.fuLogApiMessage(itemMsg));
        }

        // S2-Cell-Tokens
        final s2 = r['s2_cell_tokens'];
        if (s2 is Map) {
          final wkt = s2['wkt']?.toString();
          if (wkt != null) {
            // WKT kürzen für Terminal-Anzeige
            final wktShort =
                wkt.length > 100 ? '${wkt.substring(0, 100)}...' : wkt;
            _log('│  WKT     : $wktShort');
          }

          // S2-Level-8 Tokens
          final level8 = s2['8'];
          if (level8 is List && level8.isNotEmpty) {
            _log('│  S2 L-8  : ${level8.join(', ')}');
          }

          // S2-Level-13 Tokens
          final level13 = s2['13'];
          if (level13 is List && level13.isNotEmpty) {
            _log('│  S2 L-13 : ${level13.join(', ')}');
          }
        }

        // GeoJSON Koordinaten-Zusammenfassung
        final geoJson = r['geo_json'];
        if (geoJson is Map) {
          final geometry = geoJson['geometry'];
          if (geometry is Map) {
            final coords = geometry['coordinates'];
            if (coords is List && coords.isNotEmpty) {
              final ring = coords[0];
              if (ring is List) {
                _log(_l10n.fuLogCoordPoints(ring.length));
                if (ring.isNotEmpty && ring.first is List) {
                  final fp = ring.first as List;
                  _log('│  Erster  : [${fp.join(', ')}]');
                }
              }
            }
          }

          // Properties
          final props = geoJson['properties'];
          if (props is Map) {
            final boundaryType = props['boundary_type']?.toString() ?? '';
            final s2Index = props['s2_index']?.toString() ?? '';
            if (boundaryType.isNotEmpty || s2Index.isNotEmpty) {
              _log(
                  '│  Props   : boundary_type=$boundaryType  s2_index=$s2Index');
            }
          }
        }

        _log('└' + '─' * 52);
        _log('');
      }

      // ── Zusammenfassung ───────────────────────────────────────────────
      _logSection(_l10n.fuLogSummary);
      _log(_l10n.fuLogSummaryTotal(results.length));
      _log(_l10n.fuLogSummaryNew(created),
          level: created > 0 ? _LogLevel.success : _LogLevel.info);
      _log(_l10n.fuLogSummaryExisting(alreadyRegistered));
      if (errorCount > 0) {
        _log(_l10n.fuLogSummaryErrors(errorCount), level: _LogLevel.error);
        _log('');
        _log(_l10n.fuLogErrorDetails, level: _LogLevel.error);
        for (final e in errorMessages) {
          _log('     $e', level: _LogLevel.error);
        }
      }
      if (_collectedGeoIds.isNotEmpty) {
        _log('');
        _log(_l10n.fuLogGeoIdsReadyForExport(_collectedGeoIds.length),
            level: _LogLevel.success);
        _log(_l10n.fuLogClickSaveButton);
        setState(() {}); // Button-Sichtbarkeit aktualisieren
      }
    } catch (e, st) {
      _log(_l10n.fuLogParseError(e.toString()), level: _LogLevel.error);
      _log('   ${st.toString().split('\n').first}', level: _LogLevel.error);
      _log('');
      _log(_l10n.fuLogRawText);
      for (final line in body.split('\n')) {
        _log(line);
      }
    }
  }

  // ── CSV → Features ───────────────────────────────────────────────────────

  // ── DB-Persistierung ─────────────────────────────────────────────────────

  /// Persistiert alle gesammelten Feld-Ergebnisse als openRAL-Objekte in der DB.
  /// Läuft asynchron nach dem Upload – UI bleibt weiterhin bedienbar.
  Future<void> _persistResults({bool dryRun = false}) async {
    if (_persistableResults.isEmpty) return;
    setState(() => _isPersisting = true);

    _logDivider();
    if (dryRun) {
      _logSection(_l10n.fuLogDryRunHeader(_persistableResults.length));
      _log(_l10n.fuLogDryRunSubtitle);
    } else {
      _logSection(_l10n.fuLogPersistHeader(_persistableResults.length));
      _log(_l10n.fuLogPersistSubtitle);
    }
    _log('');

    int successNew = 0;
    int successExisting = 0;
    int errors = 0;

    for (int i = 0; i < _persistableResults.length; i++) {
      final result = _persistableResults[i];
      _log(
          '[${(i + 1).toString().padLeft(3, '0')}/${_persistableResults.length.toString().padLeft(3, '0')}] "${result.fieldName}"');

      try {
        final coordinatesGeojson =
            json.encode({'coordinates': result.coordinates});
        final appUserUID = appUserDoc!['identity']['UID'] as String;

        if (result.isCreated) {
          if (dryRun) {
            _log(_l10n.fuLogDryRunWouldCreate);
            _log(_l10n.fuLogDryRunName(result.fieldName));
            _log(_l10n.fuLogDryRunGeoId(result.geoId));
            _log(_l10n.fuLogDryRunOwner(appUserUID));
            _log(_l10n.fuLogDryRunCoords(
                result.coordinates.length,
                result.coordinates.isNotEmpty
                    ? result.coordinates.first.toString()
                    : '-'));
          } else {
            //  Neues Feld: openRAL-Objekt erstellen und mit generateDigitalSibling persistieren
            Map<String, dynamic> newField = await getOpenRALTemplate('field');
            newField['identity']['name'] = result.fieldName;
            newField['existenceStarts'] = DateTime.now().toIso8601String();
            newField['objectState'] = 'undefined';
            newField['identity']['alternateIDs'] = [
              {'UID': result.geoId, 'issuedBy': 'Asset Registry'}
            ];
            newField = setSpecificPropertyJSON(
                newField, 'boundaries', coordinatesGeojson, 'geojson');
            newField['currentOwners'] = [
              {'UID': appUserUID}
            ];
            await generateDigitalSibling(newField, syncFromCloud: false);
            _log(_l10n.fuLogPersistedNew(result.geoId),
                level: _LogLevel.success);
          }
          successNew++;
        } else {
          if (dryRun) {
            _log(_l10n.fuLogDryRunQuerying(result.geoId));
            final existingObjects =
                await getFirebaseObjectsByAlternateUID(result.geoId);
            if (existingObjects.isEmpty) {
              _log(_l10n.fuLogDryRunNotFound, level: _LogLevel.warning);
              _log(_l10n.fuLogDryRunWouldCreateNew);
              _log(_l10n.fuLogDryRunName(result.fieldName));
              _log(_l10n.fuLogDryRunOwner(appUserUID));
              _log(_l10n.fuLogDryRunCoords(
                  result.coordinates.length,
                  result.coordinates.isNotEmpty
                      ? result.coordinates.first.toString()
                      : '-'));
            } else {
              final existing = Map<String, dynamic>.from(existingObjects.first);
              final currentOwners =
                  List<dynamic>.from(existing['currentOwners'] ?? []);
              final hasBoundaries =
                  (getSpecificPropertyfromJSON(existing, 'boundaries') ?? '')
                      .toString()
                      .isNotEmpty;
              final hasStartDate =
                  (existing['existenceStarts'] ?? '').toString().isNotEmpty;
              final hasOwner = currentOwners.any((o) => o['UID'] == appUserUID);
              final existingName =
                  existing['identity']['name'] as String? ?? '';

              _log(_l10n.fuLogDryRunFound, level: _LogLevel.success);
              _log(_l10n.fuLogDryRunDbName(existingName));
              _log(_l10n.fuLogDryRunFlags(hasBoundaries.toString(),
                  hasStartDate.toString(), hasOwner.toString()));
              final actions = <String>[];
              if (!hasOwner) actions.add(_l10n.fuLogDryRunAddOwner(appUserUID));
              if (!hasBoundaries) actions.add(_l10n.fuLogDryRunSetBoundaries);
              if (!hasStartDate) actions.add(_l10n.fuLogDryRunSetStartDate);
              if (existingName == 'N/A')
                actions.add(_l10n.fuLogDryRunSetName(result.fieldName));
              if (actions.isEmpty) {
                _log(_l10n.fuLogDryRunNoChange);
              } else {
                _log(_l10n.fuLogDryRunActions(actions.join(' | ')));
              }
            }
            successExisting++;
          } else {
            //  Bestehendes Feld: in Firebase nachschlagen, ggf. aktualisieren
            final existingObjects =
                await getFirebaseObjectsByAlternateUID(result.geoId);

            if (existingObjects.isNotEmpty) {
              Map<String, dynamic> existing =
                  Map<String, dynamic>.from(existingObjects.first);
              final currentOwners =
                  List<dynamic>.from(existing['currentOwners'] ?? []);
              final hasBoundaries =
                  (getSpecificPropertyfromJSON(existing, 'boundaries') ?? '')
                      .toString()
                      .isNotEmpty;
              final hasStartDate =
                  (existing['existenceStarts'] ?? '').toString().isNotEmpty;
              final hasOwner = currentOwners.any((o) => o['UID'] == appUserUID);

              bool changed = false;

              if (!hasOwner) {
                currentOwners.add({'UID': appUserUID});
                existing['currentOwners'] = currentOwners;
                changed = true;
              }
              if (!hasBoundaries) {
                existing = setSpecificPropertyJSON(
                    existing, 'boundaries', coordinatesGeojson, 'geojson');
                changed = true;
              }
              if (!hasStartDate) {
                existing['existenceStarts'] = DateTime.now().toIso8601String();
                changed = true;
              }
              if (existing['identity']['name'] == 'N/A') {
                existing['identity']['name'] = result.fieldName;
                changed = true;
              }

              if (changed) {
                await changeObjectData(existing, syncFromCloud: false);
                _log(_l10n.fuLogPersistedUpdated(result.geoId),
                    level: _LogLevel.success);
              } else {
                _log(_l10n.fuLogPersistedAlreadyFull(result.geoId));
              }
              successExisting++;
            } else {
              // Kein Firebase-Eintrag vorhanden: neu anlegen mit bekannter GeoID
              Map<String, dynamic> newField = await getOpenRALTemplate('field');
              newField['identity']['name'] = result.fieldName;
              newField['existenceStarts'] = DateTime.now().toIso8601String();
              newField['objectState'] = 'undefined';
              newField['identity']['alternateIDs'] = [
                {'UID': result.geoId, 'issuedBy': 'Asset Registry'}
              ];
              newField = setSpecificPropertyJSON(
                  newField, 'boundaries', coordinatesGeojson, 'geojson');
              newField['currentOwners'] = [
                {'UID': appUserUID}
              ];
              await generateDigitalSibling(newField, syncFromCloud: false);
              _log(_l10n.fuLogPersistedNewFromExisting(result.geoId),
                  level: _LogLevel.success);
              successNew++;
            }
          }
        }
      } catch (e) {
        _log(_l10n.fuLogPersistError(e.toString()), level: _LogLevel.error);
        errors++;
      }
    }

    _logDivider();
    if (dryRun) {
      _logSection(_l10n.fuLogDryRunDone);
      _log(_l10n.fuLogDryRunSummaryNew(successNew));
      _log(_l10n.fuLogDryRunSummaryUpdated(successExisting));
    } else {
      _logSection(_l10n.fuLogPersistDone);
      _log(_l10n.fuLogPersistSummaryNew(successNew));
      _log(_l10n.fuLogPersistSummaryUpdated(successExisting));
    }
    if (errors > 0) {
      _log(_l10n.fuLogPersistSummaryErrors(errors), level: _LogLevel.error);
    }

    setState(() {
      _isPersisting = false;
      _persistenceComplete =
          !dryRun; // nur echter Lauf markiert als abgeschlossen
    });
  }

  List<Map<String, dynamic>> _parseCsvToGeoJsonFeatures(String csvContent) {
    // Trennzeichen erkennen
    final firstLine = csvContent.split('\n').first;
    int semicolons = 0, commas = 0;
    bool inQuotes = false;
    for (final ch in firstLine.split('')) {
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == ';') semicolons++;
        if (ch == ',') commas++;
      }
    }
    final delimiter = semicolons > commas ? ';' : ',';
    _log(_l10n.fuLogDelimiterDetected(delimiter, semicolons, commas));

    // Zeilen-Ende erkennen
    final String eol;
    if (csvContent.contains('\r\n')) {
      eol = '\r\n';
      _log(_l10n.fuLogEolWindows);
    } else if (csvContent.contains('\r')) {
      eol = '\r';
      _log(_l10n.fuLogEolMac);
    } else {
      eol = '\n';
      _log(_l10n.fuLogEolUnix);
    }

    final csvData = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: eol,
    ).convert(csvContent);

    _log(_l10n.fuLogParsedRows(csvData.length));

    if (csvData.length < 2) {
      _log(_l10n.fuLogNoCsvDataRows, level: _LogLevel.error);
      return [];
    }

    // Header-Spalten mappen
    final header = csvData[0];
    final cols = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      cols[header[i].toString().trim().toLowerCase()] = i;
    }
    _log(_l10n.fuLogHeaderColumns(cols.keys.toList().toString()));

    final polygonIdx =
        cols['polygon'] ?? cols['coordinates'] ?? cols['koordinaten'];
    final nameIdx = cols['name'];

    if (polygonIdx == null) {
      _log(_l10n.fuLogNoPolygonColumn, level: _LogLevel.error);
      _log(_l10n.fuLogAvailableColumns(cols.keys.toList().toString()));
      return [];
    }

    _log(_l10n.fuLogPolygonColumn(polygonIdx, header[polygonIdx].toString()));
    if (nameIdx != null) {
      _log(_l10n.fuLogNameColumn(nameIdx!, header[nameIdx].toString()));
    } else {
      _log(_l10n.fuLogNoNameColumn);
    }

    // Feldnamen-Liste zurücksetzen und neu befüllen
    _parsedFieldNames.clear();
    _parsedFieldCoords.clear();

    final features = <Map<String, dynamic>>[];
    int skipped = 0;

    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];

      if (row.length <= polygonIdx) {
        _log(_l10n.fuLogRowTooShort(i + 1, row.length, polygonIdx),
            level: _LogLevel.warning);
        skipped++;
        continue;
      }

      final rawCoords = row[polygonIdx]?.toString().trim() ?? '';
      final fieldName = (nameIdx != null && row.length > nameIdx)
          ? (row[nameIdx]?.toString().trim().isNotEmpty == true
              ? row[nameIdx].toString().trim()
              : 'Feld_$i')
          : 'Feld_$i';

      if (rawCoords.isEmpty) {
        _log(_l10n.fuLogEmptyCoords(i + 1, fieldName),
            level: _LogLevel.warning);
        skipped++;
        continue;
      }

      final coords = _parseCoordinatesToRing(rawCoords);

      if (coords.length < 4) {
        _log(_l10n.fuLogTooFewPoints(i + 1, fieldName),
            level: _LogLevel.warning);
        skipped++;
        continue;
      }

      _log(_l10n.fuLogRowParsed(i + 1, fieldName, coords.length));

      _parsedFieldNames.add(fieldName); // für Ergebnis-Korrelation
      _parsedFieldCoords.add(coords); // Koordinaten für DB-Persistierung
      features.add({
        'type': 'Feature',
        'properties': {'s2_index': '8,13'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coords],
        },
      });
    }

    if (skipped > 0) {
      _log(_l10n.fuLogSkipped(skipped), level: _LogLevel.warning);
    }
    _log(_l10n.fuLogParseSummary(features.length, skipped));
    return features;
  }

  /// Wandelt das CSV-Koordinatenformat in einen geschlossenen GeoJSON-Ring um.
  ///
  /// Unterstützte Eingabeformate:
  ///   [-88.36,14.79];[-88.37,14.79];...   (Semikolon-getrennte [lon,lat]-Paare)
  List<List<double>> _parseCoordinatesToRing(String raw) {
    final points = <List<double>>[];
    try {
      for (final part in raw.split(';')) {
        final clean = part.replaceAll('[', '').replaceAll(']', '').trim();
        if (clean.isEmpty) continue;
        final parts = clean.split(',');
        if (parts.length < 2) continue;
        final lon = double.tryParse(parts[0].trim());
        final lat = double.tryParse(parts[1].trim());
        if (lon != null && lat != null) {
          points.add([lon, lat]);
        }
      }

      // Polygon schließen
      if (points.length >= 2) {
        if (points.first[0] != points.last[0] ||
            points.first[1] != points.last[1]) {
          points.add(List<double>.from(points.first));
        }
      }
    } catch (_) {}
    return points;
  }

  // ── Hilfsfunktionen ──────────────────────────────────────────────────────

  String _decodeBytes(List<int> bytes) {
    try {
      final s = utf8.decode(bytes);
      _log(_l10n.fuLogEncodingUtf8);
      return s;
    } catch (_) {}
    try {
      final s = latin1.decode(bytes);
      _log(_l10n.fuLogEncodingLatin1);
      return s;
    } catch (_) {}
    _log(_l10n.fuLogEncodingFallback, level: _LogLevel.warning);
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _maskEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx < 3) return email;
    return '${email.substring(0, 3)}${'*' * (atIdx - 3)}${email.substring(atIdx)}';
  }

  String _httpStatusText(int code) {
    const map = {
      200: 'OK',
      201: 'Created',
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      422: 'Unprocessable Entity',
      500: 'Internal Server Error',
    };
    return map[code] ?? '';
  }

  void _printFormattedResponse(String body) {
    try {
      final parsed = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(parsed);
      for (final line in pretty.split('\n')) {
        _log(line);
      }

      // Zusammenfassung wenn "results" vorhanden
      if (parsed is Map && parsed.containsKey('results')) {
        final results = parsed['results'] as List;
        _log('');
        _logSection(_l10n.fuLogSummary);
        int created = 0, existing = 0, other = 0;
        for (final r in results) {
          if (r is Map) {
            final status = r['status']?.toString() ?? '';
            if (status == 'created') {
              created++;
            } else if (status == 'existing' || status == 'already_exists') {
              existing++;
            } else {
              other++;
            }
          }
        }
        _log(_l10n.fuLogSummaryTotal(results.length));
        _log(_l10n.fuLogSummaryNew(created), level: _LogLevel.success);
        _log(_l10n.fuLogSummaryExisting(existing));
        if (other > 0) {
          _log(_l10n.fuLogStatusError(other.toString()),
              level: _LogLevel.warning);
        }
      }
    } catch (_) {
      _log(_l10n.fuLogNotJsonObject);
      for (final line in body.split('\n')) {
        _log(line);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.fastUploadTitle,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Linkes Panel ────────────────────────────────────────────
            SizedBox(
              width: 260,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── CSV-Datei ──────────────────────────────────────────
                      _SectionLabel(l10n.fastUploadCsvSection),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickCsvFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.fastUploadPickCsv),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueGrey[700],
                        ),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 10),
                        _FileChip(name: _selectedFileName!),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),

                      // ── Aktionen ───────────────────────────────────────────
                      _SectionLabel(l10n.fastUploadActionSection),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: (_isProcessing || _csvContent == null)
                            ? null
                            : _processAndUpload,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isProcessing
                              ? l10n.fastUploadProcessing
                              : l10n.fastUploadProcess,
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _reset,
                        icon: const Icon(Icons.clear_all),
                        label: Text(l10n.fastUploadReset),
                      ),
                      if (_collectedGeoIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _saveGeoIds,
                          icon: const Icon(Icons.download),
                          label: Text(l10n
                              .fastUploadSaveGeoIds(_collectedGeoIds.length)),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.indigo[600],
                          ),
                        ),
                      ],
                      if (_persistableResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Dry-Run Button (nur im Debug-Modus sichtbar)
                        if (kDebugMode) ...[
                          OutlinedButton.icon(
                            onPressed: (_isProcessing || _isPersisting)
                                ? null
                                : () => _persistResults(dryRun: true),
                            icon:
                                const Icon(Icons.search, color: Colors.orange),
                            label: Text(
                              l10n.fastUploadDryRun,
                              style: const TextStyle(color: Colors.orange),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        ElevatedButton.icon(
                          onPressed: (_isProcessing || _isPersisting)
                              ? null
                              : () => _persistResults(),
                          icon: _isPersisting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(_persistenceComplete
                                  ? Icons.check_circle
                                  : Icons.storage),
                          label: Text(
                            _isPersisting
                                ? l10n.fastUploadPersisting
                                : _persistenceComplete
                                    ? l10n.fastUploadPersistenceComplete
                                    : l10n.fastUploadPersistToDb(
                                        _persistableResults.length),
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _persistenceComplete
                                ? Colors.teal[700]
                                : Colors.deepOrange[700],
                          ),
                        ),
                      ],

                      const Spacer(),
                      const Divider(),

                      // ── Format-Hinweis ─────────────────────────────────────
                      Text(
                        l10n.fastUploadFormatHint,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.fastUploadFormatHintBody,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // ── Rechtes Panel: Terminal ──────────────────────────────────
            Expanded(
              child: _TerminalWidget(
                entries: _logEntries,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Datenklassen ─────────────────────────────────────────────────────────────

enum _LogLevel { info, success, warning, error, section }

class _LogEntry {
  final String timestamp;
  final String message;
  final _LogLevel level;

  const _LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });
}

// ── Hilfs-Widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  const _FileChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: Colors.green[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[800],
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalWidget extends StatelessWidget {
  final List<_LogEntry> entries;
  final ScrollController scrollController;

  const _TerminalWidget({
    required this.entries,
    required this.scrollController,
  });

  static const _bg = Color(0xFF1E1E1E);
  static const _headerBg = Color(0xFF2D2D2D);

  Color _colorForLevel(_LogLevel level) {
    switch (level) {
      case _LogLevel.success:
        return const Color(0xFF4EC9B0); // teal-green
      case _LogLevel.error:
        return const Color(0xFFF44747); // red
      case _LogLevel.warning:
        return const Color(0xFFDCDCAA); // yellow
      case _LogLevel.section:
        return const Color(0xFF6796E6); // blue
      case _LogLevel.info:
        return const Color(0xFFD4D4D4); // light grey
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _bg,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal-Titelleiste
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 15, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Fast Upload – Debug Terminal',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length} Zeilen',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Log-Bereich
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      '> Warte auf Aktion ...',
                      style: TextStyle(
                        color: Color(0xFF555555),
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (_, idx) {
                      final e = entries[idx];
                      return Text(
                        '[${e.timestamp}] ${e.message}',
                        style: TextStyle(
                          color: _colorForLevel(e.level),
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

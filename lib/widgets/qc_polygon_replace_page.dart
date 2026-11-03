import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import '../services/geojson_polygon_import.dart';
import '../utils/polygon_geometry.dart';

/// Ergebnis der Seite: das gewählte Polygon samt Angaben zur externen
/// Korrektur. Der Aufrufer schreibt es über `saveFieldGeometry`.
class PolygonReplacement {
  const PolygonReplacement({
    required this.polygon,
    required this.fileName,
    required this.reason,
    required this.tool,
    required this.method,
    required this.correctedBy,
    required this.correctedAt,
  });

  final ImportedPolygon polygon;
  final String fileName;
  final String reason;
  final String tool;
  final String method;
  final String correctedBy;

  /// `yyyy-MM-dd`, leer wenn unbekannt.
  final String correctedAt;

  /// Steht so im signierten Job (`externalCorrection`).
  Map<String, dynamic> toJobProperty() => {
        'tool': tool,
        'method': method,
        'correctedBy': correctedBy,
        'correctedAt': correctedAt,
        'sourceFile': fileName,
        'featureId': polygon.featureId,
        'featureName': polygon.label,
        'featureHash': polygon.hash,
      };
}

/// Ab hier wird gewarnt, nicht blockiert: der Prüfer sieht beide Polygone
/// und entscheidet.
const double _areaDeviationWarning = 0.5;
const double _distanceWarningMeters = 200;

/// Ersetzt die Grenze eines Feldes in der QC durch ein extern (z.B. in QGIS)
/// korrigiertes Polygon aus einer GeoJSON-Datei.
class QcPolygonReplacePage extends StatefulWidget {
  const QcPolygonReplacePage({
    super.key,
    required this.fieldName,
    required this.currentRing,
    this.geoId,
  });

  final String fieldName;

  /// Bisherige Grenze, offener oder geschlossener Ring.
  final List<LatLng> currentRing;
  final String? geoId;

  @override
  State<QcPolygonReplacePage> createState() => _QcPolygonReplacePageState();
}

class _QcPolygonReplacePageState extends State<QcPolygonReplacePage> {
  late final List<LatLng> _current = openRing(widget.currentRing);
  late final double _currentArea = polygonAreaInHectares(closeRing(_current));
  late final LatLng _currentCentroid = polygonCentroid(_current);

  String? _fileName;
  String? _fileError;
  List<ImportedPolygon> _candidates = [];
  List<RejectedFeature> _rejected = [];
  ImportedPolygon? _selected;

  final _reason = TextEditingController();
  final _tool = TextEditingController(text: 'QGIS');
  final _method = TextEditingController();
  final _correctedBy = TextEditingController();
  final _correctedAt = TextEditingController();

  GoogleMapController? _map;

  @override
  void dispose() {
    for (final c in [_reason, _tool, _method, _correctedBy, _correctedAt]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _selected != null &&
      _reason.text.trim().isNotEmpty &&
      _correctedBy.text.trim().isNotEmpty;

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;

    try {
      final parsed = parseGeoJsonPolygons(utf8.decode(file.bytes!));
      final ranked = rankForField(
        parsed.polygons,
        geoId: widget.geoId,
        name: widget.fieldName,
        currentCentroid: _currentCentroid,
      );
      setState(() {
        _fileName = file.name;
        _fileError = null;
        _candidates = ranked;
        _rejected = parsed.rejected;
      });
      _select(ranked.firstOrNull);
    } on FormatException {
      setState(() {
        _fileName = file.name;
        _fileError = l10n.qcReplacePolygonInvalidFile;
        _candidates = [];
        _rejected = [];
        _selected = null;
      });
    }
  }

  void _select(ImportedPolygon? polygon) {
    setState(() {
      _selected = polygon;
      if (polygon == null) return;
      // Angaben aus den Feature-Attributen vorbelegen, ohne bereits
      // Eingetipptes zu überschreiben.
      void prefill(TextEditingController c, List<String> keys) {
        final value = polygon.property(keys);
        if (value != null && (c.text.isEmpty || c == _tool)) c.text = value;
      }

      prefill(_tool, const ['tool', 'correction_tool', 'correctionTool']);
      prefill(_method,
          const ['method', 'correction_method', 'correctionMethod']);
      prefill(_correctedBy, const [
        'corrected_by',
        'correctedBy',
        'editor',
        'author',
        'operator'
      ]);
      prefill(_correctedAt, const [
        'corrected_at',
        'correctedAt',
        'correction_date',
        'date'
      ]);
      prefill(_reason, const [
        'reason',
        'correction_reason',
        'correctionReason',
        'comment'
      ]);
    });
    _fitMap();
  }

  void _fitMap() {
    final points = [..._current, ...?_selected?.ring];
    if (_map == null || points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      48,
    ));
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_correctedAt.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    setState(() => _correctedAt.text = DateFormat('yyyy-MM-dd').format(date));
  }

  void _save() {
    Navigator.pop(
      context,
      PolygonReplacement(
        polygon: _selected!,
        fileName: _fileName ?? '',
        reason: _reason.text.trim(),
        tool: _tool.text.trim(),
        method: _method.text.trim(),
        correctedBy: _correctedBy.text.trim(),
        correctedAt: _correctedAt.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qcReplacePolygonTitle(widget.fieldName)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.check),
              label: Text(l10n.qcReplacePolygonApply),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final map = _buildMap();
          final panel = _buildPanel(l10n);
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: map),
                    SizedBox(width: 420, child: panel),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(height: 320, child: map),
                    Expanded(child: panel),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _currentCentroid, zoom: 16),
          mapType: MapType.satellite,
          onMapCreated: (c) {
            _map = c;
            _fitMap();
          },
          polygons: {
            Polygon(
              polygonId: const PolygonId('current'),
              points: _current,
              strokeColor: Colors.red,
              strokeWidth: 2,
              fillColor: Colors.red.withValues(alpha: 0.08),
            ),
            if (_selected case final selected?)
              Polygon(
                polygonId: const PolygonId('replacement'),
                points: selected.ring,
                strokeColor: Colors.greenAccent,
                strokeWidth: 3,
                fillColor: Colors.greenAccent.withValues(alpha: 0.15),
              ),
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: PointerInterceptor(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legend(Colors.red,
                      AppLocalizations.of(context)!.qcReplacePolygonCurrent),
                  _legend(Colors.green,
                      AppLocalizations.of(context)!.qcReplacePolygonNew),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 3, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.black87, fontSize: 12)),
          ],
        ),
      );

  Widget _buildPanel(AppLocalizations l10n) {
    return Material(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.qcReplacePolygonInfo,
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_open),
            label: Text(_fileName ?? l10n.qcReplacePolygonChooseFile),
          ),
          if (_fileError != null) _warning(_fileError!, Colors.red),
          if (_rejected.isNotEmpty) _buildRejected(l10n),
          if (_fileName != null && _fileError == null && _candidates.isEmpty)
            _warning(l10n.qcReplacePolygonNoUsable, Colors.red),
          if (_candidates.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<ImportedPolygon>(
              // Neue Datei, neue Auswahl - initialValue gilt nur beim Aufbau.
              key: ValueKey(_fileName),
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.qcReplacePolygonFeature,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final p in _candidates)
                  DropdownMenuItem(
                    value: p,
                    child: Text(_candidateLabel(p),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black)),
                  ),
              ],
              onChanged: _select,
            ),
          ],
          if (_selected case final selected?) ...[
            const SizedBox(height: 12),
            _buildComparison(selected, l10n),
          ],
          const Divider(height: 32),
          _textField(_reason, l10n.qcCorrectionReason,
              hint: l10n.qcReplacePolygonReasonHint, maxLines: 2),
          _textField(_correctedBy, l10n.qcReplacePolygonCorrectedBy),
          _textField(_tool, l10n.qcReplacePolygonTool),
          _textField(_method, l10n.qcReplacePolygonMethod,
              hint: l10n.qcReplacePolygonMethodHint),
          _textField(
            _correctedAt,
            l10n.qcReplacePolygonCorrectedAt,
            hint: 'yyyy-MM-dd',
            suffix: IconButton(
              icon: const Icon(Icons.calendar_today, size: 18),
              onPressed: _pickDate,
            ),
          ),
        ],
      ),
    );
  }

  String _candidateLabel(ImportedPolygon p) {
    final distance = distanceInMeters(_currentCentroid, p.centroid);
    return [
      p.label,
      if (p.geoId != null) p.geoId!,
      '${p.areaHa.toStringAsFixed(2)} ha',
      '${distance.round()} m',
    ].join(' · ');
  }

  Widget _buildComparison(ImportedPolygon selected, AppLocalizations l10n) {
    final deviation =
        _currentArea > 0 ? (selected.areaHa - _currentArea) / _currentArea : 0.0;
    final distance = distanceInMeters(_currentCentroid, selected.centroid);
    final sign = deviation >= 0 ? '+' : '';

    TableRow row(String label, String value) => TableRow(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child:
                Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          defaultColumnWidth: const FlexColumnWidth(),
          children: [
            row('${l10n.qcReplacePolygonCurrent}  ',
                '${_currentArea.toStringAsFixed(2)} ha · ${l10n.qcReplacePolygonCorners(_current.length)}'),
            row('${l10n.qcReplacePolygonNew}  ',
                '${selected.areaHa.toStringAsFixed(2)} ha · ${l10n.qcReplacePolygonCorners(selected.ring.length)}'),
            row('${l10n.qcReplacePolygonDeviation}  ',
                '$sign${(deviation * 100).toStringAsFixed(1)} % · ${distance.round()} m'),
          ],
        ),
        if (selected.selfIntersects)
          _warning(l10n.qcEditPolygonSelfIntersect, Colors.red),
        if (deviation.abs() > _areaDeviationWarning)
          _warning(l10n.qcReplacePolygonLargeAreaChange, Colors.orange[900]!),
        if (distance > _distanceWarningMeters)
          _warning(l10n.qcReplacePolygonFarAway, Colors.orange[900]!),
      ],
    );
  }

  Widget _buildRejected(AppLocalizations l10n) {
    String reasonText(PolygonRejectReason r) => switch (r) {
          PolygonRejectReason.notPolygon => l10n.qcReplacePolygonRejectNotPolygon,
          PolygonRejectReason.multiPart => l10n.qcReplacePolygonRejectMultiPart,
          PolygonRejectReason.holes => l10n.qcReplacePolygonRejectHoles,
          PolygonRejectReason.notWgs84 => l10n.qcReplacePolygonRejectNotWgs84,
          PolygonRejectReason.tooFewCorners =>
            l10n.qcReplacePolygonRejectTooFewCorners,
        };

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(Icons.warning_amber, color: Colors.orange[900]),
      title: Text(
        l10n.qcReplacePolygonSkipped(_rejected.length),
        style: TextStyle(color: Colors.orange[900], fontSize: 13),
      ),
      children: [
        for (final r in _rejected)
          ListTile(
            dense: true,
            title: Text(r.label, style: const TextStyle(color: Colors.black)),
            subtitle: Text(reasonText(r.reason),
                style: const TextStyle(color: Colors.black54)),
          ),
      ],
    );
  }

  Widget _warning(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.black87),
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

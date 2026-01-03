import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';

/// CustomPainter für die Polygon-Visualisierung mit Transformation
class PolygonPainter extends CustomPainter {
  final List<List<double>> points;
  final List<double> accuracies;
  final double scale;
  final Offset offset;
  final int? selectedPointIndex;

  PolygonPainter({
    required this.points,
    required this.accuracies,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.selectedPointIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Finde min/max Koordinaten für Bounding Box
    double minLat = points[0][0];
    double maxLat = points[0][0];
    double minLon = points[0][1];
    double maxLon = points[0][1];

    for (var point in points) {
      if (point[0] < minLat) minLat = point[0];
      if (point[0] > maxLat) maxLat = point[0];
      if (point[1] < minLon) minLon = point[1];
      if (point[1] > maxLon) maxLon = point[1];
    }

    // Berechne Skalierung mit Padding
    final padding = 20.0;
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;

    // Verhindere Division durch Null bei einzelnem Punkt
    final effectiveLatRange = latRange > 0 ? latRange : 0.0001;
    final effectiveLonRange = lonRange > 0 ? lonRange : 0.0001;

    final scaleX = (size.width - 2 * padding) / effectiveLonRange;
    final scaleY = (size.height - 2 * padding) / effectiveLatRange;
    final baseScale = min(scaleX, scaleY);

    // Funktion zum Umrechnen von Geo-Koordinaten in Canvas-Koordinaten (mit Transformation)
    Offset toCanvas(List<double> point) {
      final x = padding + (point[1] - minLon) * baseScale;
      final y = size.height - (padding + (point[0] - minLat) * baseScale);
      // Wende Zoom und Pan an
      return Offset(
        (x - size.width / 2) * scale + size.width / 2 + offset.dx,
        (y - size.height / 2) * scale + size.height / 2 + offset.dy,
      );
    }

    // Zeichne Polygon-Fläche (halbtransparent)
    if (points.length >= 3) {
      final path = Path();
      final firstPoint = toCanvas(points[0]);
      path.moveTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < points.length; i++) {
        final point = toCanvas(points[i]);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      final fillPaint = Paint()
        ..color = Colors.green.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Zeichne Polygon-Linien
    final linePaint = Paint()
      ..color = Colors.blue[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length - 1; i++) {
      final start = toCanvas(points[i]);
      final end = toCanvas(points[i + 1]);
      canvas.drawLine(start, end, linePaint);
    }

    // Zeichne Schlusslinie (gestrichelt) wenn mehr als 2 Punkte
    if (points.length >= 3) {
      final start = toCanvas(points.last);
      final end = toCanvas(points.first);

      final dashedPaint = Paint()
        ..color = Colors.orange[700]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Zeichne gestrichelte Linie
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      double distance = (end - start).distance;
      double currentDistance = 0.0;

      while (currentDistance < distance) {
        final progress = currentDistance / distance;
        final nextProgress = min((currentDistance + dashWidth) / distance, 1.0);

        final dashStart = Offset(
          start.dx + (end.dx - start.dx) * progress,
          start.dy + (end.dy - start.dy) * progress,
        );
        final dashEnd = Offset(
          start.dx + (end.dx - start.dx) * nextProgress,
          start.dy + (end.dy - start.dy) * nextProgress,
        );

        canvas.drawLine(dashStart, dashEnd, dashedPaint);
        currentDistance += dashWidth + dashSpace;
      }
    }

    // Zeichne Punkte mit Genauigkeits-Farbcodierung
    for (int i = 0; i < points.length; i++) {
      final center = toCanvas(points[i]);
      final accuracy = i < accuracies.length ? accuracies[i] : null;

      // Farbcodierung nach Genauigkeit
      Color pointColor;
      if (accuracy == null) {
        pointColor = Colors.grey[700]!;
      } else if (accuracy <= 5) {
        pointColor = Colors.green[700]!;
      } else if (accuracy <= 10) {
        pointColor = Colors.orange[700]!;
      } else {
        pointColor = Colors.red[700]!;
      }

      // Äußerer Ring (weiß)
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8, outerPaint);

      // Innerer Punkt (farbcodiert)
      final innerPaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;
      final pointRadius = (i == selectedPointIndex) ? 8.0 : 6.0;
      canvas.drawCircle(center, pointRadius, innerPaint);

      // Highlight für ausgewählten Punkt
      if (i == selectedPointIndex) {
        final highlightPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, 12, highlightPaint);
      }

      // Punkt-Nummer
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: (i == selectedPointIndex) ? 10 : 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.accuracies.length != accuracies.length ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.selectedPointIndex != selectedPointIndex;
  }

  /// Hilfsmethode: Konvertiert Canvas-Koordinaten zurück zu Geo-Koordinaten
  List<double>? canvasToGeo(Offset canvasPoint, Size size) {
    if (points.isEmpty) return null;

    double minLat = points[0][0];
    double maxLat = points[0][0];
    double minLon = points[0][1];
    double maxLon = points[0][1];

    for (var point in points) {
      if (point[0] < minLat) minLat = point[0];
      if (point[0] > maxLat) maxLat = point[0];
      if (point[1] < minLon) minLon = point[1];
      if (point[1] > maxLon) maxLon = point[1];
    }

    final padding = 20.0;
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;
    final effectiveLatRange = latRange > 0 ? latRange : 0.0001;
    final effectiveLonRange = lonRange > 0 ? lonRange : 0.0001;

    final scaleX = (size.width - 2 * padding) / effectiveLonRange;
    final scaleY = (size.height - 2 * padding) / effectiveLatRange;
    final baseScale = min(scaleX, scaleY);

    // Rückwärts-Transformation
    final adjustedX =
        (canvasPoint.dx - size.width / 2 - offset.dx) / scale + size.width / 2;
    final adjustedY = (canvasPoint.dy - size.height / 2 - offset.dy) / scale +
        size.height / 2;

    final lon = (adjustedX - padding) / baseScale + minLon;
    final lat = ((size.height - adjustedY) - padding) / baseScale + minLat;

    return [lat, lon];
  }
}

/// Widget für die GPS-basierte Aufzeichnung von Feldgrenzen
/// Speichert Punkte während der Aufzeichnung in Hive für Crash-Resistenz
class PolygonRecorderWidget extends StatefulWidget {
  final Function(List<List<double>>, double) onPolygonComplete;
  final String?
      draftKey; // Optional: Zum Fortsetzen einer unterbrochenen Aufzeichnung
  final int minDistanceMeters; // Minimaler Abstand zwischen Punkten
  final String? farmId; // Farm-ID für Draft-Zuordnung
  final VoidCallback? onCancel; // Callback beim Verlassen ohne Abschluss

  const PolygonRecorderWidget({
    super.key,
    required this.onPolygonComplete,
    this.draftKey,
    this.minDistanceMeters = 10,
    this.farmId,
    this.onCancel,
  });

  /// Gibt alle Draft-Polygone für eine Farm zurück
  static Future<List<Map<String, dynamic>>> getDraftsForFarm(
      String? farmId) async {
    try {
      final box = await Hive.openBox<Map>('draftPolygons');
      final drafts = <Map<String, dynamic>>[];

      for (var key in box.keys) {
        final draft = box.get(key);
        if (draft != null && draft['farmId'] == farmId) {
          drafts.add({
            'key': key,
            'points': draft['points'],
            'accuracies': draft['accuracies'],
            'timestamp': draft['timestamp'],
            'pointCount': (draft['points'] as List?)?.length ?? 0,
          });
        }
      }

      // Sortiere nach Timestamp (neueste zuerst)
      drafts.sort((a, b) =>
          (b['timestamp'] as String).compareTo(a['timestamp'] as String));
      return drafts;
    } catch (e) {
      debugPrint('Error loading drafts: $e');
      return [];
    }
  }

  @override
  State<PolygonRecorderWidget> createState() => _PolygonRecorderWidgetState();
}

class _PolygonRecorderWidgetState extends State<PolygonRecorderWidget> {
  final List<List<double>> _points = [];
  final List<double> _accuracies = []; // Genauigkeit für jeden Punkt in Metern
  StreamSubscription<Position>? _positionStream;
  bool _isRecording = false;
  bool _isLoading = false;
  Position? _currentPosition;
  Position? _lastAddedPosition;
  Box<Map>? _draftBox;
  String _draftKey = '';

  // Zoom und Pan State
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  int? _selectedPointIndex;
  bool _isDraggingPoint = false;
  final GlobalKey _canvasKey = GlobalKey();
  List<int> _sortedToOriginalIndexMap =
      []; // Mapping von sortiertem Index zu Original-Index

  @override
  void initState() {
    super.initState();
    _initializeDraftStorage();
  }

  Future<void> _initializeDraftStorage() async {
    setState(() => _isLoading = true);
    try {
      // Öffne Draft-Box für Zwischenspeicherung
      _draftBox = await Hive.openBox<Map>('draftPolygons');

      // Generiere Draft-Key
      _draftKey =
          widget.draftKey ?? 'draft_${DateTime.now().millisecondsSinceEpoch}';

      // Lade existierenden Draft falls vorhanden
      final existingDraft = _draftBox?.get(_draftKey);
      if (existingDraft != null && existingDraft['points'] != null) {
        final points = existingDraft['points'] as List;
        final accuracies = existingDraft['accuracies'] as List?;
        setState(() {
          _points
              .addAll(points.map((p) => List<double>.from(p as List)).toList());
          if (accuracies != null) {
            _accuracies
                .addAll(accuracies.map((a) => (a as num).toDouble()).toList());
          }
        });
      }

      // Starte GPS automatisch beim Öffnen des Screens
      await _startRecording();
    } catch (e) {
      debugPrint('Error initializing draft storage: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_draftBox != null && _points.isNotEmpty) {
      await _draftBox!.put(_draftKey, {
        'points': _points,
        'accuracies': _accuracies,
        'farmId': widget.farmId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _deleteDraft() async {
    if (_draftBox != null) {
      await _draftBox!.delete(_draftKey);
    }
  }

  Future<void> _startRecording() async {
    // Prüfe GPS-Berechtigung
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.gpsDisabledMessage)),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gpsDisabledMessage)),
        );
      }
      return;
    }

    setState(() => _isRecording = true);

    // Starte GPS-Stream mit Distanzfilter
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update alle 5m
      ),
    ).listen((Position position) {
      setState(() => _currentPosition = position);
    });
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
    _positionStream?.cancel();
    _positionStream = null;
    setState(() => _currentPosition = null);
  }

  void _addCurrentPoint() async {
    final l10n = AppLocalizations.of(context)!;

    Position? positionToAdd = _currentPosition;

    // Debug-Modus: Simuliere Punkte mit mindestens 15m Abstand
    if (kDebugMode && _lastAddedPosition != null) {
      // Generiere einen zufälligen Punkt 15-20m vom letzten Punkt entfernt
      final random = Random();
      final distanceMeters = 15.0 + random.nextDouble() * 5.0; // 15-20m
      final bearing = random.nextDouble() * 360; // Zufällige Richtung

      // Berechne neue Koordinaten basierend auf Distanz und Richtung
      // 1 Grad Latitude ≈ 111.32 km
      // 1 Grad Longitude ≈ 111.32 km * cos(latitude)
      final latOffset = (distanceMeters / 111320.0) * cos(bearing * pi / 180);
      final lonOffset = (distanceMeters / 111320.0) *
          sin(bearing * pi / 180) /
          cos(_lastAddedPosition!.latitude * pi / 180);

      final newLat = _lastAddedPosition!.latitude + latOffset;
      final newLon = _lastAddedPosition!.longitude + lonOffset;

      positionToAdd = Position(
        latitude: newLat,
        longitude: newLon,
        timestamp: DateTime.now(),
        accuracy: 5.0 + random.nextDouble() * 3.0, // 5-8m Genauigkeit
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      debugPrint(
          '🔧 Debug: Simulierter Punkt ${distanceMeters.toStringAsFixed(1)}m entfernt in Richtung ${bearing.toStringAsFixed(0)}°');
    }

    // Prüfe ob GPS-Position verfügbar ist
    if (positionToAdd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.waitingForGps),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // Prüfe Mindestabstand zum letzten Punkt (außer im Debug-Modus, wo bereits simuliert)
    if (_lastAddedPosition != null && !kDebugMode) {
      final distance = Geolocator.distanceBetween(
        _lastAddedPosition!.latitude,
        _lastAddedPosition!.longitude,
        positionToAdd.latitude,
        positionToAdd.longitude,
      );

      if (distance < widget.minDistanceMeters) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l10n.minimumDistanceWarning(widget.minDistanceMeters)),
            duration: const Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    setState(() {
      _points.add([positionToAdd!.latitude, positionToAdd.longitude]);
      _accuracies.add(positionToAdd.accuracy);
      _lastAddedPosition = positionToAdd;
    });

    // Speichere Draft nach jedem Punkt
    await _saveDraft();
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
        if (_accuracies.isNotEmpty) {
          _accuracies.removeLast();
        }
        if (_points.isNotEmpty) {
          _lastAddedPosition = Position(
            latitude: _points.last[0],
            longitude: _points.last[1],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        } else {
          _lastAddedPosition = null;
        }
      });
      _saveDraft();
    }
  }

  void _removePointAt(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deletePoint,
          style: const TextStyle(color: Colors.black),
        ),
        content: Text(
          l10n.deletePointConfirmation(index + 1),
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && index < _points.length) {
      setState(() {
        _points.removeAt(index);
        if (index < _accuracies.length) {
          _accuracies.removeAt(index);
        }
        // Update last added position
        if (_points.isNotEmpty) {
          _lastAddedPosition = Position(
            latitude: _points.last[0],
            longitude: _points.last[1],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        } else {
          _lastAddedPosition = null;
        }
      });
      await _saveDraft();
    }
  }

  void _clearPolygon() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.clearPolygon,
          style: const TextStyle(color: Colors.black),
        ),
        content: Text(
          '${l10n.pointsRecorded(_points.length)} - ${l10n.clearPolygon}?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearPolygon),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _points.clear();
        _accuracies.clear();
        _lastAddedPosition = null;
      });
      await _deleteDraft();
    }
  }

  void _completePolygon() async {
    final l10n = AppLocalizations.of(context)!;

    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minimumPointsRequired)),
      );
      return;
    }

    // Auto-close Polygon wenn erste und letzte Punkte nahe beieinander
    final firstPoint = _points.first;
    final lastPoint = _points.last;
    final distance = Geolocator.distanceBetween(
      firstPoint[0],
      firstPoint[1],
      lastPoint[0],
      lastPoint[1],
    );

    // Sortiere Punkte zu einem sinnvollen Polygon
    List<List<double>> sortedPoints = _sortPointsToPolygon(List.from(_points));

    // Prüfe ob Polygon nach Sortierung geschlossen werden muss
    final sortedFirstPoint = sortedPoints.first;
    final sortedLastPoint = sortedPoints.last;
    final sortedDistance = Geolocator.distanceBetween(
      sortedFirstPoint[0],
      sortedFirstPoint[1],
      sortedLastPoint[0],
      sortedLastPoint[1],
    );

    List<List<double>> finalPoints = List.from(sortedPoints);
    if (sortedDistance < 10 && sortedDistance > 0) {
      // Schließe Polygon automatisch
      finalPoints.add(List.from(sortedFirstPoint));
    } else if (sortedDistance >= 10) {
      // Polygon nicht geschlossen - frage nach
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            l10n.polygonNotClosed,
            style: const TextStyle(color: Colors.black),
          ),
          content: Text(
            '${l10n.polygonNotClosed} (${sortedDistance.toStringAsFixed(1)}m). ${l10n.closeAutomatically}',
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.close),
            ),
          ],
        ),
      );

      if (shouldClose != true) return;
      finalPoints.add(List.from(sortedFirstPoint));
    }

    // Berechne Fläche
    final area = _calculateAreaInHectares(finalPoints);

    // Stoppe GPS-Aufzeichnung
    _stopRecording();

    // Lösche Draft
    await _deleteDraft();

    // Callback mit finalen Punkten und Fläche
    widget.onPolygonComplete(finalPoints, area);
  }

  /// Sortiert Punkte zu einem sinnvollen Polygon mittels Nearest-Neighbor-Algorithmus
  List<List<double>> _sortPointsToPolygon(List<List<double>> points) {
    if (points.length <= 3) return points;

    // Finde den südwestlichsten Punkt als Startpunkt
    int startIdx = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i][0] < points[startIdx][0] ||
          (points[i][0] == points[startIdx][0] &&
              points[i][1] < points[startIdx][1])) {
        startIdx = i;
      }
    }

    List<List<double>> sorted = [];
    List<List<double>> remaining = List.from(points);
    List<double> current = remaining.removeAt(startIdx);
    sorted.add(current);

    // Berechne Schwerpunkt
    double centerLat =
        points.map((p) => p[0]).reduce((a, b) => a + b) / points.length;
    double centerLon =
        points.map((p) => p[1]).reduce((a, b) => a + b) / points.length;

    // Sortiere Punkte nach Winkel vom Schwerpunkt aus
    remaining.sort((a, b) {
      double angleA = atan2(a[1] - centerLon, a[0] - centerLat);
      double angleB = atan2(b[1] - centerLon, b[0] - centerLat);
      return angleA.compareTo(angleB);
    });

    sorted.addAll(remaining);
    return sorted;
  }

  /// Berechnet die Fläche eines Polygons in Hektar mittels Shoelace-Formel
  double _calculateAreaInHectares(List<List<double>> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      area += points[i][0] * points[i + 1][1];
      area -= points[i + 1][0] * points[i][1];
    }
    area = area.abs() / 2.0;

    // Konvertiere Grad² zu Hektar
    // 1 Grad Latitude ≈ 111.32 km, 1 Grad Longitude ≈ 111.32 * cos(latitude)
    // Verwende Durchschnitt der Breitengrade für Genauigkeit
    final avgLat =
        points.map((p) => p[0]).reduce((a, b) => a + b) / points.length;
    final latToKm = 111.32;
    final lonToKm = 111.32 * cos(avgLat * pi / 180);

    // Fläche in km² dann in Hektar (1 km² = 100 ha)
    final areaKm2 = area * latToKm * lonToKm;
    return areaKm2 * 100;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // Hilfsmethode: Erstellt Index-Mapping und sortierte Punkte
  List<List<double>> _getSortedPointsWithMapping() {
    if (_points.isEmpty) return [];

    // Erstelle Liste mit Original-Indizes
    List<MapEntry<int, List<double>>> indexedPoints = [];
    for (int i = 0; i < _points.length; i++) {
      indexedPoints.add(MapEntry(i, _points[i]));
    }

    // Sortiere wie in _sortPointsToPolygon
    if (_points.length <= 3) {
      _sortedToOriginalIndexMap = indexedPoints.map((e) => e.key).toList();
      return indexedPoints.map((e) => e.value).toList();
    }

    // Finde südwestlichsten Punkt
    int startIdx = 0;
    for (int i = 1; i < indexedPoints.length; i++) {
      if (indexedPoints[i].value[0] < indexedPoints[startIdx].value[0] ||
          (indexedPoints[i].value[0] == indexedPoints[startIdx].value[0] &&
              indexedPoints[i].value[1] < indexedPoints[startIdx].value[1])) {
        startIdx = i;
      }
    }

    // Berechne Schwerpunkt
    double centerLat =
        _points.map((p) => p[0]).reduce((a, b) => a + b) / _points.length;
    double centerLon =
        _points.map((p) => p[1]).reduce((a, b) => a + b) / _points.length;

    List<MapEntry<int, List<double>>> sorted = [];
    List<MapEntry<int, List<double>>> remaining = List.from(indexedPoints);
    MapEntry<int, List<double>> current = remaining.removeAt(startIdx);
    sorted.add(current);

    // Sortiere nach Winkel
    remaining.sort((a, b) {
      double angleA = atan2(a.value[1] - centerLon, a.value[0] - centerLat);
      double angleB = atan2(b.value[1] - centerLon, b.value[0] - centerLat);
      return angleA.compareTo(angleB);
    });

    sorted.addAll(remaining);

    // Erstelle Mapping
    _sortedToOriginalIndexMap = sorted.map((e) => e.key).toList();
    return sorted.map((e) => e.value).toList();
  }

  void _checkPointSelection(Offset tapPosition) {
    if (_points.isEmpty) return;

    // Hole tatsächliche Canvas-Größe
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    // Hole sortierte Punkte mit Mapping
    final sortedPoints = _getSortedPointsWithMapping();

    // Berechne Canvas-Koordinaten für alle Punkte
    double minLat = sortedPoints[0][0];
    double maxLat = sortedPoints[0][0];
    double minLon = sortedPoints[0][1];
    double maxLon = sortedPoints[0][1];

    for (var point in sortedPoints) {
      if (point[0] < minLat) minLat = point[0];
      if (point[0] > maxLat) maxLat = point[0];
      if (point[1] < minLon) minLon = point[1];
      if (point[1] > maxLon) maxLon = point[1];
    }

    const padding = 20.0;
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;
    final effectiveLatRange = latRange > 0 ? latRange : 0.0001;
    final effectiveLonRange = lonRange > 0 ? lonRange : 0.0001;

    final scaleX = (size.width - 2 * padding) / effectiveLonRange;
    final scaleY = (size.height - 2 * padding) / effectiveLatRange;
    final baseScale = min(scaleX, scaleY);

    // Funktion zum Berechnen der Canvas-Position
    Offset toCanvas(List<double> point) {
      final x = padding + (point[1] - minLon) * baseScale;
      final y = size.height - (padding + (point[0] - minLat) * baseScale);
      return Offset(
        (x - size.width / 2) * _scale + size.width / 2 + _offset.dx,
        (y - size.height / 2) * _scale + size.height / 2 + _offset.dy,
      );
    }

    // Finde nächsten Punkt in den SORTIERTEN Punkten
    double minDistance = double.infinity;
    int? closestSortedIndex;

    for (int i = 0; i < sortedPoints.length; i++) {
      final pointPos = toCanvas(sortedPoints[i]);
      final distance = (tapPosition - pointPos).distance;

      if (distance < minDistance && distance < 50 / _scale) {
        minDistance = distance;
        closestSortedIndex = i;
      }
    }

    // Verwende das Mapping um Original-Index zu finden
    int? closestOriginalIndex;
    if (closestSortedIndex != null &&
        closestSortedIndex < _sortedToOriginalIndexMap.length) {
      closestOriginalIndex = _sortedToOriginalIndexMap[closestSortedIndex];
    }

    setState(() {
      _selectedPointIndex = closestOriginalIndex;
      _isDraggingPoint = closestOriginalIndex != null;
    });
  }

  void _dragPoint(Offset newPosition) {
    if (_selectedPointIndex == null) return;

    // Konvertiere Canvas-Koordinaten zu Geo-Koordinaten
    // Dies ist vereinfacht - für produktiven Code sollte die
    // Transformation aus PolygonPainter verwendet werden
    setState(() {
      // Platzhalter - würde echte Koordinaten-Konvertierung benötigen
      // _points[_selectedPointIndex!] = convertedCoordinates;
    });
  }

  Future<void> _showPointEditDialog(int originalIndex) async {
    final l10n = AppLocalizations.of(context)!;

    // Finde die visuelle Nummer (sortierte Position) für diesen Punkt
    int visualNumber = originalIndex + 1; // Default
    if (_sortedToOriginalIndexMap.isNotEmpty) {
      for (int i = 0; i < _sortedToOriginalIndexMap.length; i++) {
        if (_sortedToOriginalIndexMap[i] == originalIndex) {
          visualNumber = i + 1;
          break;
        }
      }
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${l10n.point} $visualNumber',
          style: const TextStyle(color: Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lat: ${_points[originalIndex][0].toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.black87),
            ),
            Text(
              'Lon: ${_points[originalIndex][1].toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.black87),
            ),
            if (originalIndex < _accuracies.length)
              Text(
                '${l10n.accuracy}: ${_accuracies[originalIndex].toStringAsFixed(1)}m',
                style: const TextStyle(color: Colors.black87),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == 'delete') {
      _removePointAt(originalIndex);
    }
  }

  Future<bool> _onWillPop() async {
    if (_points.isEmpty) {
      return true; // Keine Daten, kann verlassen werden
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.cancelRegistration,
          style: const TextStyle(color: Colors.black),
        ),
        content: Text(
          l10n.cancelRegistrationMessage,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: Text(l10n.continueRegistration),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l10n.saveAndExit),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(
              l10n.discardData,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      // Lösche Draft bei explizitem Verwerfen
      await _deleteDraft();
      _stopRecording();
      widget.onCancel?.call();
      return true;
    } else if (result == 'save') {
      // Speichere Draft und verlasse
      await _saveDraft();
      _stopRecording();
      widget.onCancel?.call();
      return true;
    }

    // Bei 'continue' oder null (Dialog geschlossen) bleiben wir
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final estimatedArea = _points.length >= 3
        ? _calculateAreaInHectares([..._points, _points.first])
        : 0.0;

    return PopScope(
      canPop: _points.isEmpty,
      onPopInvoked: (bool didPop) async {
        if (!didPop && _points.isNotEmpty) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          // Hauptinhalt (scrollbar)
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 100.0, // Platz für GPS-Widget
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: _isRecording ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.recordFieldBoundary,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Polygon-Visualisierung mit interaktiven Gesten - EXPANDED für verfügbaren Platz
                  if (_points.isNotEmpty)
                    Expanded(
                      child: Container(
                        key: _canvasKey,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onScaleStart: (details) {
                              _lastFocalPoint = details.focalPoint;
                              // Prüfe ob ein Punkt berührt wurde (aber nur bei Single Touch)
                              if (details.pointerCount == 1) {
                                _checkPointSelection(details.localFocalPoint);
                              }
                            },
                            onScaleUpdate: (details) {
                              if (_isDraggingPoint &&
                                  _selectedPointIndex != null &&
                                  details.pointerCount == 1) {
                                // Punkt verschieben
                                _dragPoint(details.localFocalPoint);
                              } else if (details.pointerCount > 1) {
                                // Zoom und Pan (nur bei Multi-Touch)
                                setState(() {
                                  _scale =
                                      (_scale * details.scale).clamp(0.5, 5.0);
                                  _offset +=
                                      details.focalPoint - _lastFocalPoint;
                                  _lastFocalPoint = details.focalPoint;
                                });
                              } else {
                                // Nur Pan bei Single Touch ohne Punkt-Drag
                                setState(() {
                                  _offset +=
                                      details.focalPoint - _lastFocalPoint;
                                  _lastFocalPoint = details.focalPoint;
                                });
                              }
                            },
                            onScaleEnd: (details) {
                              if (_isDraggingPoint) {
                                _saveDraft();
                              }
                              setState(() {
                                _isDraggingPoint = false;
                                // Behalte die Selektion nach dem Drag
                              });
                            },
                            onLongPressStart: (details) {
                              // Wichtig: Selektion vor Dialog
                              _checkPointSelection(details.localPosition);
                              // Warte kurz damit setState wirksam wird
                              Future.microtask(() {
                                if (_selectedPointIndex != null && mounted) {
                                  _showPointEditDialog(_selectedPointIndex!);
                                }
                              });
                            },
                            child: Stack(
                              children: [
                                CustomPaint(
                                  painter: PolygonPainter(
                                    points: _sortPointsToPolygon(
                                        List.from(_points)),
                                    accuracies: _accuracies,
                                    scale: _scale,
                                    offset: _offset,
                                    selectedPointIndex: _selectedPointIndex,
                                  ),
                                  child: Container(),
                                ),
                                // Zoom-Controls
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Column(
                                    children: [
                                      FloatingActionButton.small(
                                        heroTag: 'zoom_in',
                                        onPressed: () {
                                          setState(() {
                                            _scale =
                                                (_scale * 1.2).clamp(0.5, 5.0);
                                          });
                                        },
                                        child: const Icon(Icons.add),
                                      ),
                                      const SizedBox(height: 4),
                                      FloatingActionButton.small(
                                        heroTag: 'zoom_out',
                                        onPressed: () {
                                          setState(() {
                                            _scale =
                                                (_scale / 1.2).clamp(0.5, 5.0);
                                          });
                                        },
                                        child: const Icon(Icons.remove),
                                      ),
                                      const SizedBox(height: 4),
                                      FloatingActionButton.small(
                                        heroTag: 'zoom_reset',
                                        onPressed: () {
                                          setState(() {
                                            _scale = 1.0;
                                            _offset = Offset.zero;
                                            _selectedPointIndex = null;
                                          });
                                        },
                                        child: const Icon(
                                            Icons.center_focus_strong),
                                      ),
                                    ],
                                  ),
                                ),
                                // Info-Text
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l10n.pinchToZoom,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Status-Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.pointsRecorded(_points.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (_points.length >= 3)
                              Text(
                                l10n.estimatedArea(
                                    estimatedArea.toStringAsFixed(2)),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                          ],
                        ),
                        if (_isRecording && _currentPosition != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.current}: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                          Text(
                            '${l10n.accuracy}: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                        if (_points.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              l10n.tapToAddPoint,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Punkt-Hinzufügen Button (groß und prominent)
                  ElevatedButton.icon(
                    onPressed: _addCurrentPoint,
                    icon: const Icon(Icons.add_location, size: 28),
                    label: Text(
                      l10n.addPoint,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Liste der Punkte (scrollbar wenn viele)
                  if (_points.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      l10n.recordedPoints,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _points.length,
                        itemBuilder: (context, index) {
                          final accuracy = index < _accuracies.length
                              ? _accuracies[index]
                              : null;
                          final accuracyColor = accuracy != null
                              ? (accuracy <= 5
                                  ? Colors.green[700]!
                                  : accuracy <= 10
                                      ? Colors.orange[700]!
                                      : Colors.red[700]!)
                              : Colors.grey[700]!;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: accuracyColor,
                                  width: 4,
                                ),
                              ),
                              color: accuracyColor.withOpacity(0.05),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: accuracyColor,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                              ),
                              title: Text(
                                'Lat: ${_points[index][0].toStringAsFixed(6)}, Lon: ${_points[index][1].toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: accuracy != null
                                  ? Text(
                                      '${l10n.accuracy}: ${accuracy.toStringAsFixed(1)}m',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: accuracyColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red[400],
                                onPressed: () => _removePointAt(index),
                                tooltip: l10n.delete,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Complete Button or Minimum Points Message
                  if (_points.length >= 3)
                    ElevatedButton.icon(
                      onPressed: _completePolygon,
                      icon: const Icon(Icons.check_circle),
                      label: Text(l10n.completeRegistration),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        l10n.minimumPointsRequired,
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Fixiertes GPS-Signal-Widget am unteren Bildschirmrand
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _currentPosition == null
                    ? Colors.grey[300]
                    : (_currentPosition!.accuracy <= 5
                        ? Colors.green[100]
                        : _currentPosition!.accuracy <= 10
                            ? Colors.orange[100]
                            : Colors.red[100]),
                border: Border(
                  top: BorderSide(
                    color: _currentPosition == null
                        ? Colors.grey[500]!
                        : (_currentPosition!.accuracy <= 5
                            ? Colors.green[700]!
                            : _currentPosition!.accuracy <= 10
                                ? Colors.orange[700]!
                                : Colors.red[700]!),
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _currentPosition == null
                        ? Icons.gps_off
                        : (_currentPosition!.accuracy <= 5
                            ? Icons.gps_fixed
                            : _currentPosition!.accuracy <= 10
                                ? Icons.gps_not_fixed
                                : Icons.gps_off),
                    color: _currentPosition == null
                        ? Colors.grey[700]
                        : (_currentPosition!.accuracy <= 5
                            ? Colors.green[700]
                            : _currentPosition!.accuracy <= 10
                                ? Colors.orange[700]
                                : Colors.red[700]),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPosition == null
                              ? l10n.gpsDisabledMessage
                              : (_currentPosition!.accuracy <= 5
                                  ? l10n.gpsSignalExcellent
                                  : _currentPosition!.accuracy <= 10
                                      ? l10n.gpsSignalGood
                                      : l10n.gpsSignalPoor),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _currentPosition == null
                                ? Colors.grey[700]
                                : (_currentPosition!.accuracy <= 5
                                    ? Colors.green[900]
                                    : _currentPosition!.accuracy <= 10
                                        ? Colors.orange[900]
                                        : Colors.red[900]),
                          ),
                        ),
                        if (_currentPosition != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.accuracy}: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_currentPosition != null &&
                      _currentPosition!.accuracy <= 5)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

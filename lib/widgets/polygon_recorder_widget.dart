import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/main.dart' show country;
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
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
  final Function(List<List<double>>, double, List<double>) onPolygonComplete;
  final String?
      draftKey; // Optional: Zum Fortsetzen einer unterbrochenen Aufzeichnung
  final int minDistanceMeters; // Minimaler Abstand zwischen Punkten
  final String? farmId; // Farm-ID für Draft-Zuordnung
  final VoidCallback? onCancel; // Callback beim Verlassen ohne Abschluss

  const PolygonRecorderWidget({
    super.key,
    required this.onPolygonComplete,
    this.draftKey,
    this.minDistanceMeters = 5,
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
  GoogleMapController? _recordingMapController;
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
      // Karte folgt GPS-Position wenn noch keine Punkte aufgenommen wurden
      if (_points.isEmpty && _recordingMapController != null) {
        try {
          _recordingMapController!.animateCamera(
            CameraUpdate.newLatLng(
                LatLng(position.latitude, position.longitude)),
          );
        } catch (_) {
          // Controller bereits disposed (z.B. nach Redo), ignorieren
          _recordingMapController = null;
        }
      }
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

    // If stream hasn't provided position yet, try to get current position immediately
    if (positionToAdd == null && !kDebugMode) {
      try {
        positionToAdd = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 5),
          ),
        );
        debugPrint(
            'Fetched current position directly: ${positionToAdd.latitude}, ${positionToAdd.longitude}');
        // Update _currentPosition for UI
        setState(() => _currentPosition = positionToAdd);
      } catch (e) {
        debugPrint('Error getting current position: $e');
      }
    }

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

    // Kamera auf neue Bounds updaten
    _updateRecordingMapCamera();

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

  // --- Polygon-Vorschau Hilfsmethoden ---

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 5.0) return Colors.green;
    if (accuracy <= 10.0) return Colors.lightGreen;
    if (accuracy <= 15.0) return Colors.orange;
    return Colors.red;
  }

  Set<Circle> _buildAccuracyCircles(
      List<LatLng> points, List<double> accuracies) {
    final Set<Circle> circles = {};
    final pointCount = (points.isNotEmpty &&
            points.first.latitude == points.last.latitude &&
            points.first.longitude == points.last.longitude)
        ? points.length - 1
        : points.length;
    for (int i = 0; i < pointCount; i++) {
      final accuracy = (i < accuracies.length) ? accuracies[i] : 0.0;
      circles.add(Circle(
        circleId: CircleId('acc_$i'),
        center: points[i],
        radius: 3,
        fillColor: _getAccuracyColor(accuracy).withOpacity(0.8),
        strokeColor: _getAccuracyColor(accuracy),
        strokeWidth: 2,
      ));
    }
    return circles;
  }

  LatLngBounds _calculateLatLngBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<bool> _showPolygonPreviewDialog(
    List<List<double>> finalPoints,
    double area,
    List<double> accuracies,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppState>(context, listen: false);
    final availableUnits = getAreaUnits(country);

    // Konvertiere [lat, lon] → LatLng
    final latLngPoints = finalPoints.map((p) => LatLng(p[0], p[1])).toList();

    final bounds = _calculateLatLngBounds(latLngPoints);
    final centroid = LatLng(
      latLngPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
          latLngPoints.length,
      latLngPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
          latLngPoints.length,
    );

    GoogleMapController? mapController;

    final screenHeight = MediaQuery.of(context).size.height;
    final isOnline = Provider.of<AppState>(context, listen: false).isConnected;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: screenHeight * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Titelzeile
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Icon(isOnline ? Icons.map : Icons.map_outlined,
                          color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogL10n.polygonPreviewTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (!isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off,
                                  size: 14, color: Colors.orange[800]),
                              const SizedBox(width: 4),
                              Text('Offline',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Beschreibung
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    dialogL10n.polygonPreviewDescription,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
                // Flächenanzeige
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: availableUnits.map((unit) {
                      final symbol = unit['symbol'] as String;
                      final factor =
                          (unit['toHectareFactor'] as num).toDouble();
                      final converted = area / factor;
                      final isPreferred =
                          symbol == appState.preferredAreaUnitSymbol;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPreferred)
                            const Icon(Icons.star,
                                size: 14, color: Colors.orange)
                          else
                            const SizedBox(width: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${converted.toStringAsFixed(4)} $symbol',
                            style: TextStyle(
                              fontSize: isPreferred ? 16 : 13,
                              fontWeight: isPreferred
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color:
                                  isPreferred ? Colors.black : Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                // Karten- oder Canvas-Vorschau
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(0)),
                    child: isOnline
                        ? GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: centroid,
                              zoom: 16,
                            ),
                            onMapCreated: (controller) {
                              mapController = controller;
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () => mapController?.animateCamera(
                                  CameraUpdate.newLatLngBounds(bounds, 40),
                                ),
                              );
                            },
                            polygons: {
                              Polygon(
                                polygonId: const PolygonId('preview'),
                                points: latLngPoints,
                                strokeColor: Colors.blue,
                                strokeWidth: 2,
                                fillColor: Colors.blue.withOpacity(0.2),
                              ),
                            },
                            circles:
                                _buildAccuracyCircles(latLngPoints, accuracies),
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            myLocationButtonEnabled: false,
                            mapType: MapType.hybrid,
                            liteModeEnabled: false,
                          )
                        : InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(64),
                            minScale: 0.5,
                            maxScale: 8.0,
                            child: Container(
                              color: Colors.grey[100],
                              child: CustomPaint(
                                painter: PolygonPainter(
                                  points: finalPoints,
                                  accuracies: accuracies,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                  ),
                ),
                const Divider(height: 1),
                // Buttons
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.replay, color: Colors.red),
                          label: Text(
                            dialogL10n.polygonPreviewRedo,
                            style: const TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.check_circle),
                          label: Text(dialogL10n.polygonPreviewConfirm),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    mapController?.dispose();
    return result ?? false;
  }

  void _completePolygon() async {
    final l10n = AppLocalizations.of(context)!;

    if (_points.length < 4) {
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

    // Vorschau-Dialog: Polygon auf Karte verifizieren (inkl. Flächenanzeige)
    if (!context.mounted) return;
    final confirmed =
        await _showPolygonPreviewDialog(finalPoints, area, _accuracies);

    if (confirmed) {
      // Nutzer bestätigt → normaler Speicher-Flow
      widget.onPolygonComplete(finalPoints, area, _accuracies);
    } else {
      // Nutzer verwirft → alle Punkte löschen und GPS neu starten
      if (!context.mounted) return;
      setState(() {
        _points.clear();
        _accuracies.clear();
        _lastAddedPosition = null;
        _currentPosition = null;
        _recordingMapController =
            null; // Controller-Referenz leeren (Widget wurde disposed)
      });
      await _startRecording();
    }
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
    _recordingMapController?.dispose();
    super.dispose();
  }

  void _updateRecordingMapCamera() {
    if (_recordingMapController == null || _points.isEmpty) return;
    if (_points.length == 1) {
      _recordingMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_points[0][0], _points[0][1]), 17),
      );
      return;
    }
    final bounds = _calculateLatLngBounds(
      _points.map((p) => LatLng(p[0], p[1])).toList(),
    );
    _recordingMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
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

    final estimatedArea = _points.length >= 4
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
                      child: Consumer<AppState>(
                        builder: (ctx, appState, _) {
                          final isOnline = appState.isConnected;
                          return Container(
                            key: _canvasKey,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.transparent
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  // Kartenhintergrund (nur bei bestehender Verbindung)
                                  if (isOnline)
                                    IgnorePointer(
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: _currentPosition != null
                                              ? LatLng(
                                                  _currentPosition!.latitude,
                                                  _currentPosition!.longitude)
                                              : LatLng(_points.first[0],
                                                  _points.first[1]),
                                          zoom: 17,
                                        ),
                                        onMapCreated: (controller) {
                                          _recordingMapController = controller;
                                          _updateRecordingMapCamera();
                                        },
                                        myLocationEnabled: true,
                                        myLocationButtonEnabled: false,
                                        zoomControlsEnabled: false,
                                        scrollGesturesEnabled: false,
                                        zoomGesturesEnabled: false,
                                        rotateGesturesEnabled: false,
                                        tiltGesturesEnabled: false,
                                        mapToolbarEnabled: false,
                                        mapType: MapType.hybrid,
                                        liteModeEnabled: false,
                                      ),
                                    ),
                                  // Polygon-Canvas + Gesten (immer präsent)
                                  GestureDetector(
                                    onScaleStart: (details) {
                                      _lastFocalPoint = details.focalPoint;
                                      // Prüfe ob ein Punkt berührt wurde (aber nur bei Single Touch)
                                      if (details.pointerCount == 1) {
                                        _checkPointSelection(
                                            details.localFocalPoint);
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
                                          _scale = (_scale * details.scale)
                                              .clamp(0.5, 5.0);
                                          _offset += details.focalPoint -
                                              _lastFocalPoint;
                                          _lastFocalPoint = details.focalPoint;
                                        });
                                      } else {
                                        // Nur Pan bei Single Touch ohne Punkt-Drag
                                        setState(() {
                                          _offset += details.focalPoint -
                                              _lastFocalPoint;
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
                                      _checkPointSelection(
                                          details.localPosition);
                                      // Warte kurz damit setState wirksam wird
                                      Future.microtask(() {
                                        if (_selectedPointIndex != null &&
                                            mounted) {
                                          _showPointEditDialog(
                                              _selectedPointIndex!);
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
                                            selectedPointIndex:
                                                _selectedPointIndex,
                                          ),
                                          child: Container(
                                            color: isOnline
                                                ? Colors.transparent
                                                : null,
                                          ),
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
                                                    _scale = (_scale * 1.2)
                                                        .clamp(0.5, 5.0);
                                                  });
                                                },
                                                child: const Icon(Icons.add),
                                              ),
                                              const SizedBox(height: 4),
                                              FloatingActionButton.small(
                                                heroTag: 'zoom_out',
                                                onPressed: () {
                                                  setState(() {
                                                    _scale = (_scale / 1.2)
                                                        .clamp(0.5, 5.0);
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

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

                  // Kompakte Info über Punkte und Fläche
                  if (_points.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Consumer<AppState>(
                        builder: (ctx, appState, _) {
                          final units = getAreaUnits(country);
                          final currentUnit = units.firstWhere(
                            (u) =>
                                u['symbol'] == appState.preferredAreaUnitSymbol,
                            orElse: () => units.first,
                          );
                          final symbol = currentUnit['symbol'] as String;
                          final factor = (currentUnit['toHectareFactor'] as num)
                              .toDouble();
                          final displayArea = estimatedArea / factor;
                          return GestureDetector(
                            onTap: () {
                              // Nächste verfügbare Einheit wählen
                              final idx = units
                                  .indexWhere((u) => u['symbol'] == symbol);
                              final nextUnit = units[(idx + 1) % units.length];
                              appState.setPreferredAreaUnit(
                                  nextUnit['symbol'] as String);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_points.length} ${l10n.points} • ${displayArea.toStringAsFixed(2)} $symbol',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.swap_horiz,
                                    size: 16, color: Colors.grey[500]),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),
                  // Complete Button or Minimum Points Message
                  if (_points.length >= 4)
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

          // Minimiertes GPS-Signal-Widget (semi-transparent overlay)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_currentPosition == null
                        ? Colors.grey[800]
                        : (_currentPosition!.accuracy <= 5
                            ? Colors.green[700]
                            : _currentPosition!.accuracy <= 10
                                ? Colors.orange[700]
                                : Colors.red[700]))!
                    .withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentPosition == null
                        ? Icons.gps_off
                        : (_currentPosition!.accuracy <= 5
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed),
                    color: Colors.white,
                    size: 16,
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    const Text(
                      'GPS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

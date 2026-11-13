import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../utils/gps_quality.dart';

/// Ein Polygon in der [QcShapePreview].
class QcPreviewShape {
  const QcPreviewShape({required this.points, this.accuracies});

  final List<LatLng> points;

  /// GPS-Genauigkeit je Ecke; färbt die Eckpunkte und - über den schlechtesten
  /// Wert - die Fläche, wie in der Übersichtskarte.
  final List<double>? accuracies;
}

/// Ein Punktobjekt (Farm, Farmer) in der [QcShapePreview].
class QcPreviewPoint {
  const QcPreviewPoint({required this.position, required this.color});

  final LatLng position;
  final Color color;
}

/// Vorschau von Feldgrenzen und Standorten ohne Kartenhintergrund.
///
/// Gezeichnet wird lokal mit [CustomPaint] - anders als ein GoogleMap-Widget
/// erzeugt das keinen abrechenbaren Kartenaufruf. Im Web zählt jede erzeugte
/// Karte als "Dynamic Map"; die QC-Liste lädt die echte Karte deshalb erst,
/// wenn der Prüfer sie ausdrücklich öffnet.
class QcShapePreview extends StatelessWidget {
  const QcShapePreview({
    super.key,
    this.shapes = const [],
    this.points = const [],
  });

  final List<QcPreviewShape> shapes;
  final List<QcPreviewPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShapePainter(shapes: shapes, points: points),
      child: const SizedBox.expand(),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.shapes, required this.points});

  final List<QcPreviewShape> shapes;
  final List<QcPreviewPoint> points;

  static const double _padding = 20;
  static const double _metersPerDegreeLat = 111320;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEEF1EA),
    );

    final all = [
      for (final s in shapes) ...s.points,
      for (final p in points) p.position,
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude, maxLat = minLat;
    double minLng = all.first.longitude, maxLng = minLng;
    for (final p in all) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // Plattkarte mit Breitenkorrektur: auf Feldgröße ist der Fehler
    // vernachlässigbar, und die Form bleibt unverzerrt.
    final midLat = (minLat + maxLat) / 2;
    final lngFactor = math.cos(midLat * math.pi / 180);
    final spanX = (maxLng - minLng) * lngFactor;
    final spanY = maxLat - minLat;

    final usableW = math.max(1.0, size.width - 2 * _padding);
    final usableH = math.max(1.0, size.height - 2 * _padding);
    final span = math.max(spanX, spanY);
    // Nur ein Punkt (oder alles auf einer Stelle): zentrieren, Massstab
    // entspricht dann etwa 200 m über die Vorschau.
    final scale = span > 0
        ? math.min(usableW / math.max(spanX, 1e-12),
            usableH / math.max(spanY, 1e-12))
        : usableW / (200 / _metersPerDegreeLat);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    Offset project(LatLng p) => Offset(
          offsetX + (p.longitude - minLng) * lngFactor * scale,
          offsetY + (maxLat - p.latitude) * scale,
        );

    for (final shape in shapes) {
      if (shape.points.length < 2) continue;
      final worst = worstAccuracy(shape.accuracies);
      final color = worst == null ? Colors.blue : gpsAccuracyColor(worst);

      final path = Path()..addPolygon(shape.points.map(project).toList(), true);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );

      final acc = shape.accuracies;
      for (var i = 0; i < shape.points.length; i++) {
        final vertexColor = (acc != null && i < acc.length)
            ? gpsAccuracyColor(acc[i])
            : color;
        final c = project(shape.points[i]);
        canvas.drawCircle(c, 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(c, 2.5, Paint()..color = vertexColor);
      }
    }

    for (final point in points) {
      final c = project(point.position);
      canvas.drawCircle(c, 7, Paint()..color = Colors.white);
      canvas.drawCircle(c, 5, Paint()..color = point.color);
    }

    _paintScaleBar(canvas, size, scale);
  }

  /// Massstabsleiste oben rechts (unten liegt der Hinweis der Vorschau) -
  /// ohne Kartenhintergrund die einzige Orientierung, wie gross die Fläche ist.
  void _paintScaleBar(Canvas canvas, Size size, double pxPerDegree) {
    final pxPerMeter = pxPerDegree / _metersPerDegreeLat;
    if (pxPerMeter <= 0 || !pxPerMeter.isFinite) return;

    final targetMeters = (size.width / 4) / pxPerMeter;
    const steps = [
      5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000
    ];
    final meters = steps.lastWhere((s) => s <= targetMeters,
        orElse: () => steps.first);
    final barPx = meters * pxPerMeter;
    if (barPx > size.width - 16) return;

    final right = size.width - 8;
    const y = 24.0;
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(right - barPx, y), Offset(right, y), paint);
    canvas.drawLine(Offset(right - barPx, y - 4), Offset(right - barPx, y), paint);
    canvas.drawLine(Offset(right, y - 4), Offset(right, y), paint);

    final label = meters >= 1000 ? '${meters ~/ 1000} km' : '$meters m';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black87, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(right - tp.width, y - 6 - tp.height));
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shapes != shapes || old.points != points;
}

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geometrie-Helfer für Feld-Polygone.
///
/// Gespeichert werden Polygone als *geschlossener* Ring (letzter Punkt wiederholt
/// den ersten), so wie die Aufnahme sie ablegt. Bearbeitet wird dagegen der
/// *offene* Ring - sonst müsste jede Ecken-Operation den Schlusspunkt
/// mitpflegen. Diese beiden Helfer wandeln zwischen den Formen.
List<LatLng> openRing(List<LatLng> points) {
  if (points.length < 2) return List<LatLng>.from(points);
  final first = points.first;
  final last = points.last;
  if (first.latitude == last.latitude && first.longitude == last.longitude) {
    return points.sublist(0, points.length - 1);
  }
  return List<LatLng>.from(points);
}

List<LatLng> closeRing(List<LatLng> points) {
  if (points.isEmpty) return const [];
  final first = points.first;
  final last = points.last;
  if (first.latitude == last.latitude && first.longitude == last.longitude) {
    return List<LatLng>.from(points);
  }
  return [...points, first];
}

/// Fläche in Hektar über die Gauß'sche Trapezformel.
///
/// Bewusst dieselbe Rechnung wie bei der Aufnahme im Polygon-Recorder: die
/// Fläche eines nachträglich korrigierten Feldes muss mit den bei der Erfassung
/// berechneten Flächen vergleichbar bleiben. Erwartet einen geschlossenen Ring.
double polygonAreaInHectares(List<LatLng> closedRing) {
  if (closedRing.length < 3) return 0.0;

  double area = 0.0;
  for (int i = 0; i < closedRing.length - 1; i++) {
    area += closedRing[i].latitude * closedRing[i + 1].longitude;
    area -= closedRing[i + 1].latitude * closedRing[i].longitude;
  }
  area = area.abs() / 2.0;

  // Grad² in Hektar: 1 Grad Breite ~ 111.32 km, 1 Grad Länge ~ 111.32 km * cos(lat).
  final avgLat = closedRing.map((p) => p.latitude).reduce((a, b) => a + b) /
      closedRing.length;
  const latToKm = 111.32;
  final lonToKm = 111.32 * math.cos(avgLat * math.pi / 180);

  return area * latToKm * lonToKm * 100; // km² -> ha
}

/// Schwerpunkt als Mittelwert der Stützpunkte - dieselbe Näherung, die die
/// Erfassung für `currentGeolocation.geoCoordinates` verwendet.
LatLng polygonCentroid(List<LatLng> points) {
  final ring = openRing(points);
  double sumLat = 0;
  double sumLng = 0;
  for (final p in ring) {
    sumLat += p.latitude;
    sumLng += p.longitude;
  }
  return LatLng(sumLat / ring.length, sumLng / ring.length);
}

/// Index, an dem ein neuer Punkt einzufügen ist, damit er auf der Kante landet,
/// die [point] am nächsten liegt. Gerechnet wird in einer lokalen Ebene: die
/// Längengrade werden mit cos(lat) gestaucht, sonst wäre in Äquatornähe die
/// falsche Kante die nächste.
int insertIndexForPoint(LatLng point, List<LatLng> ring) {
  if (ring.length < 2) return ring.length;

  final scale = math.cos(point.latitude * math.pi / 180).abs();
  double best = double.infinity;
  int bestIndex = 0;

  for (int i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final d = _distanceToSegment(point, a, b, scale);
    if (d < best) {
      best = d;
      bestIndex = i;
    }
  }
  return bestIndex + 1;
}

/// Abstand eines Punktes zur nächsten Kante des Rings, in Metern.
///
/// Damit lässt sich ein versehentlicher Tipp weit neben dem Feld von einem
/// bewussten "hier fehlt eine Ecke" unterscheiden.
double distanceToRingInMeters(LatLng point, List<LatLng> ring) {
  if (ring.length < 2) return double.infinity;

  final scale = math.cos(point.latitude * math.pi / 180).abs();
  double best = double.infinity;
  for (int i = 0; i < ring.length; i++) {
    final d =
        _distanceToSegment(point, ring[i], ring[(i + 1) % ring.length], scale);
    if (d < best) best = d;
  }
  // Gerechnet wurde in Grad (Längengrade bereits gestaucht), zurück in Meter.
  return math.sqrt(best) * 111320.0;
}

/// Ob ein Punkt innerhalb des Rings liegt (Strahlenverfahren).
///
/// Ein Tipp mitten in ein grosses Feld ist Dutzende Meter von jeder Kante
/// entfernt und trotzdem eindeutig gemeint - die reine Abstandsprüfung würde
/// ihn zu Unrecht abweisen.
bool isPointInsideRing(LatLng point, List<LatLng> ring) {
  if (ring.length < 3) return false;

  bool inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final yi = ring[i].latitude, xi = ring[i].longitude;
    final yj = ring[j].latitude, xj = ring[j].longitude;

    final crosses = (yi > point.latitude) != (yj > point.latitude) &&
        point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Ob sich zwei nicht benachbarte Kanten des Rings kreuzen.
///
/// Ein solches Polygon ist keine gültige Fläche: die Trapezformel verrechnet
/// die überschlagenen Teile gegeneinander, die ausgewiesene Fläche wird dann
/// kleiner statt größer. Genau das macht eine versehentlich weit draußen
/// gesetzte Ecke so tückisch - die Zahl sieht unauffällig aus.
bool ringSelfIntersects(List<LatLng> ring) {
  final n = ring.length;
  if (n < 4) return false;

  for (int i = 0; i < n; i++) {
    final a1 = ring[i];
    final a2 = ring[(i + 1) % n];
    for (int j = i + 1; j < n; j++) {
      // Benachbarte Kanten teilen sich einen Punkt - das ist keine Kreuzung.
      if (j == i || (j + 1) % n == i || (i + 1) % n == j) continue;
      if (_segmentsCross(a1, a2, ring[j], ring[(j + 1) % n])) return true;
    }
  }
  return false;
}

bool _segmentsCross(LatLng p1, LatLng p2, LatLng q1, LatLng q2) {
  final d1 = _cross(q1, q2, p1);
  final d2 = _cross(q1, q2, p2);
  final d3 = _cross(p1, p2, q1);
  final d4 = _cross(p1, p2, q2);

  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }
  // Berührungen auf der Kante zählen ebenfalls als Überschneidung.
  if (d1 == 0 && _onSegment(q1, q2, p1)) return true;
  if (d2 == 0 && _onSegment(q1, q2, p2)) return true;
  if (d3 == 0 && _onSegment(p1, p2, q1)) return true;
  if (d4 == 0 && _onSegment(p1, p2, q2)) return true;
  return false;
}

double _cross(LatLng a, LatLng b, LatLng p) =>
    (b.longitude - a.longitude) * (p.latitude - a.latitude) -
    (b.latitude - a.latitude) * (p.longitude - a.longitude);

bool _onSegment(LatLng a, LatLng b, LatLng p) =>
    p.longitude >= math.min(a.longitude, b.longitude) &&
    p.longitude <= math.max(a.longitude, b.longitude) &&
    p.latitude >= math.min(a.latitude, b.latitude) &&
    p.latitude <= math.max(a.latitude, b.latitude);

/// Quadrierter Abstand Punkt/Strecke in gestauchten Gradeinheiten - für einen
/// reinen Vergleich reicht das Quadrat, die Wurzel wäre verschenkte Rechenzeit.
double _distanceToSegment(LatLng p, LatLng a, LatLng b, double scale) {
  final px = p.longitude * scale, py = p.latitude;
  final ax = a.longitude * scale, ay = a.latitude;
  final bx = b.longitude * scale, by = b.latitude;

  final dx = bx - ax, dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    final ex = px - ax, ey = py - ay;
    return ex * ex + ey * ey;
  }

  double t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);

  final cx = ax + t * dx, cy = ay + t * dy;
  final ex = px - cx, ey = py - cy;
  return ex * ex + ey * ey;
}

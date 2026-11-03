import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/polygon_geometry.dart';

/// Einlesen extern korrigierter Feldgrenzen (z.B. aus QGIS) als GeoJSON.
///
/// TFC speichert einen einfachen Ring als `[lat, lon]`; GeoJSON liefert
/// `[lon, lat]` in WGS84. Alles, was sich nicht verlustfrei in einen
/// einfachen Ring übersetzen lässt, wird mit Grund abgelehnt statt still
/// angepasst - die Geometrie landet in einem signierten Job.

/// Warum ein Feature nicht übernommen werden kann.
enum PolygonRejectReason {
  /// Kein Polygon (Punkt, Linie, leere Geometrie ...).
  notPolygon,

  /// MultiPolygon mit mehr als einem Teil.
  multiPart,

  /// Polygon mit Innenringen (Löchern).
  holes,

  /// Koordinaten außerhalb von WGS84 - meist ein Export im lokalen
  /// Koordinatensystem statt EPSG:4326.
  notWgs84,

  /// Weniger als drei Ecken.
  tooFewCorners,
}

class RejectedFeature {
  const RejectedFeature(this.label, this.reason);
  final String label;
  final PolygonRejectReason reason;
}

/// Ein übernehmbares Polygon aus der Datei.
class ImportedPolygon {
  ImportedPolygon({
    required this.featureId,
    required this.label,
    required this.properties,
    required this.ring,
  });

  /// `id` des Features, sonst seine Position in der Datei (ab 1).
  final String featureId;
  final String label;
  final Map<String, dynamic> properties;

  /// Offener Ring in `[lat, lon]`.
  final List<LatLng> ring;

  late final double areaHa = polygonAreaInHectares(closeRing(ring));
  late final LatLng centroid = polygonCentroid(ring);
  late final bool selfIntersects = ringSelfIntersects(ring);

  /// Fingerabdruck der übernommenen Geometrie - steht im Job und erlaubt den
  /// Abgleich mit der gelieferten Datei.
  late final String hash = sha256
      .convert(utf8.encode(jsonEncode(
          [for (final p in ring) [p.longitude, p.latitude]])))
      .toString();

  String? get geoId => property(const ['geoId', 'geoid', 'geo_id', 'GeoID']);

  /// Erster nicht-leerer Wert unter einem der [keys], Groß-/Kleinschreibung
  /// egal - QGIS-Attribute heißen je nach Bearbeiter unterschiedlich.
  String? property(List<String> keys) {
    final wanted = keys.map((k) => k.toLowerCase()).toSet();
    for (final MapEntry(:key, :value) in properties.entries) {
      if (!wanted.contains(key.toLowerCase())) continue;
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

class GeoJsonPolygonFile {
  const GeoJsonPolygonFile(this.polygons, this.rejected);
  final List<ImportedPolygon> polygons;
  final List<RejectedFeature> rejected;
}

/// Liest eine GeoJSON-Datei (FeatureCollection, Feature oder nackte
/// Geometrie). Wirft [FormatException], wenn die Datei kein GeoJSON ist.
GeoJsonPolygonFile parseGeoJsonPolygons(String text) {
  final dynamic root;
  try {
    root = jsonDecode(text);
  } catch (_) {
    throw const FormatException('not valid JSON');
  }
  if (root is! Map) throw const FormatException('not a GeoJSON object');

  // Altes GeoJSON (2008) kann ein Koordinatensystem angeben. Alles außer WGS84
  // würde Koordinaten liefern, die hier niemand umrechnet.
  final crsName = root['crs']?['properties']?['name']?.toString() ?? '';
  final foreignCrs = crsName.isNotEmpty &&
      !crsName.contains('4326') &&
      !crsName.toUpperCase().contains('CRS84');

  final List features = switch (root['type']) {
    'FeatureCollection' => (root['features'] as List?) ?? const [],
    'Feature' => [root],
    'Polygon' || 'MultiPolygon' => [
        {'type': 'Feature', 'geometry': root, 'properties': {}}
      ],
    _ => throw const FormatException('not a GeoJSON object'),
  };

  final polygons = <ImportedPolygon>[];
  final rejected = <RejectedFeature>[];

  for (int i = 0; i < features.length; i++) {
    final feature = features[i];
    if (feature is! Map) continue;
    final properties = Map<String, dynamic>.from(
        (feature['properties'] as Map?)?.map((k, v) => MapEntry('$k', v)) ??
            const {});
    final featureId = feature['id']?.toString() ?? '${i + 1}';
    final label = _labelOf(properties) ?? 'Feature $featureId';

    if (foreignCrs) {
      rejected.add(RejectedFeature(label, PolygonRejectReason.notWgs84));
      continue;
    }
    final result = _ringOf(feature['geometry']);
    if (result case PolygonRejectReason reason) {
      rejected.add(RejectedFeature(label, reason));
    } else if (result case List<LatLng> ring) {
      polygons.add(ImportedPolygon(
        featureId: featureId,
        label: label,
        properties: properties,
        ring: ring,
      ));
    }
  }

  if (polygons.isEmpty && rejected.isEmpty) {
    throw const FormatException('no features');
  }
  return GeoJsonPolygonFile(polygons, rejected);
}

String? _labelOf(Map<String, dynamic> properties) {
  for (final key in const ['name', 'Name', 'NAME', 'field', 'fieldName']) {
    final v = properties[key]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return null;
}

/// Offener Ring in `[lat, lon]` oder der Grund, warum es keinen gibt.
Object _ringOf(dynamic geometry) {
  if (geometry is! Map) return PolygonRejectReason.notPolygon;
  final coords = geometry['coordinates'];
  if (coords is! List) return PolygonRejectReason.notPolygon;

  final List rings;
  switch (geometry['type']) {
    case 'Polygon':
      rings = coords;
    case 'MultiPolygon':
      // QGIS speichert auch einfache Flächen gern als MultiPolygon mit einem
      // Teil - das ist übernehmbar.
      if (coords.length != 1) return PolygonRejectReason.multiPart;
      if (coords.first is! List) return PolygonRejectReason.notPolygon;
      rings = coords.first as List;
    default:
      return PolygonRejectReason.notPolygon;
  }
  if (rings.isEmpty || rings.first is! List) {
    return PolygonRejectReason.notPolygon;
  }
  if (rings.length > 1) return PolygonRejectReason.holes;

  final points = <LatLng>[];
  for (final position in rings.first as List) {
    if (position is! List || position.length < 2) {
      return PolygonRejectReason.notPolygon;
    }
    final lon = position[0], lat = position[1];
    if (lon is! num || lat is! num) return PolygonRejectReason.notPolygon;
    if (lat.abs() > 90 || lon.abs() > 180) return PolygonRejectReason.notWgs84;
    points.add(LatLng(lat.toDouble(), lon.toDouble()));
  }

  final ring = openRing(points);
  if (ring.length < 3) return PolygonRejectReason.tooFewCorners;
  return ring;
}

/// Entfernung zweier Punkte in Metern (Haversine).
double distanceInMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

/// Sortiert die Polygone nach Passung zum Feld: gleiche GeoID, dann gleicher
/// Name, dann Nähe zum bisherigen Polygon.
List<ImportedPolygon> rankForField(
  List<ImportedPolygon> polygons, {
  String? geoId,
  String? name,
  LatLng? currentCentroid,
}) {
  String norm(String? s) => (s ?? '').trim().toLowerCase();
  int tier(ImportedPolygon p) {
    if (norm(geoId).isNotEmpty && norm(p.geoId) == norm(geoId)) return 0;
    if (norm(name).isNotEmpty && norm(p.label) == norm(name)) return 1;
    return 2;
  }

  double distance(ImportedPolygon p) => currentCentroid == null
      ? 0
      : distanceInMeters(currentCentroid, p.centroid);

  return [...polygons]..sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      return byTier != 0 ? byTier : distance(a).compareTo(distance(b));
    });
}

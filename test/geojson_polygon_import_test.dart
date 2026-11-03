import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trace_foodchain_app/services/geojson_polygon_import.dart';

/// Kleines Quadrat bei Tegucigalpa, GeoJSON-Reihenfolge [lon, lat], geschlossen.
List<List<double>> _square(double lon, double lat, [double d = 0.001]) => [
      [lon, lat],
      [lon + d, lat],
      [lon + d, lat + d],
      [lon, lat + d],
      [lon, lat],
    ];

Map<String, dynamic> _feature(
  Map<String, dynamic> geometry, {
  Map<String, dynamic> properties = const {},
  Object? id,
}) =>
    {
      'type': 'Feature',
      if (id != null) 'id': id,
      'geometry': geometry,
      'properties': properties,
    };

Map<String, dynamic> _polygon(List<List<List<double>>> rings) =>
    {'type': 'Polygon', 'coordinates': rings};

String _collection(List<Map<String, dynamic>> features) =>
    jsonEncode({'type': 'FeatureCollection', 'features': features});

void main() {
  group('parseGeoJsonPolygons', () {
    test('swaps [lon, lat] to [lat, lon] and opens the ring', () {
      final file = parseGeoJsonPolygons(_collection([
        _feature(_polygon([_square(-87.2, 14.1)]),
            properties: {'name': 'Parcela 1'}, id: 7),
      ]));

      final polygon = file.polygons.single;
      expect(polygon.ring.length, 4);
      expect(polygon.ring.first, const LatLng(14.1, -87.2));
      expect(polygon.label, 'Parcela 1');
      expect(polygon.featureId, '7');
      expect(polygon.areaHa, greaterThan(1));
      expect(file.rejected, isEmpty);
    });

    test('accepts a single-part MultiPolygon as QGIS writes it', () {
      final file = parseGeoJsonPolygons(_collection([
        _feature({
          'type': 'MultiPolygon',
          'coordinates': [
            [_square(-87.2, 14.1)]
          ],
        }),
      ]));
      expect(file.polygons.single.ring.length, 4);
    });

    test('accepts a bare Feature and a bare geometry', () {
      final feature = _feature(_polygon([_square(-87.2, 14.1)]));
      expect(parseGeoJsonPolygons(jsonEncode(feature)).polygons, hasLength(1));
      expect(
          parseGeoJsonPolygons(jsonEncode(feature['geometry'])).polygons,
          hasLength(1));
    });

    test('rejects what cannot become a simple ring, with the reason', () {
      final file = parseGeoJsonPolygons(_collection([
        _feature({
          'type': 'MultiPolygon',
          'coordinates': [
            [_square(-87.2, 14.1)],
            [_square(-87.3, 14.2)],
          ],
        }, properties: {'name': 'multi'}),
        _feature(
            _polygon([_square(-87.2, 14.1, 0.01), _square(-87.195, 14.105)]),
            properties: {'name': 'holes'}),
        // UTM-Koordinaten statt WGS84.
        _feature(_polygon([_square(480000, 1560000, 50)]),
            properties: {'name': 'utm'}),
        _feature({
          'type': 'Point',
          'coordinates': [-87.2, 14.1]
        }, properties: {'name': 'point'}),
        _feature(_polygon([
          [
            [-87.2, 14.1],
            [-87.1, 14.1],
            [-87.2, 14.1],
          ]
        ]), properties: {'name': 'line'}),
      ]));

      expect(file.polygons, isEmpty);
      expect({for (final r in file.rejected) r.label: r.reason}, {
        'multi': PolygonRejectReason.multiPart,
        'holes': PolygonRejectReason.holes,
        'utm': PolygonRejectReason.notWgs84,
        'point': PolygonRejectReason.notPolygon,
        'line': PolygonRejectReason.tooFewCorners,
      });
    });

    test('rejects a file declaring a non-WGS84 crs', () {
      final file = parseGeoJsonPolygons(jsonEncode({
        'type': 'FeatureCollection',
        'crs': {
          'type': 'name',
          'properties': {'name': 'urn:ogc:def:crs:EPSG::32616'}
        },
        'features': [
          _feature(_polygon([_square(-87.2, 14.1)]))
        ],
      }));
      expect(file.rejected.single.reason, PolygonRejectReason.notWgs84);
    });

    test('throws on anything that is not GeoJSON', () {
      expect(() => parseGeoJsonPolygons('not json'),
          throwsA(isA<FormatException>()));
      expect(() => parseGeoJsonPolygons('{"foo": 1}'),
          throwsA(isA<FormatException>()));
    });

    test('reads attributes case-insensitively', () {
      final polygon = parseGeoJsonPolygons(_collection([
        _feature(_polygon([_square(-87.2, 14.1)]),
            properties: {'Corrected_By': 'ESA - M. López', 'GEOID': 'abc'}),
      ])).polygons.single;
      expect(polygon.property(['corrected_by']), 'ESA - M. López');
      expect(polygon.geoId, 'abc');
    });

    test('hash depends on the geometry only', () {
      final a = parseGeoJsonPolygons(_collection([
        _feature(_polygon([_square(-87.2, 14.1)]), properties: {'name': 'a'}),
      ])).polygons.single;
      final b = parseGeoJsonPolygons(_collection([
        _feature(_polygon([_square(-87.2, 14.1)]), properties: {'name': 'b'}),
      ])).polygons.single;
      final c = parseGeoJsonPolygons(_collection([
        _feature(_polygon([_square(-87.2, 14.2)])),
      ])).polygons.single;
      expect(a.hash, b.hash);
      expect(a.hash, isNot(c.hash));
    });
  });

  group('rankForField', () {
    final polygons = parseGeoJsonPolygons(_collection([
      _feature(_polygon([_square(-87.0, 14.0)]), properties: {'name': 'far'}),
      _feature(_polygon([_square(-87.2, 14.1)]), properties: {'name': 'near'}),
      _feature(_polygon([_square(-86.5, 13.5)]),
          properties: {'name': 'Parcela Norte'}),
      _feature(_polygon([_square(-86.0, 13.0)]),
          properties: {'name': 'x', 'geoId': 'G-1'}),
    ])).polygons;

    List<String> labels(List<ImportedPolygon> list) =>
        list.map((p) => p.label).toList();

    test('geoId first, then name, then distance', () {
      final ranked = rankForField(polygons,
          geoId: 'g-1',
          name: 'parcela norte',
          currentCentroid: const LatLng(14.1005, -87.1995));
      expect(labels(ranked), ['x', 'Parcela Norte', 'near', 'far']);
    });

    test('without identifiers the nearest polygon comes first', () {
      final ranked = rankForField(polygons,
          currentCentroid: const LatLng(14.1005, -87.1995));
      expect(ranked.first.label, 'near');
    });
  });
}

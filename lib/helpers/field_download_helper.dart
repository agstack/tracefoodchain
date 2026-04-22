import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/service_functions.dart';
import '../utils/file_download.dart';

/// Shared helper for downloading field boundaries as GeoJSON or KML.
class FieldDownloadHelper {
  /// Parses a boundaries JSON string (format: {"coordinates": [[lon, lat], ...]})
  /// into a list of [lon, lat] pairs.
  static List<List<double>>? parseBoundaries(String? boundariesValue) {
    if (boundariesValue == null || boundariesValue.isEmpty) return null;
    try {
      final decoded = jsonDecode(boundariesValue);
      if (decoded is Map && decoded['coordinates'] is List) {
        return (decoded['coordinates'] as List).map((e) {
          final pair = e as List;
          return [
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          ];
        }).toList();
      }
    } catch (e) {
      debugPrint('Error parsing boundaries: $e');
    }
    return null;
  }

  static String escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Downloads field boundaries as a GeoJSON file.
  static Future<void> downloadGeoJSON(
    BuildContext context, {
    required String name,
    required String? boundariesJson,
    required AppLocalizations l10n,
    String? geoId,
    String? area,
  }) async {
    final coords = parseBoundaries(boundariesJson);
    if (coords == null || coords.isEmpty) {
      await fshowInfoDialog(context, l10n.noCoordinatesAvailable);
      return;
    }
    final ring = List<List<double>>.from(coords);
    if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
      ring.add(ring.first);
    }
    final properties = <String, dynamic>{'name': name};
    if (area != null && area.isNotEmpty) properties['area_ha'] = area;
    if (geoId != null && geoId.isNotEmpty) properties['geoId'] = geoId;

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
          'properties': properties,
        }
      ],
    };
    final safeName = name.replaceAll(RegExp(r'[^\w-]'), '_');
    final bytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(geojson));
    try {
      await downloadFile(bytes, '$safeName.geojson');
      if (context.mounted) {
        await fshowInfoDialog(context, l10n.fieldCoordinatesDownloaded);
      }
    } catch (e) {
      if (context.mounted) await fshowInfoDialog(context, 'Error: $e');
    }
  }

  /// Downloads field boundaries as a KML file.
  static Future<void> downloadKML(
    BuildContext context, {
    required String name,
    required String? boundariesJson,
    required AppLocalizations l10n,
    String? area,
    String? geoId,
  }) async {
    final coords = parseBoundaries(boundariesJson);
    if (coords == null || coords.isEmpty) {
      await fshowInfoDialog(context, l10n.noCoordinatesAvailable);
      return;
    }
    final ring = List<List<double>>.from(coords);
    if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
      ring.add(ring.first);
    }
    final coordStr = ring.map((c) => '${c[0]},${c[1]},0').join(' ');
    final descParts = <String>[];
    if (area != null && area.isNotEmpty) {
      descParts.add('Area: ${escapeXml(area)} ha');
    }
    if (geoId != null && geoId.isNotEmpty) {
      descParts.add('Geo ID: ${escapeXml(geoId)}');
    }
    final description = descParts.join(' | ');
    final kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>${escapeXml(name)}</name>
    <Placemark>
      <name>${escapeXml(name)}</name>
      <description>$description</description>
      <Style>
        <LineStyle><color>ff0000ff</color><width>2</width></LineStyle>
        <PolyStyle><color>330000ff</color></PolyStyle>
      </Style>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$coordStr</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>''';
    final safeName = name.replaceAll(RegExp(r'[^\w-]'), '_');
    final bytes = utf8.encode(kmlContent);
    try {
      await downloadFile(bytes, '$safeName.kml');
      if (context.mounted) {
        await fshowInfoDialog(context, l10n.fieldCoordinatesDownloaded);
      }
    } catch (e) {
      if (context.mounted) await fshowInfoDialog(context, 'Error: $e');
    }
  }
}

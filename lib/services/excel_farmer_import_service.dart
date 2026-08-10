import 'dart:math' as math;

import 'package:excel/excel.dart';

/// TEMPORÄRER Importer für Bauern/Plots, die nicht mehr im Asset Registry sind.
///
/// Die Quelldatei liefert pro Zeile genau einen Plot mit dem Centroid (lat/lon)
/// und der Ertragsfläche in Hektar - kein echtes Polygon. Aus diesen beiden
/// Angaben wird ein flächengleiches Pseudo-Polygon um den Centroid erzeugt.
///
/// Dieser Service parst und rechnet nur; er legt keine openRAL-Objekte an und
/// schreibt nichts in die Datenbank.

/// Eine eingelesene Zeile inklusive abgeleitetem Pseudo-Polygon.
class ImportedPlotRow {
  /// 1-basierte Zeilennummer in der Excel-Datei (inkl. Kopfzeile).
  final int excelRow;
  final String personName;
  final String dni;
  final String intermediary;
  final String municipality;
  final String community;
  final String buyer;

  /// GeoID aus der Datei. Diese IDs sind derzeit tot (Asset Registry arbeitet
  /// an Version 2.0), werden also nur als alternateID mit issuedBy
  /// "Asset Registry" mitgeführt und NICHT für Lookups verwendet.
  final String geoId;

  /// Site-Kennung aus der Datei, z.B. "site_001".
  final String siteId;
  final double latitude;
  final double longitude;
  final double areaHectares;

  /// Geschlossener GeoJSON-Ring aus [lon, lat]-Paaren.
  final List<List<double>> polygon;

  const ImportedPlotRow({
    required this.excelRow,
    required this.personName,
    required this.dni,
    required this.intermediary,
    required this.municipality,
    required this.community,
    required this.buyer,
    required this.geoId,
    required this.siteId,
    required this.latitude,
    required this.longitude,
    required this.areaHectares,
    required this.polygon,
  });

  /// Name für das spätere Feld-Objekt: Site-Kennung, sonst Zeilennummer.
  String get fieldName => siteId.isNotEmpty ? siteId : 'row_$excelRow';

  /// alternateIDs für das spätere Feld-Objekt. Die Asset-Registry-GeoID wird
  /// nur dokumentiert, nicht zur Auflösung benutzt.
  List<Map<String, String>> get plannedAlternateIds => [
        if (geoId.isNotEmpty) {'UID': geoId, 'issuedBy': 'Asset Registry'},
      ];

  Map<String, dynamic> toGeoJsonFeature() => {
        'type': 'Feature',
        'properties': {
          's2_index': '8,13',
          'site': siteId,
          'personName': personName,
          'areaHa': areaHectares,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [polygon],
        },
      };
}

/// Eine zusammengeführte Ortsbezeichnung: mehrere Schreibweisen in der Datei
/// wurden auf eine kanonische Form abgebildet.
class NameNormalization {
  /// Spalte, aus der die Werte stammen, z.B. "Municipality".
  final String column;

  /// Gewählte Schreibweise (die in der Datei häufigste).
  final String canonical;

  /// Alle vorgefundenen Schreibweisen mit ihrer Häufigkeit.
  final Map<String, int> variants;

  const NameNormalization({
    required this.column,
    required this.canonical,
    required this.variants,
  });

  /// Die verworfenen Schreibweisen.
  Iterable<String> get replaced => variants.keys.where((v) => v != canonical);
}

/// Ergebnis eines Parse-Laufs.
class ExcelImportResult {
  final List<ImportedPlotRow> plots;

  /// Zeilen, die übersprungen wurden - je Eintrag eine erklärende Meldung.
  final List<String> warnings;

  /// Kopfzeile wie in der Datei gefunden (Originalschreibweise).
  final List<String> headers;

  /// Header, für die keine Spalte zugeordnet werden konnte.
  final List<String> missingColumns;

  /// Ortsnamen, bei denen mehrere Schreibweisen zusammengeführt wurden.
  final List<NameNormalization> normalizations;

  final String sheetName;

  const ExcelImportResult({
    required this.plots,
    required this.warnings,
    required this.headers,
    required this.missingColumns,
    required this.normalizations,
    required this.sheetName,
  });

  bool get isEmpty => plots.isEmpty;
}

/// Spaltenaliase - alles kleingeschrieben und ohne Sonderzeichen verglichen.
const Map<String, List<String>> _columnAliases = {
  'personName': ['assignedpersonname', 'personname', 'name', 'farmer'],
  'dni': ['dni', 'nationalid', 'idnumber'],
  'intermediary': ['intermediary', 'intermediario'],
  'municipality': ['municipality', 'municipio'],
  'community': ['community', 'comunidad', 'village'],
  'buyer': ['buyer', 'comprador'],
  'geoId': ['geoid', 'geo_id', 'geoidhash'],
  'siteId': ['site', 'siteid', 'plot', 'plotid'],
  'latitude': ['lat', 'latitude', 'latitud'],
  'longitude': ['lon', 'lng', 'long', 'longitude', 'longitud'],
  'areaHectares': [
    'productivecoffeearealastharvestinhectares',
    'areaha',
    'hectares',
    'hectareas',
    'area',
  ],
};

/// Spalten, ohne die kein sinnvoller Import möglich ist.
const List<String> _requiredColumns = ['latitude', 'longitude', 'areaHectares'];

String _normalizeHeader(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _cellToString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

double? _cellToDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Diakritika der spanischen Schreibweise. Dart hat keine Unicode-Normalisierung
/// in der Standardbibliothek; für Ortsnamen in Honduras reicht dieser Satz.
const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Vergleichsschlüssel für Ortsnamen: kleingeschrieben, ohne Akzente,
/// Mehrfach-Leerzeichen zusammengefasst und getrimmt.
///
/// Damit fallen "San Nicolás", "San Nicolas" und " San Rafael" zusammen.
String placeKey(String raw) {
  final lower = raw.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString().split(RegExp(r'\s+')).join(' ');
}

/// Bestimmt je Vergleichsschlüssel die kanonische Schreibweise per
/// Mehrheitsentscheid: Die in der Datei häufigste Variante gewinnt, damit die
/// korrekt akzentuierte Form erhalten bleibt ("San Nicolás" 262x schlägt
/// "San Nicolas" 67x). Bei Gleichstand gewinnt die alphabetisch erste Variante,
/// damit das Ergebnis reproduzierbar ist.
Map<String, NameNormalization> _buildCanonicalMap(
  String column,
  Iterable<String> rawValues,
) {
  final counts = <String, Map<String, int>>{};
  for (final raw in rawValues) {
    if (raw.trim().isEmpty) continue;
    final key = placeKey(raw);
    counts.putIfAbsent(key, () => <String, int>{});
    counts[key]![raw] = (counts[key]![raw] ?? 0) + 1;
  }

  final result = <String, NameNormalization>{};
  counts.forEach((key, variants) {
    final sorted = variants.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    result[key] = NameNormalization(
      column: column,
      canonical: sorted.first.key.trim(),
      variants: variants,
    );
  });
  return result;
}

/// Zwischenform: Rohwerte einer gültigen Zeile, bevor die Ortsnamen
/// vereinheitlicht sind.
class _RawRow {
  final int excelRow;
  final String personName;
  final String dni;
  final String intermediary;
  final String municipality;
  final String community;
  final String buyer;
  final String geoId;
  final String siteId;
  final double latitude;
  final double longitude;
  final double areaHectares;

  const _RawRow({
    required this.excelRow,
    required this.personName,
    required this.dni,
    required this.intermediary,
    required this.municipality,
    required this.community,
    required this.buyer,
    required this.geoId,
    required this.siteId,
    required this.latitude,
    required this.longitude,
    required this.areaHectares,
  });
}

/// Erzeugt ein flächengleiches, regelmäßiges Pseudo-Polygon um einen Centroid.
///
/// [areaHectares] wird exakt getroffen: Für ein regelmäßiges n-Eck gilt
/// A = 0.5 * n * r² * sin(2π/n), also r = sqrt(2A / (n * sin(2π/n))).
/// Der Ring läuft gegen den Uhrzeigersinn (GeoJSON-Konvention für Außenringe)
/// und ist geschlossen (letzter Punkt == erster Punkt).
List<List<double>> pseudoPolygonFromCentroid({
  required double latitude,
  required double longitude,
  required double areaHectares,
  int vertices = 16,
}) {
  if (areaHectares <= 0) return const [];
  final n = vertices < 3 ? 3 : vertices;

  final areaSqm = areaHectares * 10000.0;
  final radiusMeters = math.sqrt(2 * areaSqm / (n * math.sin(2 * math.pi / n)));

  const metersPerDegreeLat = 111320.0;
  final latRad = latitude * math.pi / 180.0;
  // Nahe den Polen geht cos(lat) gegen 0 - abfangen, damit die Länge nicht
  // explodiert. Für die Kaffeeanbaugebiete ist das nie relevant.
  final cosLat = math.max(math.cos(latRad).abs(), 0.01);
  final metersPerDegreeLon = metersPerDegreeLat * cosLat;

  final ring = <List<double>>[];
  for (int i = 0; i < n; i++) {
    final angle = 2 * math.pi * i / n;
    // x = Ost, y = Nord. Negatives x läuft gegen den Uhrzeigersinn.
    final east = -radiusMeters * math.sin(angle);
    final north = radiusMeters * math.cos(angle);
    final lon = longitude + east / metersPerDegreeLon;
    final lat = latitude + north / metersPerDegreeLat;
    ring.add([
      double.parse(lon.toStringAsFixed(7)),
      double.parse(lat.toStringAsFixed(7)),
    ]);
  }
  ring.add(List<double>.from(ring.first));
  return ring;
}

/// Liest die Excel-Datei und liefert die Plots samt Pseudo-Polygonen.
///
/// [vertices] steuert die Auflösung des Pseudo-Polygons (Default 16 Ecken,
/// 4 ergibt ein Quadrat).
ExcelImportResult parseFarmerExcel(
  List<int> bytes, {
  int vertices = 16,
}) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    return const ExcelImportResult(
      plots: [],
      warnings: ['Die Datei enthält kein Tabellenblatt.'],
      headers: [],
      missingColumns: [],
      normalizations: [],
      sheetName: '',
    );
  }

  final sheetName = excel.tables.keys.first;
  final sheet = excel.tables[sheetName]!;
  final rows = sheet.rows;

  if (rows.length < 2) {
    return ExcelImportResult(
      plots: const [],
      warnings: const ['Das Tabellenblatt enthält keine Datenzeilen.'],
      headers: const [],
      missingColumns: const [],
      normalizations: const [],
      sheetName: sheetName,
    );
  }

  // ── Kopfzeile → Spaltenindizes ────────────────────────────────────────────
  final headerCells = rows.first;
  final headers = <String>[];
  final normalizedToIndex = <String, int>{};
  for (int i = 0; i < headerCells.length; i++) {
    final raw = _cellToString(headerCells[i]?.value);
    headers.add(raw);
    if (raw.isEmpty) continue;
    normalizedToIndex.putIfAbsent(_normalizeHeader(raw), () => i);
  }

  final columnIndex = <String, int>{};
  _columnAliases.forEach((field, aliases) {
    for (final alias in aliases) {
      final idx = normalizedToIndex[alias];
      if (idx != null) {
        columnIndex[field] = idx;
        return;
      }
    }
  });

  final missing =
      _requiredColumns.where((c) => !columnIndex.containsKey(c)).toList();
  if (missing.isNotEmpty) {
    return ExcelImportResult(
      plots: const [],
      warnings: [
        'Pflichtspalten fehlen: ${missing.join(', ')}. '
            'Gefundene Spalten: ${headers.where((h) => h.isNotEmpty).join(', ')}',
      ],
      headers: headers,
      missingColumns: missing,
      normalizations: const [],
      sheetName: sheetName,
    );
  }

  // ── Durchgang 1: Datenzeilen roh einlesen und validieren ─────────────────
  final rawRows = <_RawRow>[];
  final warnings = <String>[];

  dynamic cell(List<Data?> row, String field) {
    final idx = columnIndex[field];
    if (idx == null || idx >= row.length) return null;
    return row[idx]?.value;
  }

  for (int r = 1; r < rows.length; r++) {
    final row = rows[r];
    final excelRow = r + 1; // 1-basiert inkl. Kopfzeile

    // Komplett leere Zeilen stillschweigend überspringen.
    final isBlank = row.every((c) => _cellToString(c?.value).isEmpty);
    if (isBlank) continue;

    final lat = _cellToDouble(cell(row, 'latitude'));
    final lon = _cellToDouble(cell(row, 'longitude'));
    final area = _cellToDouble(cell(row, 'areaHectares'));
    final siteId = _cellToString(cell(row, 'siteId'));
    final label = siteId.isNotEmpty ? siteId : 'Zeile $excelRow';

    if (lat == null || lon == null) {
      warnings.add('Zeile $excelRow ($label): lat/lon fehlt oder unlesbar.');
      continue;
    }
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      warnings.add(
          'Zeile $excelRow ($label): Koordinate außerhalb des gültigen Bereichs '
          '(lat=$lat, lon=$lon).');
      continue;
    }
    if (area == null || area <= 0) {
      warnings.add('Zeile $excelRow ($label): Fläche fehlt oder ist <= 0 '
          '(${_cellToString(cell(row, 'areaHectares'))}).');
      continue;
    }

    rawRows.add(_RawRow(
      excelRow: excelRow,
      personName: _cellToString(cell(row, 'personName')),
      dni: _cellToString(cell(row, 'dni')),
      intermediary: _cellToString(cell(row, 'intermediary')),
      municipality: _cellToString(cell(row, 'municipality')),
      community: _cellToString(cell(row, 'community')),
      buyer: _cellToString(cell(row, 'buyer')),
      geoId: _cellToString(cell(row, 'geoId')),
      siteId: siteId,
      latitude: lat,
      longitude: lon,
      areaHectares: area,
    ));
  }

  // ── Durchgang 2: Ortsnamen vereinheitlichen ──────────────────────────────
  // Erst jetzt möglich, weil die kanonische Schreibweise per Mehrheitsentscheid
  // über alle Zeilen bestimmt wird.
  final municipalityMap =
      _buildCanonicalMap('Municipality', rawRows.map((r) => r.municipality));
  final communityMap =
      _buildCanonicalMap('Community', rawRows.map((r) => r.community));

  String canonical(Map<String, NameNormalization> map, String raw) =>
      raw.trim().isEmpty ? '' : (map[placeKey(raw)]?.canonical ?? raw.trim());

  final plots = rawRows
      .map((r) => ImportedPlotRow(
            excelRow: r.excelRow,
            personName: r.personName,
            dni: r.dni,
            intermediary: r.intermediary,
            municipality: canonical(municipalityMap, r.municipality),
            community: canonical(communityMap, r.community),
            buyer: r.buyer,
            geoId: r.geoId,
            siteId: r.siteId,
            latitude: r.latitude,
            longitude: r.longitude,
            areaHectares: r.areaHectares,
            polygon: pseudoPolygonFromCentroid(
              latitude: r.latitude,
              longitude: r.longitude,
              areaHectares: r.areaHectares,
              vertices: vertices,
            ),
          ))
      .toList();

  // Nur die Gruppen melden, in denen tatsächlich zusammengeführt wurde.
  final normalizations = [
    ...municipalityMap.values,
    ...communityMap.values,
  ].where((n) => n.variants.length > 1).toList()
    ..sort((a, b) {
      final byColumn = a.column.compareTo(b.column);
      return byColumn != 0 ? byColumn : a.canonical.compareTo(b.canonical);
    });

  return ExcelImportResult(
    plots: plots,
    warnings: warnings,
    headers: headers,
    missingColumns: const [],
    normalizations: normalizations,
    sheetName: sheetName,
  );
}

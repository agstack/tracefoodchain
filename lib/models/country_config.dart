import 'package:cloud_firestore/cloud_firestore.dart';

/// Länderspezifische Einstellungen für die Registrierung von Farmer, Farm und
/// Feld.
///
/// Liegt in Firestore unter `TFC_countries/{code}` und ist bewusst KEIN
/// openRAL-Objekt: es wird weder signiert noch über den Objekt-Sync verteilt.
/// Registrierungen verweisen nur über den Ländercode in
/// `currentGeolocation.postalAddress.country` darauf.
class CountryConfig {
  const CountryConfig({
    required this.code,
    required this.name,
    this.active = true,
    this.legacyNames = const [],
    this.areaUnits = const [],
    this.defaultAreaUnit = 'ha',
    this.regionLabels = const [],
    this.regions = const [],
    this.whispNationalCode = '',
    this.producerRegistry = producerRegistryNone,
    this.updatedAt,
    this.updatedBy = '',
  });

  static const String producerRegistryNone = 'none';
  static const String producerRegistryIhcafe = 'ihcafe';
  static const List<String> producerRegistries = [
    producerRegistryNone,
    producerRegistryIhcafe,
  ];

  /// Höchstzahl der Verwaltungsebenen im Registrierungsformular
  /// (Bundesland/Departamento, Gemeinde, Ort).
  static const int maxRegionLevels = 3;

  /// ISO 3166-1 alpha-2, in Großbuchstaben (z.B. "HN").
  final String code;
  final String name;

  /// Nur aktive Länder lassen sich Nutzern zuweisen.
  final bool active;

  /// Frühere Schreibweisen, unter denen Registrierungen dieses Landes
  /// gespeichert wurden (z.B. "Honduras"). Bestehende Daten werden nicht
  /// migriert - signierte Methoden dürfen nicht nachträglich geändert werden.
  final List<String> legacyNames;

  /// Gleiches Format wie bisher `areaUnitsHonduras`:
  /// `{"name": "manzanas", "symbol": "mz", "toHectareFactor": 0.70259}`.
  final List<Map<String, dynamic>> areaUnits;

  /// Einheiten für Länder, die keine eigenen festlegen.
  static const List<Map<String, dynamic>> fallbackAreaUnits = [
    {"name": "hectares", "symbol": "ha", "toHectareFactor": 1.0},
    {"name": "acres", "symbol": "ac", "toHectareFactor": 0.404686},
  ];

  /// [areaUnits], oder [fallbackAreaUnits], wenn das Land keine hat.
  List<Map<String, dynamic>> get effectiveAreaUnits =>
      areaUnits.isNotEmpty ? areaUnits : fallbackAreaUnits;

  /// Vorauswahl der Flächeneinheit: [preferred], wenn das Land sie kennt,
  /// sonst [defaultAreaUnit], sonst die erste Einheit.
  String initialAreaUnit([String? preferred]) {
    final symbols = effectiveAreaUnits.map((u) => u['symbol']).toList();
    if (preferred != null && symbols.contains(preferred)) return preferred;
    if (symbols.contains(defaultAreaUnit)) return defaultAreaUnit;
    return symbols.first as String;
  }

  /// Bezeichnung der Verwaltungsebene [level] (0 = oberste), oder null, wenn
  /// das Land dafür keine festlegt.
  String? regionLabel(int level) =>
      level < regionLabels.length && regionLabels[level].trim().isNotEmpty
          ? regionLabels[level]
          : null;

  /// Symbol der vorausgewählten Flächeneinheit.
  final String defaultAreaUnit;

  /// Bezeichnungen der Verwaltungsebenen in Landessprache, von oben nach
  /// unten (z.B. Departamento, Municipio, Aldea).
  final List<String> regionLabels;

  /// Regionen der obersten Verwaltungsebene (z.B. die Departamentos).
  final List<String> regions;

  /// Ländercode für die nationalen Datensätze der WHISP-Analyse, leer wenn
  /// WHISP für das Land keine hat.
  final String whispNationalCode;

  /// Register, gegen das beim Excel-Upload abgeglichen wird.
  final String producerRegistry;

  final DateTime? updatedAt;
  final String updatedBy;

  static bool isValidCode(String code) => RegExp(r'^[A-Z]{2}$').hasMatch(code);

  /// Vergleicht Regionsnamen ohne Groß-/Kleinschreibung und Akzente
  /// ("Copan" = "Copán"): Freitext und Importe schreiben sie uneinheitlich.
  static bool sameRegion(String a, String b) {
    String fold(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ñ', 'n');
    return fold(a) == fold(b);
  }

  /// Alle Werte, unter denen Registrierungen dieses Landes in
  /// `postalAddress.country` stehen können - für Firestore-`whereIn`.
  List<String> get storedValues => [code, ...legacyNames];

  /// Ob [value] dieses Land bezeichnet: Code, Name oder frühere Schreibweise.
  bool matches(String? value) {
    final v = value?.trim().toLowerCase() ?? '';
    if (v.isEmpty) return false;
    return v == code.toLowerCase() ||
        v == name.toLowerCase() ||
        legacyNames.any((n) => n.toLowerCase() == v);
  }

  factory CountryConfig.fromMap(String code, Map<dynamic, dynamic> map) {
    List<String> strings(dynamic raw) => raw is List
        ? raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const [];

    final units = <Map<String, dynamic>>[];
    final rawUnits = map['areaUnits'];
    if (rawUnits is List) {
      for (final u in rawUnits) {
        if (u is! Map) continue;
        final factor = u['toHectareFactor'];
        units.add({
          'name': u['name']?.toString() ?? '',
          'symbol': u['symbol']?.toString() ?? '',
          'toHectareFactor': factor is num
              ? factor.toDouble()
              : double.tryParse(factor?.toString() ?? '') ?? 1.0,
        });
      }
    }

    return CountryConfig(
      code: code.toUpperCase(),
      name: map['name']?.toString() ?? code,
      active: map['active'] != false,
      legacyNames: strings(map['legacyNames']),
      areaUnits: units,
      defaultAreaUnit: map['defaultAreaUnit']?.toString() ?? 'ha',
      regionLabels: strings(map['regionLabels']),
      regions: strings(map['regions']),
      whispNationalCode: map['whispNationalCode']?.toString() ?? '',
      producerRegistry: producerRegistries.contains(map['producerRegistry'])
          ? map['producerRegistry'] as String
          : producerRegistryNone,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy']?.toString() ?? '',
    );
  }

  /// [updatedAt] als ISO-String, damit die Map auch in Hive (als JSON)
  /// gespeichert werden kann. Beim Schreiben nach Firestore wird er durch den
  /// Server-Zeitstempel ersetzt.
  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'active': active,
        'legacyNames': legacyNames,
        'areaUnits': areaUnits,
        'defaultAreaUnit': defaultAreaUnit,
        'regionLabels': regionLabels,
        'regions': regions,
        'whispNationalCode': whispNationalCode,
        'producerRegistry': producerRegistry,
        'updatedAt': updatedAt?.toIso8601String(),
        'updatedBy': updatedBy,
      };

  CountryConfig copyWith({
    String? name,
    bool? active,
    List<String>? legacyNames,
    List<Map<String, dynamic>>? areaUnits,
    String? defaultAreaUnit,
    List<String>? regionLabels,
    List<String>? regions,
    String? whispNationalCode,
    String? producerRegistry,
    DateTime? updatedAt,
    String? updatedBy,
  }) =>
      CountryConfig(
        code: code,
        name: name ?? this.name,
        active: active ?? this.active,
        legacyNames: legacyNames ?? this.legacyNames,
        areaUnits: areaUnits ?? this.areaUnits,
        defaultAreaUnit: defaultAreaUnit ?? this.defaultAreaUnit,
        regionLabels: regionLabels ?? this.regionLabels,
        regions: regions ?? this.regions,
        whispNationalCode: whispNationalCode ?? this.whispNationalCode,
        producerRegistry: producerRegistry ?? this.producerRegistry,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
      );

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

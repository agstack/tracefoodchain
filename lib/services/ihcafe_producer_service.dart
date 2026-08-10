import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline-Verzeichnis der IHCafe-Produzenten (Registrar/Fast Upload).
///
/// Der Registrar importiert den IHCafe-Export einmalig (im Online-Zustand bzw.
/// per Dateiauswahl) und kann die Liste danach ohne Netz durchsuchen, um einen
/// Produzenten auszuwählen statt ihn abzutippen.
///
/// Bewusst NUR für den Registrar- und den Fast-Upload-Workflow gedacht. Im
/// Farmer-/Buyer-Workflow wird der Import nicht angeboten, damit dort kein
/// Speicher belegt wird.
///
/// Gespeichert wird eine verdichtete Form des Exports: aus 28,6 MB Rohdaten
/// werden rund 8 MB, weil regional, agencia und status-Details entfallen.

const String ihcafeBoxName = 'ihcafeProducers';
const String _kDataKey = 'data';
const String _kMetaKey = 'meta';

/// Eine Finca eines Produzenten.
class IhcafeFinca {
  final int? fincaId;
  final String? nombreFinca;
  final String departamento;
  final String municipio;
  final String? aldea;
  final String? direccion;

  const IhcafeFinca({
    this.fincaId,
    this.nombreFinca,
    required this.departamento,
    required this.municipio,
    this.aldea,
    this.direccion,
  });

  factory IhcafeFinca.fromExport(Map<String, dynamic> json) => IhcafeFinca(
        fincaId: json['finca_id'] as int?,
        nombreFinca: json['nombre_finca'] as String?,
        departamento:
            (json['departamento']?['nombre'] as String?)?.trim() ?? '',
        municipio: (json['municipio']?['nombre'] as String?)?.trim() ?? '',
        aldea: json['aldea']?['nombre'] as String?,
        direccion: json['direccion'] as String?,
      );

  factory IhcafeFinca.fromCompact(Map<dynamic, dynamic> c) => IhcafeFinca(
        fincaId: c['i'] as int?,
        nombreFinca: c['n'] as String?,
        departamento: (c['d'] as String?) ?? '',
        municipio: (c['m'] as String?) ?? '',
        aldea: c['a'] as String?,
        direccion: c['r'] as String?,
      );

  Map<String, dynamic> toCompact() => {
        if (fincaId != null) 'i': fincaId,
        if (nombreFinca != null && nombreFinca!.isNotEmpty) 'n': nombreFinca,
        if (departamento.isNotEmpty) 'd': departamento,
        if (municipio.isNotEmpty) 'm': municipio,
        if (aldea != null && aldea!.isNotEmpty) 'a': aldea,
        if (direccion != null && direccion!.isNotEmpty) 'r': direccion,
      };

  String get locationLabel {
    final parts = [
      if (municipio.isNotEmpty) municipio,
      if (departamento.isNotEmpty) departamento,
    ];
    return parts.join(', ');
  }
}

/// Ein Produzent aus dem IHCafe-Verzeichnis.
class IhcafeProducer {
  final int? productorId;

  /// IHCafe-interne Kennung, z.B. "04-04-06906".
  final String clave;

  /// Vollständiger DNI im Format "0719-1993-00172".
  final String identidad;

  final String nombreCompleto;
  final bool esVigente;
  final List<IhcafeFinca> fincas;

  const IhcafeProducer({
    this.productorId,
    required this.clave,
    required this.identidad,
    required this.nombreCompleto,
    required this.esVigente,
    required this.fincas,
  });

  factory IhcafeProducer.fromExport(Map<String, dynamic> json) =>
      IhcafeProducer(
        productorId: json['productor_id'] as int?,
        clave: (json['clave'] as String?)?.trim() ?? '',
        identidad: (json['identidad'] as String?)?.trim() ?? '',
        nombreCompleto: (json['nombre_completo'] as String?)?.trim() ?? '',
        esVigente: json['status']?['es_vigente'] == true,
        fincas: ((json['fincas'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(IhcafeFinca.fromExport)
            .toList(),
      );

  factory IhcafeProducer.fromCompact(Map<dynamic, dynamic> c) => IhcafeProducer(
        productorId: c['i'] as int?,
        clave: (c['c'] as String?) ?? '',
        identidad: (c['d'] as String?) ?? '',
        nombreCompleto: (c['n'] as String?) ?? '',
        esVigente: c['v'] == 1,
        fincas: ((c['f'] as List?) ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map(IhcafeFinca.fromCompact)
            .toList(),
      );

  Map<String, dynamic> toCompact() => {
        if (productorId != null) 'i': productorId,
        if (clave.isNotEmpty) 'c': clave,
        if (identidad.isNotEmpty) 'd': identidad,
        'n': nombreCompleto,
        'v': esVigente ? 1 : 0,
        if (fincas.isNotEmpty) 'f': fincas.map((f) => f.toCompact()).toList(),
      };

  /// Alle Municipios dieses Produzenten (über seine Fincas).
  Set<String> get municipios =>
      fincas.map((f) => f.municipio).where((m) => m.isNotEmpty).toSet();

  Set<String> get departamentos =>
      fincas.map((f) => f.departamento).where((d) => d.isNotEmpty).toSet();

  String get locationLabel =>
      fincas.isEmpty ? '' : fincas.first.locationLabel;
}

/// Kopfdaten des importierten Exports.
class IhcafeCatalogMeta {
  final String contract;
  final String proyectoUid;
  final String scopeDepartamento;
  final List<String> scopeMunicipios;
  final String exportedAt;
  final int recordCount;

  /// Zeitpunkt des Imports in die App.
  final String importedAt;

  const IhcafeCatalogMeta({
    required this.contract,
    required this.proyectoUid,
    required this.scopeDepartamento,
    required this.scopeMunicipios,
    required this.exportedAt,
    required this.recordCount,
    required this.importedAt,
  });

  factory IhcafeCatalogMeta.fromMap(Map<dynamic, dynamic> m) =>
      IhcafeCatalogMeta(
        contract: (m['contract'] as String?) ?? '',
        proyectoUid: (m['proyectoUid'] as String?) ?? '',
        scopeDepartamento: (m['scopeDepartamento'] as String?) ?? '',
        scopeMunicipios:
            ((m['scopeMunicipios'] as List?) ?? const []).cast<String>(),
        exportedAt: (m['exportedAt'] as String?) ?? '',
        recordCount: (m['recordCount'] as int?) ?? 0,
        importedAt: (m['importedAt'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {
        'contract': contract,
        'proyectoUid': proyectoUid,
        'scopeDepartamento': scopeDepartamento,
        'scopeMunicipios': scopeMunicipios,
        'exportedAt': exportedAt,
        'recordCount': recordCount,
        'importedAt': importedAt,
      };
}

/// Vergleichsschlüssel für Personennamen: Großschreibung, ohne Akzente, ohne
/// Satzzeichen, Mehrfach-Leerzeichen zusammengefasst.
///
/// Die Quelldaten enthalten doppelte Leerzeichen ("ERWIN ROBERTO  SIERRA
/// GARMENDIA"), daher ist das Zusammenfassen zwingend.
String personNameKey(String raw) {
  const diacritics = {
    'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
    'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
    'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    'Ñ': 'N', 'Ç': 'C',
  };
  final upper = raw.toUpperCase();
  final buffer = StringBuffer();
  for (final ch in upper.split('')) {
    final mapped = diacritics[ch] ?? ch;
    // Alles außer A-Z wird zu einem Trenner - Bindestriche und Punkte in
    // Namen sollen nicht zu unterschiedlichen Schlüsseln führen.
    if (mapped.codeUnitAt(0) >= 65 && mapped.codeUnitAt(0) <= 90) {
      buffer.write(mapped);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).join(' ');
}

/// Der geladene Katalog inklusive Suchindizes.
class IhcafeCatalog {
  final List<IhcafeProducer> producers;
  final IhcafeCatalogMeta meta;

  /// Exakter Namensschlüssel → Produzenten (Namen sind nicht eindeutig!).
  final Map<String, List<IhcafeProducer>> byNameKey;

  /// Namens-Token als Menge → Produzenten, fängt vertauschte Reihenfolge und
  /// unterschiedliche Zweitnamen-Sortierung ab.
  final Map<String, List<IhcafeProducer>> byTokenSet;

  IhcafeCatalog._({
    required this.producers,
    required this.meta,
    required this.byNameKey,
    required this.byTokenSet,
  });

  factory IhcafeCatalog(List<IhcafeProducer> producers, IhcafeCatalogMeta meta) {
    final byName = <String, List<IhcafeProducer>>{};
    final byTokens = <String, List<IhcafeProducer>>{};
    for (final p in producers) {
      final key = personNameKey(p.nombreCompleto);
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(p);
      final tokenKey = (key.split(' ')..sort()).join(' ');
      byTokens.putIfAbsent(tokenKey, () => []).add(p);
    }
    return IhcafeCatalog._(
      producers: producers,
      meta: meta,
      byNameKey: byName,
      byTokenSet: byTokens,
    );
  }

  /// Alle im Katalog vorkommenden Municipios - für die Scope-Warnung.
  Set<String> get municipios {
    final result = <String>{};
    for (final p in producers) {
      result.addAll(p.municipios);
    }
    return result;
  }

  /// Freitextsuche über Name, Identidad und Clave.
  ///
  /// Alle Suchbegriffe müssen vorkommen (UND-Verknüpfung), damit "juan trojes"
  /// sinnvoll filtert. [limit] begrenzt die Trefferliste für die UI.
  List<IhcafeProducer> search(String query, {int limit = 50}) {
    final terms = personNameKey(query).split(' ').where((t) => t.isNotEmpty);
    final digits = query.replaceAll(RegExp(r'[^0-9]'), '');

    if (terms.isEmpty && digits.isEmpty) return const [];

    final result = <IhcafeProducer>[];
    for (final p in producers) {
      final haystack =
          '${personNameKey(p.nombreCompleto)} ${personNameKey(p.locationLabel)}';
      final nameHit = terms.isEmpty || terms.every(haystack.contains);
      final idHit = digits.isNotEmpty &&
          (p.identidad.replaceAll(RegExp(r'[^0-9]'), '').contains(digits) ||
              p.clave.replaceAll(RegExp(r'[^0-9]'), '').contains(digits));

      if ((terms.isNotEmpty && nameHit) || idHit) {
        result.add(p);
        if (result.length >= limit) break;
      }
    }
    return result;
  }
}

/// Zugriff auf den lokal gespeicherten Katalog.
class IhcafeProducerService {
  IhcafeProducerService._();
  static final IhcafeProducerService instance = IhcafeProducerService._();

  Box? _box;
  IhcafeCatalog? _cached;

  Future<Box> _openBox() async {
    _box ??= Hive.isBoxOpen(ihcafeBoxName)
        ? Hive.box(ihcafeBoxName)
        : await Hive.openBox(ihcafeBoxName);
    return _box!;
  }

  /// Ist ein Katalog importiert?
  Future<bool> get isAvailable async {
    final box = await _openBox();
    return box.containsKey(_kDataKey) && box.containsKey(_kMetaKey);
  }

  /// Kopfdaten ohne den Katalog zu laden - für Statusanzeigen.
  Future<IhcafeCatalogMeta?> readMeta() async {
    final box = await _openBox();
    final raw = box.get(_kMetaKey);
    if (raw is Map) return IhcafeCatalogMeta.fromMap(raw);
    return null;
  }

  /// Ungefähre Größe des gespeicherten Katalogs in Bytes.
  Future<int> storedSizeBytes() async {
    final box = await _openBox();
    final raw = box.get(_kDataKey);
    return raw is String ? raw.length : 0;
  }

  /// Lädt den Katalog (mit Cache) oder null, wenn noch nichts importiert wurde.
  Future<IhcafeCatalog?> load() async {
    if (_cached != null) return _cached;

    final box = await _openBox();
    final raw = box.get(_kDataKey);
    final metaRaw = box.get(_kMetaKey);
    if (raw is! String || metaRaw is! Map) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    final producers = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(IhcafeProducer.fromCompact)
        .toList();

    _cached = IhcafeCatalog(producers, IhcafeCatalogMeta.fromMap(metaRaw));
    return _cached;
  }

  /// Importiert einen IHCafe-Export und legt ihn verdichtet ab.
  ///
  /// [exportJson] ist der komplette Dateiinhalt mit den Schlüsseln
  /// success/contract/scope/data. Wirft [FormatException] bei unerwartetem
  /// Aufbau, damit die UI eine verständliche Meldung zeigen kann.
  Future<IhcafeCatalogMeta> importExport(String exportJson) async {
    final dynamic decoded = jsonDecode(exportJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Unerwartetes Format: erwartet wird ein JSON-Objekt.');
    }
    final data = decoded['data'];
    if (data is! List) {
      throw const FormatException(
          'Im Export fehlt die Liste "data" mit den Produzenten.');
    }

    final producers = data
        .whereType<Map<String, dynamic>>()
        .map(IhcafeProducer.fromExport)
        .where((p) => p.nombreCompleto.isNotEmpty)
        .toList();

    if (producers.isEmpty) {
      throw const FormatException('Der Export enthält keine Produzenten.');
    }

    final scope = (decoded['scope'] as Map?) ?? const {};
    final exportInfo = (decoded['export_info'] as Map?) ?? const {};

    final meta = IhcafeCatalogMeta(
      contract: (decoded['contract'] as String?) ?? '',
      proyectoUid: (decoded['proyecto_uid'] as String?) ?? '',
      scopeDepartamento: (scope['departamento'] as String?) ?? '',
      scopeMunicipios:
          ((scope['municipios_cod'] as List?) ?? const []).map((e) => '$e').toList(),
      exportedAt: (exportInfo['exported_at'] as String?) ??
          (decoded['server_time'] as String?) ??
          '',
      recordCount: producers.length,
      importedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final compact =
        jsonEncode(producers.map((p) => p.toCompact()).toList());

    final box = await _openBox();
    await box.put(_kDataKey, compact);
    await box.put(_kMetaKey, meta.toMap());
    _cached = null; // beim nächsten Zugriff frisch aufbauen

    debugPrint('IHCafe catalog imported: ${producers.length} producers, '
        '${(compact.length / 1024 / 1024).toStringAsFixed(1)} MB stored');
    return meta;
  }

  /// Entfernt den Katalog wieder - z.B. wenn das Gerät Platz braucht.
  Future<void> clear() async {
    final box = await _openBox();
    await box.delete(_kDataKey);
    await box.delete(_kMetaKey);
    _cached = null;
  }
}

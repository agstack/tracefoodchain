import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:trace_foodchain_app/models/country_config.dart';
import 'package:trace_foodchain_app/repositories/honduras_specifics.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';

const String countryConfigBoxName = 'countryConfig';
const String countriesCollection = 'TFC_countries';

/// Länder, die die App auch ohne Cloud-Eintrag kennt.
///
/// Honduras lief bereits vor der Länder-Konfiguration produktiv; der Eintrag
/// bildet genau das bisherige Verhalten ab. Ein Dokument gleichen Codes in
/// [countriesCollection] hat immer Vorrang.
final List<CountryConfig> builtInCountries = [
  CountryConfig(
    code: 'HN',
    name: 'Honduras',
    // Registrierungen vor der Länder-Konfiguration speichern den Namen.
    legacyNames: const ['Honduras'],
    areaUnits: areaUnitsHonduras,
    defaultAreaUnit: 'mz',
    regionLabels: const ['Departamento', 'Municipio', 'Aldea'],
    regions: const [
      'Atlántida',
      'Choluteca',
      'Colón',
      'Comayagua',
      'Copán',
      'Cortés',
      'El Paraíso',
      'Francisco Morazán',
      'Gracias a Dios',
      'Intibucá',
      'Islas de la Bahía',
      'La Paz',
      'Lempira',
      'Ocotepeque',
      'Olancho',
      'Santa Bárbara',
      'Valle',
      'Yoro',
    ],
    whispNationalCode: 'hn',
    producerRegistry: CountryConfig.producerRegistryIhcafe,
  ),
];

class CountryConfigOfflineException implements Exception {
  @override
  String toString() => 'Countries can only be changed while online';
}

class CountryConfigPermissionException implements Exception {
  @override
  String toString() => 'Missing permission manage_countries';
}

/// Länder-Konfiguration aus Firestore, mit Kopie in Hive für die Feldarbeit
/// ohne Netz.
///
/// Gelesen wird synchron aus dem Speicher; [refreshFromCloud] holt den Stand
/// der Cloud nach, wann immer eine Verbindung besteht.
class CountryConfigService extends ChangeNotifier {
  CountryConfigService._();
  static final CountryConfigService instance = CountryConfigService._();

  Box<String>? _box;

  /// Was die Cloud zuletzt geliefert hat (bzw. die Kopie davon in Hive).
  Map<String, CountryConfig> _cloud = {};

  /// Eingebaute Länder, überschrieben durch die Cloud.
  Map<String, CountryConfig> _effective = {
    for (final c in builtInCountries) c.code: c,
  };

  Future<Box<String>> _openBox() async {
    final box = _box;
    if (box != null && box.isOpen) return box;
    return _box = Hive.isBoxOpen(countryConfigBoxName)
        ? Hive.box<String>(countryConfigBoxName)
        : await Hive.openBox<String>(countryConfigBoxName);
  }

  /// Lädt die gespeicherte Kopie. Vor dem ersten Zugriff aufrufen.
  Future<void> init() async {
    final box = await _openBox();
    final cached = <String, CountryConfig>{};
    for (final code in box.keys.cast<String>()) {
      try {
        final raw = jsonDecode(box.get(code)!);
        if (raw is Map) cached[code] = CountryConfig.fromMap(code, raw);
      } catch (e) {
        debugPrint('CountryConfig: skipping unreadable cache entry $code: $e');
      }
    }
    _setCloud(cached);
  }

  /// Holt alle Länder vom Server und ersetzt die lokale Kopie.
  ///
  /// Liest ausdrücklich vom Server: aus dem Firestore-Offline-Cache käme
  /// ohne Netz eine leere Liste, und die würde die gute Kopie in Hive löschen.
  /// Gibt false zurück, wenn der Server nicht erreichbar war.
  Future<bool> refreshFromCloud() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(countriesCollection)
          .get(const GetOptions(source: Source.server));

      final fetched = <String, CountryConfig>{};
      for (final doc in snapshot.docs) {
        if (!CountryConfig.isValidCode(doc.id)) continue;
        try {
          fetched[doc.id] = CountryConfig.fromMap(doc.id, doc.data());
        } catch (e) {
          debugPrint('CountryConfig: skipping invalid country ${doc.id}: $e');
        }
      }

      final box = await _openBox();
      await box.clear();
      await box.putAll({
        for (final c in fetched.values) c.code: jsonEncode(c.toMap()),
      });
      _setCloud(fetched);
      return true;
    } catch (e) {
      debugPrint('CountryConfig: refresh from cloud failed: $e');
      return false;
    }
  }

  /// Speichert ein Land in der Cloud (nur mit `manage_countries`).
  Future<void> save(CountryConfig country) async {
    if (!PermissionService().hasPermission('manage_countries')) {
      throw CountryConfigPermissionException();
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw CountryConfigOfflineException();
    }

    final saved = country.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
    );

    await FirebaseFirestore.instance
        .collection(countriesCollection)
        .doc(saved.code)
        .set({
      ...saved.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final box = await _openBox();
    await box.put(saved.code, jsonEncode(saved.toMap()));
    _setCloud({..._cloud, saved.code: saved});
  }

  void _setCloud(Map<String, CountryConfig> cloud) {
    _cloud = cloud;
    _effective = {
      for (final c in builtInCountries) c.code: c,
      ...cloud,
    };
    notifyListeners();
  }

  /// Alle bekannten Länder, nach Namen sortiert.
  List<CountryConfig> get all => _effective.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<CountryConfig> get active => all.where((c) => c.active).toList();

  CountryConfig? byCode(String code) => _effective[code.toUpperCase()];

  /// Land zu einem gespeicherten Wert - Code, Name oder frühere Schreibweise.
  CountryConfig? resolve(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final byIso = byCode(value.trim());
    if (byIso != null) return byIso;
    for (final c in _effective.values) {
      if (c.matches(value)) return c;
    }
    return null;
  }

  /// Eingebautes Land, das noch nie in der Cloud gespeichert wurde.
  bool isBuiltInOnly(String code) =>
      !_cloud.containsKey(code) &&
      builtInCountries.any((c) => c.code == code);
}

final CountryConfigService countryConfigService = CountryConfigService.instance;

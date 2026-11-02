import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trace_foodchain_app/models/country_config.dart';
import 'package:trace_foodchain_app/services/country_config_service.dart';

const _kenya = CountryConfig(
  code: 'KE',
  name: 'Kenya',
  areaUnits: [
    {'name': 'acres', 'symbol': 'ac', 'toHectareFactor': 0.404686},
    {'name': 'hectares', 'symbol': 'ha', 'toHectareFactor': 1.0},
  ],
  defaultAreaUnit: 'ac',
  regionLabels: ['County', 'Sub-County', 'Ward'],
  regions: ['Nyeri', 'Kirinyaga'],
  whispNationalCode: 'ke',
);

void main() {
  group('CountryConfig', () {
    test('survives a round trip through toMap/fromMap', () {
      final copy = CountryConfig.fromMap(
          'KE', jsonDecode(jsonEncode(_kenya.toMap())) as Map);

      expect(copy.toMap(), _kenya.toMap());
    });

    test('reads numbers stored as int or string as factors', () {
      final c = CountryConfig.fromMap('XX', {
        'name': 'X',
        'areaUnits': [
          {'name': 'a', 'symbol': 'a', 'toHectareFactor': 1},
          {'name': 'b', 'symbol': 'b', 'toHectareFactor': '0.5'},
        ],
      });

      expect(c.areaUnits.map((u) => u['toHectareFactor']), [1.0, 0.5]);
    });

    test('unknown producer registry falls back to none', () {
      final c = CountryConfig.fromMap(
          'XX', {'name': 'X', 'producerRegistry': 'somethingElse'});

      expect(c.producerRegistry, CountryConfig.producerRegistryNone);
    });

    test('matches code, name and legacy names case-insensitively', () {
      const c = CountryConfig(
          code: 'HN', name: 'Honduras', legacyNames: ['Rep. de Honduras']);

      expect(c.matches('hn'), isTrue);
      expect(c.matches(' HONDURAS '), isTrue);
      expect(c.matches('rep. de honduras'), isTrue);
      expect(c.matches('NI'), isFalse);
      expect(c.matches(''), isFalse);
      expect(c.storedValues, ['HN', 'Rep. de Honduras']);
    });

    test('accepts only two upper-case letters as code', () {
      expect(CountryConfig.isValidCode('KE'), isTrue);
      expect(CountryConfig.isValidCode('ke'), isFalse);
      expect(CountryConfig.isValidCode('KEN'), isFalse);
    });
  });

  group('CountryConfigService', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('country_config_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('knows Honduras without any cloud data', () async {
      await countryConfigService.init();

      final hn = countryConfigService.resolve('Honduras');
      expect(hn?.code, 'HN');
      expect(countryConfigService.isBuiltInOnly('HN'), isTrue);
      // Bisherige Registrierungen speichern den Namen, nicht den Code.
      expect(hn!.storedValues, containsAll(['HN', 'Honduras']));
      expect(hn.areaUnits.map((u) => u['symbol']), ['ha', 'mz']);
    });

    test('loads the device copy and lets it override built-in countries',
        () async {
      final box = await Hive.openBox<String>(countryConfigBoxName);
      await box.put('KE', jsonEncode(_kenya.toMap()));
      await box.put(
          'HN',
          jsonEncode(builtInCountries.first.copyWith(active: false).toMap()));

      await countryConfigService.init();

      expect(countryConfigService.byCode('ke')?.name, 'Kenya');
      expect(countryConfigService.resolve('KE')?.defaultAreaUnit, 'ac');
      expect(countryConfigService.byCode('HN')?.active, isFalse);
      expect(countryConfigService.isBuiltInOnly('HN'), isFalse);
      expect(countryConfigService.active.map((c) => c.code), ['KE']);
      expect(countryConfigService.all.map((c) => c.code), ['HN', 'KE']);
    });

    test('ignores unreadable cache entries', () async {
      final box = await Hive.openBox<String>(countryConfigBoxName);
      await box.put('KE', 'not json');

      await countryConfigService.init();

      expect(countryConfigService.byCode('KE'), isNull);
      expect(countryConfigService.byCode('HN'), isNotNull);
    });
  });
}

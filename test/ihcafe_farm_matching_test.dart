import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/services/ihcafe_farm_matching.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

IhcafeProducer _p(int id, String name, String dni,
        List<(int, String)> fincas) =>
    IhcafeProducer(
      productorId: id,
      clave: '04-04-${id.toString().padLeft(5, '0')}',
      identidad: dni,
      nombreCompleto: name,
      esVigente: true,
      fincas: [
        for (final (fid, mun) in fincas)
          IhcafeFinca(fincaId: fid, departamento: 'El Paraíso', municipio: mun),
      ],
    );

final _catalog = IhcafeCatalog(
  [
    _p(1, 'ERWIN ROBERTO  SIERRA GARMENDIA', '0719-1993-00172', [(101, 'Trojes')]),
    _p(2, 'MARIA JOSE LOPEZ', '0703-1980-00001', [(201, 'Danlí'), (202, 'Trojes')]),
    _p(3, 'MARIA JOSE LOPEZ', '0703-1981-00002', [(301, 'Danlí')]),
    _p(4, 'JUAN CARLOS PEREZ MEJIA', '0715-1970-00003', [(401, 'Teupasenti')]),
    _p(5, 'PEDRO PABLO MARTINEZ', '0704-1990-00004', [(501, 'El Paraíso')]),
    _p(6, 'ANA LUCIA REYES', '0719-1975-00005', [(601, 'Trojes'), (602, 'Trojes')]),
    _p(7, 'PEDRO MARTINEZ', '0704-1960-00006', [(701, 'El Paraíso')]),
  ],
  const IhcafeCatalogMeta(
    contract: 'c',
    proyectoUid: 'p',
    scopeDepartamento: 'El Paraíso',
    scopeMunicipios: [],
    exportedAt: '2026-11-05',
    recordCount: 6,
    importedAt: '',
  ),
);

FarmToMatch _f(String name,
        {String uid = 'farm1',
        String? farmer = 'farmer1',
        String dni = '',
        String mun = '',
        String aldea = '',
        List<String> farmerIds = const [],
        List<String> farmIds = const []}) =>
    FarmToMatch(
      farmUid: uid,
      farmName: name,
      farmerUid: farmer,
      farmerName: name,
      nationalId: dni,
      municipio: mun,
      aldea: aldea,
      farmerIhcafeIds: farmerIds,
      farmIhcafeIds: farmIds,
    );

void main() {
  final m = IhcafeFarmMatcher(_catalog);

  test('DNI match without dashes, finca in same municipio', () {
    final r = m.matchOne(_f('Erwin Sierra', dni: '0719199300172', mun: 'Trojes'));
    expect(r.level, IhcafeLinkLevel.dni);
    expect(r.producer!.productorId, 1);
    expect(r.farmerAdds.map((a) => a.uid), ['04-04-00001', '1']);
    expect(r.farmAdds.single.uid, '101');
  });

  test('DNI match with a completely different name is flagged', () {
    final r = m.matchOne(_f('Pedro Gomez', dni: '0719-1993-00172'));
    expect(r.level, IhcafeLinkLevel.dniNameMismatch);
    expect(r.isApplicable(defaultApplyLevels), isFalse);
  });

  test('exact name + municipio, accents and spacing ignored', () {
    final r = m.matchOne(_f('Erwin Roberto Sierra Garmendía', mun: 'trojes'));
    expect(r.level, IhcafeLinkLevel.nameMunicipio);
    expect(r.producer!.productorId, 1);
  });

  test('same name twice in municipio is ambiguous', () {
    final r = m.matchOne(_f('Maria Jose Lopez', mun: 'Danli'));
    expect(r.level, IhcafeLinkLevel.ambiguous);
    expect(r.producer, isNull);
  });

  test('municipio disambiguates a duplicate name and picks the finca', () {
    final r = m.matchOne(_f('Maria Jose Lopez', mun: 'Trojes'));
    expect(r.level, IhcafeLinkLevel.nameMunicipio);
    expect(r.producer!.productorId, 2);
    expect(r.finca!.fincaId, 202);
  });

  test('missing second names: fuzzy subset within municipio', () {
    final r = m.matchOne(_f('Juan Perez', mun: 'Teupasenti'));
    expect(r.level, IhcafeLinkLevel.nameFuzzy);
    expect(r.producer!.productorId, 4);
  });

  test('typo in a name part: fuzzy', () {
    final r = m.matchOne(_f('Juan Carlos Peres Mejia', mun: 'Teupasenti'));
    expect(r.level, IhcafeLinkLevel.nameFuzzy);
    expect(r.producer!.productorId, 4);
  });

  test('short exact name with a longer rival is only a similar-name match', () {
    final r = m.matchOne(_f('Pedro Martinez', mun: 'El Paraiso'));
    expect(r.level, IhcafeLinkLevel.nameFuzzy);
    expect(r.producer!.productorId, 7);
    expect(r.candidates.map((c) => c.productorId), [5]);
    expect(r.isApplicable(defaultApplyLevels), isFalse);
  });

  test('a shorter name does not challenge an exact full name', () {
    final r = m.matchOne(_f('Pedro Pablo Martinez', mun: 'El Paraiso'));
    expect(r.level, IhcafeLinkLevel.nameMunicipio);
    expect(r.producer!.productorId, 5);
  });

  test('name hit contradicting the farmer DNI is a conflict', () {
    final r = m.matchOne(
        _f('Juan Carlos Perez Mejia', mun: 'Teupasenti', dni: '0801199912345'));
    expect(r.level, IhcafeLinkLevel.conflict);
  });

  test('municipio outside the export', () {
    final r = m.matchOne(_f('Somebody Else', mun: 'Tegucigalpa'));
    expect(r.level, IhcafeLinkLevel.outOfScope);
  });

  test('two fincas in the same municipio: farmer linked, finca not set', () {
    final r = m.matchOne(_f('Ana Lucia Reyes', mun: 'Trojes'));
    expect(r.level, IhcafeLinkLevel.nameMunicipio);
    expect(r.farmerAdds, hasLength(2));
    expect(r.farmAdds, isEmpty);
  });

  test('already linked farmer only gets the finca', () {
    final r = m.matchOne(_f('Erwin Sierra',
        mun: 'Trojes', farmerIds: ['04-04-00001', '1']));
    expect(r.level, IhcafeLinkLevel.alreadyLinked);
    expect(r.farmerAdds, isEmpty);
    expect(r.farmAdds.single.uid, '101');
  });

  test('same producer for two different farmers is a duplicate', () {
    final results = m.matchAll([
      _f('Pedro Pablo Martinez', uid: 'a', farmer: 'x', mun: 'El Paraiso'),
      _f('Pedro Pablo Martinez', uid: 'b', farmer: 'y', mun: 'El Paraiso'),
    ]);
    expect(results.map((r) => r.level),
        everyElement(IhcafeLinkLevel.duplicate));
    expect(results.every((r) => !r.isApplicable(applicableLevels)), isTrue);
  });

  test('two farms of the same farmer are no duplicate, finca only once', () {
    final results = m.matchAll([
      _f('Pedro Pablo Martinez', uid: 'a', mun: 'El Paraiso'),
      _f('Pedro Pablo Martinez', uid: 'b', mun: 'El Paraiso'),
    ]);
    expect(results.map((r) => r.level),
        everyElement(IhcafeLinkLevel.nameMunicipio));
    expect(results.every((r) => r.farmAdds.isEmpty), isTrue);
  });

  test('parses the bulk export with envelope', () {
    final json = jsonEncode({
      'endpoint': 'productores',
      'exported_at': '2026-11-05T08:34:58Z',
      'envelope': {
        'contract': 'ciat-poligonos-paraiso-v1',
        'proyecto_uid': 'ciat-el-paraiso',
        'scope': {
          'departamento': 'El Paraíso',
          'municipios_cod': ['0703']
        },
      },
      'data': [
        {
          'productor_id': 7,
          'clave': '04-04-06906',
          'identidad': '0719-1993-00172',
          'nombre_completo': 'ERWIN ROBERTO  SIERRA GARMENDIA',
          'status': {'es_vigente': false},
          'fincas': [
            {
              'finca_id': 256194,
              'departamento': {'nombre': 'El Paraíso'},
              'municipio': {'nombre': 'Trojes'},
            }
          ],
        }
      ],
    });
    final parsed = parseIhcafeExport(json);
    expect(parsed.producers.single.fincas.single.fincaId, 256194);
    expect(parsed.meta.contract, 'ciat-poligonos-paraiso-v1');
    expect(parsed.meta.scopeDepartamento, 'El Paraíso');
    expect(parsed.meta.exportedAt, startsWith('2026-11-05'));
  });

  test('rejects the fincas export', () {
    final json = jsonEncode({
      'endpoint': 'fincas',
      'data': [
        {'finca_id': 1, 'productor': {}}
      ],
    });
    expect(() => parseIhcafeExport(json), throwsFormatException);
  });
}

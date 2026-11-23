import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/services/ihcafe_farm_matching.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

IhcafeProducer _p(int id, String name, String dni,
        List<(int, String)> fincas) =>
    IhcafeProducer(
      productorId: id,
      clave: '99-99-${id.toString().padLeft(5, '0')}',
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
    _p(1, 'TOMAS EFRAIN  PRUEBA FICTICIO', '9999-1993-00172', [(101, 'Trojes')]),
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
    final r = m.matchOne(_f('Tomas Prueba', dni: '9999199300172', mun: 'Trojes'));
    expect(r.level, IhcafeLinkLevel.dni);
    expect(r.producer!.productorId, 1);
    expect(r.farmerAdds.map((a) => a.uid), ['99-99-00001', '1']);
    expect(r.farmAdds.single.uid, '101');
  });

  test('DNI match with a completely different name is flagged', () {
    final r = m.matchOne(_f('Pedro Gomez', dni: '9999-1993-00172'));
    expect(r.level, IhcafeLinkLevel.dniNameMismatch);
    expect(r.isApplicable(defaultApplyLevels), isFalse);
  });

  test('exact name + municipio, accents and spacing ignored', () {
    final r = m.matchOne(_f('Tomás Efraín Prueba Fictício', mun: 'trojes'));
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
    final r = m.matchOne(_f('Tomas Prueba',
        mun: 'Trojes', farmerIds: ['99-99-00001', '1']));
    expect(r.level, IhcafeLinkLevel.alreadyLinked);
    expect(r.farmerAdds, isEmpty);
    expect(r.farmAdds.single.uid, '101');
  });

  test('new alternateIDs carry idName, never the DNI', () {
    final r = m.matchOne(_f('Tomas Prueba', dni: '9999199300172', mun: 'Trojes'));
    expect(r.farmerAdds.map((a) => a.toJson()), [
      {'UID': '99-99-00001', 'issuedBy': 'IHCafe', 'idName': 'clave'},
      {'UID': '1', 'issuedBy': 'IHCafe', 'idName': 'productor_id'},
    ]);
    expect(r.farmAdds.single.toJson(),
        {'UID': '101', 'issuedBy': 'IHCafe', 'idName': 'finca_id'});
  });

  test('existing IHCafe ids without idName get it backfilled', () {
    final r = m.matchOne(const FarmToMatch(
      farmUid: 'farm1',
      farmName: 'Tomas Prueba',
      farmerUid: 'farmer1',
      farmerName: 'Tomas Prueba',
      municipio: 'Trojes',
      farmerIhcafeIds: ['99-99-00001', '1'],
      farmerIhcafeIdsWithoutName: ['1'],
      farmIhcafeIds: ['101'],
      farmIhcafeIdsWithoutName: ['101'],
    ));
    expect(r.level, IhcafeLinkLevel.alreadyLinked);
    final farmerAdd = r.farmerAdds.single;
    expect((farmerAdd.uid, farmerAdd.label, farmerAdd.onlyName),
        ('1', 'productor_id', true));
    final farmAdd = r.farmAdds.single;
    expect((farmAdd.uid, farmAdd.label, farmAdd.onlyName),
        ('101', 'finca_id', true));
    expect(r.isApplicable(defaultApplyLevels), isTrue);
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

  group('finca name', () {
    IhcafeProducer p(int id, String name, List<(int, String, String?, String?)> fs) =>
        IhcafeProducer(
          productorId: id,
          clave: 'c$id',
          identidad: '',
          nombreCompleto: name,
          esVigente: true,
          fincas: [
            for (final (fid, mun, nombre, aldea) in fs)
              IhcafeFinca(
                  fincaId: fid,
                  nombreFinca: nombre,
                  departamento: 'El Paraíso',
                  municipio: mun,
                  aldea: aldea),
          ],
        );

    final fm = IhcafeFarmMatcher(IhcafeCatalog(
      [
        p(1, 'JOSE LUIS CRUZ', [(11, 'Danlí', 'LA BENDICION DANLI', null)]),
        p(2, 'JOSE LUIS CRUZ', [(21, 'Danlí', 'EL GUANO DANLI', null)]),
        p(3, 'ROSA MEJIA', [(31, 'Trojes', 'LA BENDICION', null)]),
        p(4, 'ROSA MEJIA', [(41, 'Trojes', 'FINCA LA BENDICION', null)]),
        p(5, 'LUIS ORTEZ', [
          (51, 'Trojes', 'LOS PLANES TROJES', null),
          (52, 'Trojes', 'LAS VEGAS DE VERACRUZ TROJES', null),
        ]),
        p(6, 'MARTA PAZ', [(61, 'Danlí', 'N/I', null)]),
        p(7, 'MARTA PAZ', [(71, 'Danlí', 'N/I', null)]),
      ],
      const IhcafeCatalogMeta(
        contract: 'c',
        proyectoUid: 'p',
        scopeDepartamento: 'El Paraíso',
        scopeMunicipios: [],
        exportedAt: '2026-11-05',
        recordCount: 7,
        importedAt: '',
      ),
    ));

    FarmToMatch farm(String farmer, String farmName,
            {String mun = '', String aldea = ''}) =>
        FarmToMatch(
          farmUid: 'farm',
          farmName: farmName,
          farmerUid: 'farmer',
          farmerName: farmer,
          municipio: mun,
          aldea: aldea,
        );

    test('farm name decides between two producers of the same name', () {
      final r = fm.matchOne(farm('Jose Luis Cruz', 'Finca La Bendición', mun: 'Danli'));
      expect(r.level, IhcafeLinkLevel.nameFinca);
      expect(r.producer!.productorId, 1);
      expect(r.farmAdds.single.uid, '11');
      expect(r.isApplicable(defaultApplyLevels), isFalse);
      expect(r.isApplicable(applicableLevels), isTrue);
    });

    test('farm aldea inside the finca name decides as well', () {
      final r = fm.matchOne(farm('Jose Luis Cruz', 'Jose Luis Cruz',
          mun: 'Danli', aldea: 'El Guano'));
      expect(r.level, IhcafeLinkLevel.nameFinca);
      expect(r.producer!.productorId, 2);
    });

    test('same finca name at both candidates stays ambiguous', () {
      final r = fm.matchOne(farm('Rosa Mejia', 'La Bendicion', mun: 'Trojes'));
      expect(r.level, IhcafeLinkLevel.ambiguous);
    });

    test('farm named like the farmer and N/I fincas give no evidence', () {
      expect(fm.matchOne(farm('Jose Luis Cruz', 'Jose Luis Cruz', mun: 'Danli')).level,
          IhcafeLinkLevel.ambiguous);
      expect(fm.matchOne(farm('Marta Paz', 'N/I', mun: 'Danli')).level,
          IhcafeLinkLevel.ambiguous);
    });

    test('finca name picks one of several fincas of the producer', () {
      final r = fm.matchOne(farm('Luis Ortez', 'Luis Ortez',
          mun: 'Trojes', aldea: 'Las Vegas de Veracruz'));
      expect(r.level, IhcafeLinkLevel.nameMunicipio);
      expect(r.farmAdds.single.uid, '52');
    });
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
          'clave': '99-99-00007',
          'identidad': '9999-1993-00172',
          'nombre_completo': 'TOMAS EFRAIN  PRUEBA FICTICIO',
          'status': {'es_vigente': false},
          'fincas': [
            {
              'finca_id': 900001,
              'departamento': {'nombre': 'El Paraíso'},
              'municipio': {'nombre': 'Trojes'},
            }
          ],
        }
      ],
    });
    final parsed = parseIhcafeExport(json);
    expect(parsed.producers.single.fincas.single.fincaId, 900001);
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

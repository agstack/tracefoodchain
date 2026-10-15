import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/field_trust.dart';

Map<String, dynamic> _field({
  String objectState = 'active',
  bool polygon = true,
  bool pseudo = false,
  bool geoId = true,
  bool signedQc = true,
}) {
  return {
    'objectState': objectState,
    'identity': {
      'UID': 'field-1',
      'alternateIDs': [
        if (geoId) {'UID': 'geo-1', 'issuedBy': 'Asset Registry'},
      ],
    },
    'currentGeolocation': {
      'container': {'UID': 'farm-1'},
    },
    'specificProperties': [
      if (polygon)
        {
          'key': 'boundaries',
          'value': jsonEncode({
            'type': 'Polygon',
            'coordinates': [
              [
                [0, 0],
                [0, 1],
                [1, 1],
                [0, 0],
              ]
            ],
          }),
        },
      {'key': 'area', 'value': 1.5},
      if (pseudo)
        {
          'key': 'boundarySource',
          'value': 'pseudoPolygonFromCentroid (excel import)',
        },
    ],
    'methodHistoryRef': [
      if (signedQc) {'UID': 'm-1', 'RALType': 'performQualityControl'},
    ],
    'linkedObjectRef': [],
  };
}

void main() {
  const farm = {'identity': {'UID': 'farm-1'}};
  const farmer = {'identity': {'UID': 'farmer-1'}};

  test('approved, surveyed, GeoID, farm and farmer is high', () {
    final trust = assessFieldTrust(_field(), farm: farm, farmer: farmer);
    expect(trust.level, FieldTrustLevel.high);
    expect(trust.has(FieldTrustCriterion.photo), isFalse);
  });

  test('missing farmer drops an approved field to medium', () {
    final trust = assessFieldTrust(_field(), farm: farm);
    expect(trust.level, FieldTrustLevel.medium);
  });

  test('pseudo polygon from the excel import is not high', () {
    final trust =
        assessFieldTrust(_field(pseudo: true), farm: farm, farmer: farmer);
    expect(trust.has(FieldTrustCriterion.polygon), isTrue);
    expect(trust.has(FieldTrustCriterion.surveyedPolygon), isFalse);
    expect(trust.level, FieldTrustLevel.medium);
  });

  test('not approved or without polygon is low', () {
    expect(
        assessFieldTrust(_field(objectState: 'undefined'),
                farm: farm, farmer: farmer)
            .level,
        FieldTrustLevel.low);
    expect(
        assessFieldTrust(_field(polygon: false), farm: farm, farmer: farmer)
            .level,
        FieldTrustLevel.low);
  });

  test('farm is resolved from container or farm link', () {
    expect(farmUidOfField(_field()), 'farm-1');
    expect(
        farmUidOfField({
          'currentGeolocation': {
            'container': {'UID': 'unknown'}
          },
          'linkedObjectRef': [
            {'UID': 'farm-2', 'RALType': 'farm', 'role': 'location'}
          ],
        }),
        'farm-2');
    expect(
        ownerUidOfFarm({
          'linkedObjectRef': [
            {'UID': 'u-1', 'role': 'registrar'},
            {'UID': 'farmer-1', 'role': 'owner'},
          ],
        }),
        'farmer-1');
  });
}

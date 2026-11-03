import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/object_diff.dart';

Map<String, dynamic> _farmer({
  String firstName = 'Juan',
  String lastName = 'Gómez',
  String dni = '0801-1990-12345',
}) =>
    {
      'identity': {
        'UID': 'f1',
        'name': '$firstName $lastName',
        'alternateIDs': [
          {'issuedBy': 'National ID', 'UID': dni},
          {'issuedBy': 'IHCafe', 'UID': 'A'},
        ],
      },
      'specificProperties': [
        {'key': 'firstName', 'value': firstName, 'unit': 'String'},
        {'key': 'lastName', 'value': lastName, 'unit': 'String'},
      ],
      'linkedObjectRef': [
        {'UID': 'img1', 'RALType': 'image', 'role': 'nationalIDPhoto'},
      ],
      'methodHistoryRef': [
        {'UID': 'm1'}
      ],
      'needsSync': false,
    };

void main() {
  group('diffObjectVersions', () {
    test('identical versions have no changes', () {
      expect(diffObjectVersions(_farmer(), _farmer()), isEmpty);
    });

    test('name correction lists name and specific property by key', () {
      final changes =
          diffObjectVersions(_farmer(), _farmer(lastName: 'Gomes'));
      expect(changes, [
        {
          'path': r'$.identity.name',
          'oldValue': 'Juan Gómez',
          'newValue': 'Juan Gomes',
        },
        {
          'path': r"$.specificProperties[?(@.key=='lastName')].value",
          'oldValue': 'Gómez',
          'newValue': 'Gomes',
        },
      ]);
    });

    test('DNI change is addressed by issuer', () {
      final changes =
          diffObjectVersions(_farmer(), _farmer(dni: '0801-1990-12346'));
      expect(changes.single['path'],
          r"$.identity.alternateIDs[?(@.issuedBy=='National ID')].UID");
    });

    test('replaced photo shows the new image reference', () {
      final newer = _farmer();
      (newer['linkedObjectRef'] as List).first['UID'] = 'img2';
      final changes = diffObjectVersions(_farmer(), newer);
      expect(changes.single, {
        'path': r"$.linkedObjectRef[?(@.role=='nationalIDPhoto')].UID",
        'oldValue': 'img1',
        'newValue': 'img2',
      });
    });

    test('added photo appears with null as old value', () {
      final older = _farmer()..['linkedObjectRef'] = <dynamic>[];
      final changes = diffObjectVersions(older, _farmer());
      expect(changes.single['oldValue'], isNull);
      expect(changes.single['newValue'],
          {'UID': 'img1', 'RALType': 'image', 'role': 'nationalIDPhoto'});
    });

    test('bookkeeping keys are ignored', () {
      final newer = _farmer()
        ..['needsSync'] = true
        ..['methodHistoryRef'] = [
          {'UID': 'm1'},
          {'UID': 'm2'}
        ];
      expect(diffObjectVersions(_farmer(), newer), isEmpty);
    });

    test('mixed key/name specific properties stay addressable', () {
      Map<String, dynamic> field(double area) => {
            'specificProperties': [
              {'name': 'area', 'value': area, 'unit': 'ha'},
              {'key': 'boundaryEditNotes', 'value': 'x', 'unit': 'String'},
            ],
          };
      final changes = diffObjectVersions(field(1.0), field(1.5));
      expect(changes.single['path'],
          r"$.specificProperties[?(@.name=='area')].value");
    });

    test('int and double of the same value are equal', () {
      expect(diffObjectVersions({'a': 2}, {'a': 2.0}), isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/models/user_scope.dart';

const _kenya = ScopeEntry(country: 'KE');
const _nyeri = ScopeEntry(country: 'KE', regions: ['Nyeri']);
const _nyeriKirinyaga =
    ScopeEntry(country: 'KE', regions: ['Nyeri', 'Kirinyaga']);
const _kirinyaga = ScopeEntry(country: 'KE', regions: ['Kirinyaga']);
const _honduras = ScopeEntry(country: 'HN');

Map<String, dynamic> _user({List<dynamic>? scope, String country = ''}) => {
      'currentGeolocation': {
        'postalAddress': {'country': country},
      },
      'specificProperties': [
        if (scope != null)
          {'key': UserScope.propertyKey, 'value': scope, 'unit': 'json'},
      ],
    };

String? _resolve(String? stored) => switch (stored) {
      'Honduras' || 'HN' => 'HN',
      'KE' => 'KE',
      _ => null,
    };

void main() {
  group('ScopeEntry', () {
    test('a whole country covers each of its regions', () {
      expect(_kenya.covers(_nyeri), isTrue);
      expect(_nyeri.covers(_kenya), isFalse);
    });

    test('regions cover only subsets of themselves', () {
      expect(_nyeriKirinyaga.covers(_nyeri), isTrue);
      expect(_nyeri.covers(_nyeriKirinyaga), isFalse);
      expect(_nyeri.covers(_kirinyaga), isFalse);
    });

    test('other countries are neither covered nor overlapping', () {
      expect(_kenya.covers(_honduras), isFalse);
      expect(_kenya.overlaps(_honduras), isFalse);
    });

    test('overlaps when regions intersect or one side is the whole country',
        () {
      expect(_nyeriKirinyaga.overlaps(_kirinyaga), isTrue);
      expect(_nyeri.overlaps(_kirinyaga), isFalse);
      expect(_kenya.overlaps(_kirinyaga), isTrue);
    });
  });

  group('UserScope', () {
    test('covers needs every entry of the other scope', () {
      const coordinator = UserScope([_nyeriKirinyaga, _honduras]);

      expect(coordinator.covers(const UserScope([_nyeri, _honduras])), isTrue);
      expect(coordinator.covers(const UserScope([_kenya])), isFalse);
      expect(coordinator.covers(UserScope.empty), isTrue);
    });

    test('round trip through json, one entry per country', () {
      final scope = UserScope.fromJson([
        {
          'country': 'ke',
          'regions': ['Nyeri', ' Nyeri ', '']
        },
        {'country': 'HN'},
        {
          'country': 'KE',
          'regions': ['Kirinyaga']
        },
        'garbage',
      ]);

      // Der letzte Eintrag je Land gilt.
      expect(scope, const UserScope([_kirinyaga, _honduras]));
      expect(UserScope.fromJson(scope.toJson()), scope);
    });

    test('equality ignores order', () {
      expect(
          const UserScope([_nyeriKirinyaga, _honduras]),
          const UserScope([
            _honduras,
            ScopeEntry(country: 'KE', regions: ['Kirinyaga', 'Nyeri'])
          ]));
    });

    test('label lists countries and their regions', () {
      expect(const UserScope([_nyeriKirinyaga, _honduras]).label,
          'KE: Nyeri, Kirinyaga · HN');
    });
  });

  group('UserScope.ofUser', () {
    test('uses the assigned scope when there is one', () {
      final user = _user(country: 'Honduras', scope: [
        {
          'country': 'KE',
          'regions': ['Nyeri']
        }
      ]);

      expect(UserScope.ofUser(user, resolveCountry: _resolve),
          const UserScope([_nyeri]));
      expect(UserScope.isAssigned(user), isTrue);
    });

    test('falls back to the country of the address, legacy names included', () {
      final user = _user(country: 'Honduras');

      expect(UserScope.ofUser(user, resolveCountry: _resolve),
          const UserScope([_honduras]));
      expect(UserScope.isAssigned(user), isFalse);
    });

    test('is empty for an unknown country', () {
      expect(
          UserScope.ofUser(_user(country: 'Atlantis'), resolveCountry: _resolve)
              .isEmpty,
          isTrue);
    });

    test('reads the coordinator of a registrar', () {
      final user = _user()
        ..['specificProperties'].add(
            {'key': UserScope.coordinatorKey, 'value': 'c1', 'unit': 'String'});

      expect(UserScope.coordinatorOf(user), 'c1');
      expect(UserScope.coordinatorOf(_user()), '');
    });
  });
}

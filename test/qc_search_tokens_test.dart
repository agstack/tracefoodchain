import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/qc_search_tokens.dart';

void main() {
  group('foldForSearch', () {
    test('drops accents and case like the cloud function', () {
      expect(foldForSearch('  Ñandú  Pérez '), 'nandu perez');
      expect(foldForSearch('Copán'), 'copan');
      expect(foldForSearch('Gómez'), 'gomez');
    });
  });

  group('qcQueryTokens', () {
    test('splits words and ignores single characters', () {
      expect(qcQueryTokens('Juan G. Gómez'), ['juan', 'gomez']);
    });

    test('splits IDs at separators', () {
      expect(qcQueryTokens('0801-1990-12345'), ['0801', '1990', '12345']);
    });

    test('a full UID is searched as one truncated token', () {
      expect(qcQueryTokens('6f1c2a9e-4b7d-4e2a-9c1b-2f3e4d5a6b7c'),
          ['6f1c2a9e4b7d4e2a9c1b']);
    });

    test('long words are truncated to the indexed length', () {
      expect(qcQueryTokens('abcdefghijklmnopqrstuvwxyz').single,
          'abcdefghijklmnopqrst');
    });

    test('empty input has no tokens', () {
      expect(qcQueryTokens('  a  '), isEmpty);
      expect(qcServerToken(const []), isNull);
    });
  });

  test('the longest token goes to the server', () {
    expect(qcServerToken(['juan', 'gomez', 'go']), 'gomez');
  });

  test('all tokens must be present', () {
    final index = {'ju', 'jua', 'juan', 'go', 'gom', 'gome', 'gomez'};
    expect(qcTokensMatch(index, ['juan', 'gome']), isTrue);
    expect(qcTokensMatch(index, ['juan', 'perez']), isFalse);
  });
}

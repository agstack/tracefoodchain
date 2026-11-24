import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/national_id.dart';

void main() {
  group('checkHondurasId', () {
    test('accepts 13 digits, ignoring hyphens and spaces', () {
      expect(checkHondurasId('0801-1990-12345'), NationalIdFormat.ok);
      expect(checkHondurasId('0801 1990 12345'), NationalIdFormat.ok);
      expect(checkHondurasId('0801199012345'), NationalIdFormat.ok);
    });

    test('rejects missing and wrong length', () {
      expect(checkHondurasId(''), NationalIdFormat.missing);
      expect(checkHondurasId('080119901234'), NationalIdFormat.wrongLength);
      expect(checkHondurasId('08011990123456'), NationalIdFormat.wrongLength);
    });

    test('flags implausible department, municipality or year', () {
      expect(checkHondurasId('1901199012345'), NationalIdFormat.implausible);
      expect(checkHondurasId('0829199012345'), NationalIdFormat.implausible);
      expect(checkHondurasId('0801180012345'), NationalIdFormat.implausible);
    });
  });

  test('findIdCandidates reads printed numbers from OCR text', () {
    const text = 'REPUBLICA DE HONDURAS\nDNI 0801 1990 12345\nNOMBRE JOSE';
    expect(findIdCandidates(text), ['0801199012345']);
    expect(findIdCandidates('no number here 12345'), isEmpty);
  });

  test('nameTokens folds accents and case', () {
    expect(nameTokens('José María Peña-López'),
        ['JOSE', 'MARIA', 'PEÑA', 'LOPEZ']);
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/utc_time.dart';

void main() {
  group('toUtcIso', () {
    test('writes UTC with Z, to the second', () {
      final t = DateTime.utc(2026, 11, 24, 17, 4, 51, 123);
      expect(toUtcIso(t), '2026-11-24T17:04:51Z');
    });

    test('converts local time to UTC', () {
      final local = DateTime(2026, 11, 24, 11, 4, 51);
      final expected = local.toUtc();
      expect(DateTime.parse(toUtcIso(local)), expected);
    });

    test('utcNowIso ends with Z and parses as UTC', () {
      final parsed = DateTime.parse(utcNowIso());
      expect(parsed.isUtc, isTrue);
      expect(DateTime.now().toUtc().difference(parsed).inSeconds.abs(),
          lessThan(5));
    });
  });

  group('parseStoredTime', () {
    test('UTC text becomes the same instant in local time', () {
      final parsed = parseStoredTime('2026-11-24T17:04:51Z')!;
      expect(parsed.isUtc, isFalse);
      expect(
          parsed.isAtSameMomentAs(DateTime.utc(2026, 11, 24, 17, 4, 51)), isTrue);
    });

    test('legacy text without zone is read as local time', () {
      final parsed = parseStoredTime('2026-11-24T11:04:51')!;
      expect(parsed, DateTime(2026, 11, 24, 11, 4, 51));
    });

    test('DateTime and Timestamp are accepted', () {
      final instant = DateTime.utc(2026, 11, 24, 17, 4, 51);
      expect(parseStoredTime(instant)!.isAtSameMomentAs(instant), isTrue);
      expect(
          parseStoredTime(Timestamp.fromDate(instant))!
              .isAtSameMomentAs(instant),
          isTrue);
    });

    test('empty and invalid values give null', () {
      expect(parseStoredTime(null), isNull);
      expect(parseStoredTime(''), isNull);
      expect(parseStoredTime('not a date'), isNull);
    });
  });
}

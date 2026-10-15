import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:trace_foodchain_app/helpers/json_full_double_to_int.dart';
import 'package:trace_foodchain_app/helpers/sort_json_alphabetically.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';

/// The implementation before the single-pass rewrite. The hashes are compared
/// against the hash tables of the cloud, so the new one must produce exactly
/// the same result.
String legacyGenerateStableHash(Map<String, dynamic> docData) {
  Map<String, dynamic> valueMap = deepCopyMap(docData);
  valueMap = convertToJson(valueMap);
  valueMap = jsonFullDoubleToInt(valueMap);
  valueMap = sortJsonAlphabetically(valueMap);
  final jsonString = jsonEncode(valueMap);
  return sha256.convert(utf8.encode(jsonString)).toString();
}

Map<String, dynamic> _field(int i, {int points = 200}) => {
      "identity": {"UID": "field-$i", "name": "Feld $i – Café ñ"},
      "methodHistoryRef": [
        {"UID": "m-$i", "RALType": "generateDigitalSibling"}
      ],
      "currentOwners": [
        {"UID": "owner-$i", "role": "owner"}
      ],
      "template": {"RALType": "field", "version": "1.0"},
      "specificProperties": [
        {"key": "area", "value": 1000.0, "unit": "m²"},
        {"key": "ratio", "value": 0.25},
        {"key": "count", "value": 3},
        {"key": "label", "value": "1000.0"},
        {"key": "flag", "value": true},
        {"key": "empty", "value": null},
      ],
      "currentGeolocation": {
        "geoCoordinates": {"latitude": 14.0, "longitude": -90.5},
        "polygon": [
          for (int p = 0; p < points; p++) [14.0 + p / 1000, -90.0 - p / 3]
        ],
      },
      "zeta": {
        "b": {
          "y": [
            {"z": 2.0, "a": "x"},
            [1.0, 2.5, {"k": 3.0}]
          ],
          "a": 1
        },
        "a": -0.0,
      },
    };

void main() {
  group('generateStableHash', () {
    test('matches the previous implementation', () {
      final docs = <Map<String, dynamic>>[
        {},
        {"identity": {"UID": "x"}},
        _field(1),
        _field(2, points: 0),
        // Method that embeds its objects (as stored by the app)
        {
          "identity": {"UID": "method-1"},
          "template": {"RALType": "changeOwner"},
          "executor": _field(9, points: 3),
          "inputObjects": [_field(3, points: 5)],
          "outputObjects": [_field(4, points: 5), _field(5, points: 5)],
          "digitalSignatures": [
            {"signature": "abc==", "signerUID": "u1", "signedContent": [r"$"]}
          ],
        },
        // Hive returns nested maps as Map<dynamic, dynamic>
        {
          "identity": <dynamic, dynamic>{"UID": "hive", "name": "n"},
          "list": <dynamic>[
            <dynamic, dynamic>{"b": 1.0, "a": 2}
          ],
        },
        // DateTime is converted by convertToJson
        {
          "identity": {"UID": "date"},
          "existenceStarts": DateTime.utc(2026, 10, 15, 10, 23, 38, 149),
          "nested": {"when": DateTime.utc(2025, 1, 2, 3, 4, 5)},
        },
      ];

      for (final doc in docs) {
        expect(generateStableHash(doc), legacyGenerateStableHash(doc),
            reason: jsonEncode(convertToJson(doc)));
      }
    });

    test('is faster than the previous implementation', () {
      final docs = [
        for (int i = 0; i < 300; i++)
          {
            "identity": {"UID": "method-$i"},
            "outputObjects": [_field(i), _field(i + 1000)],
          }
      ];

      final legacyWatch = Stopwatch()..start();
      final legacyHashes = docs.map(legacyGenerateStableHash).toList();
      legacyWatch.stop();

      final newWatch = Stopwatch()..start();
      final newHashes = docs.map(generateStableHash).toList();
      newWatch.stop();

      // ignore: avoid_print
      print('300 docs: legacy ${legacyWatch.elapsedMilliseconds} ms,'
          ' new ${newWatch.elapsedMilliseconds} ms');
      expect(newHashes, legacyHashes);
      expect(newWatch.elapsedMilliseconds,
          lessThan(legacyWatch.elapsedMilliseconds));
    });
  });
}

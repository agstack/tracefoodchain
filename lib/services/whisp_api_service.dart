import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WhispApiService {
  static const String _geoJsonProxyUrl =
      'https://europe-west3-tracefoodchain.cloudfunctions.net/checkWhispGeoJson';
  static const String _wktProxyUrl =
      'https://europe-west3-tracefoodchain.cloudfunctions.net/checkWhispWkt';

  /// Name of the feature property used to identify a plot across the API call.
  /// WHISP echoes it back as "external_id" on each result feature when it is
  /// passed as "externalIdColumn" in the analysis options.
  static const String externalIdProperty = 'external_id';

  Future<Map<String, dynamic>> checkWhispGeoJson(
      List<Map<String, dynamic>> features) async {
    if (features.isEmpty) {
      throw ArgumentError('Features list cannot be empty');
    }

    final response = await http
        .post(
          Uri.parse(_geoJsonProxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': 'FeatureCollection',
            'features': features,
            'analysisOptions': {
              'unitType': 'ha',
              'nationalCodes': ['hn', 'ke', 'de'],
              'externalIdColumn': externalIdProperty,
            },
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      debugPrint('WHISP GeoJSON proxy response: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint(
          'WHISP GeoJSON proxy error: ${response.statusCode} - ${response.body}');
      throw Exception('WHISP error ${response.statusCode}: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> checkWhispWkt(String wkt) async {
    if (wkt.isEmpty) {
      throw ArgumentError('WKT string cannot be empty');
    }

    final response = await http
        .post(
          Uri.parse(_wktProxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'wkt': wkt,
            'analysisOptions': {
              'unitType': 'ha',
            },
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      debugPrint('WHISP WKT proxy response: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('WHISP error ${response.statusCode}: ${response.body}');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/models/whisp_result_model.dart';

class WhispApiService {
  final String baseUrl;
  final String apiKey;

  WhispApiService({required this.baseUrl, required this.apiKey}) {
    assert(baseUrl.startsWith('https://'), 'API URL must use HTTPS');
    assert(apiKey.isNotEmpty, 'API key cannot be empty');
  }

  Future<Map<String,dynamic>> analyzeGeoIds(List<String> geoIds) async {
    // Input validation
    if (geoIds.isEmpty) {
      throw ArgumentError('Geo IDs list cannot be empty');
    }

    // geoIds = ["ea5b12fc6d5fe9d89af141874de4f51cde6a7312090860a19c4ea8d1db6d4315"];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/submit/geo-ids'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({'geoIds': geoIds}),
      );

      if (response.statusCode == 200) {
        
        return  jsonDecode(response.body);
      } else {
        throw Exception(
            'API request failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Log the error
      
      throw Exception('An error occurred while analyzing Geo IDs');
    }
  }

  //ToDo Similar updates for analyzeGeoJson and analyzeWkt methods...
}

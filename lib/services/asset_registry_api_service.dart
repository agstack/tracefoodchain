/// Asset Registry Service
/// ------------------------------------------------------------
/// A Dart service for interacting with the AgStack Asset Registry
/// based on the provided OpenAPI structure: https://agstack.github.io/agstack-website/apis/asset_registry.json
///
/// Dependencies:
///   flutter pub add http
///   flutter pub add crypto
///
/// Copyright 2025, Apache-2.0

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'user_registry_api_service.dart';

/// {@template asset_registry_service}
/// A service that encapsulates all important endpoints of the AgStack Asset Registry.
/// {@endtemplate}
class AssetRegistryService {
  /// Base URL (Default: Production server)
  final Uri _baseUri;

  /// Public access key (accessKey query parameter)
  final String? accessKey;

  /// Private key (used to sign the query parameters)
  final String? privateKey;

  /// Reference to the User Registry Service for obtaining tokens
  final UserRegistryService? userRegistryService;

  /// The domain name for token requests
  final String assetRegistryDomain;

  /// Timeout for HTTP requests (optional)
  final Duration timeout;

  /// Use Bearer token authentication instead of HMAC signature
  final bool useBearerAuth;

  /// Creates a new instance of the service with direct access keys.
  AssetRegistryService(
      {this.accessKey,
      this.privateKey,
      this.userRegistryService,
      String baseUrl = 'https://api-ar.agstack.org/',
      this.assetRegistryDomain = 'api-ar.agstack.org',
      this.timeout = const Duration(seconds: 30),
      this.useBearerAuth = true})
      : _baseUri = Uri.parse(baseUrl) {
    // Verify that either direct keys or user registry service is provided
    if ((accessKey == null || privateKey == null) &&
        userRegistryService == null) {
      throw ArgumentError(
        'Either accessKey+privateKey or userRegistryService must be provided',
      );
    }
  }

  /// Factory constructor to create an instance using the User Registry service
  static Future<AssetRegistryService> withUserRegistry({
    required UserRegistryService userRegistryService,
    String baseUrl = 'https://api-ar.agstack.org/',
    String domain = 'api-ar.agstack.org',
    Duration timeout = const Duration(seconds: 30),
    bool useBearerAuth = true,
  }) async {
    // Make sure the user is logged in
    if (!userRegistryService.isLoggedIn) {
      throw Exception('User must be logged in to access the Asset Registry');
    }

    return AssetRegistryService(
      userRegistryService: userRegistryService,
      baseUrl: baseUrl,
      assetRegistryDomain: domain,
      timeout: timeout,
      useBearerAuth: useBearerAuth,
    );
  }

  // ---------------------------------------------------------------------------
  //  Public Methods – correspond to the REST endpoints of the API
  // ---------------------------------------------------------------------------
  /// Registers a new field boundary (polygon) and returns the HTTP response object.
  /// A successful call returns status code 200 and a confirmation in the body
  /// (currently without defined JSON structure).
  Future<http.Response> registerFieldBoundary({
    required String s2Index,
    required String wkt,
  }) async {
    final body = jsonEncode(<String, dynamic>{
     // 's2_index': s2Index, // Example: "8, 13"
      'wkt': wkt,
    });

    // Debug: Print payload to console

return _post(
      '/register-field-boundary',
      query: {},
      body: body,
    );
  }

  Future<List<dynamic>> findAssetForField({
    required String bound,
    double? inclusion,
    double? overlap,
    required int create,
    int? includeAutocreated,
    int? includeS2Indices,
  }) async {
    final query = <String, dynamic>{
      'bound': bound,
      'create': create,
      if (inclusion != null) 'inclusion': inclusion,
      if (overlap != null) 'overlap': overlap,
      if (includeAutocreated != null) 'includeAutocreated': includeAutocreated,
      if (includeS2Indices != null) 'includeS2Indices': includeS2Indices,
    };

    final response = await _get('/findAssetForField', query);
    _checkOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAsset({
    required String geoid,
    int? includeS2Indices,
  }) async {
    final query = <String, dynamic>{
      'geoid': geoid,
      if (includeS2Indices != null) 'includeS2Indices': includeS2Indices,
    };

    final response = await _get('/getAsset', query);
    _checkOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> findAssetsForAOI({
    required String aoiWkt,
    int? includeAutocreated,
    int? includeS2Indices,
  }) async {
    final query = <String, dynamic>{
      'OAI': aoiWkt,
      if (includeAutocreated != null) 'includeAutocreated': includeAutocreated,
      if (includeS2Indices != null) 'includeS2Indices': includeS2Indices,
    };

    final response = await _get('/findAssetsForAOI', query);
    _checkOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<double> getPercentageOverlapTwoFields({
    required String geoIdField1,
    required String geoIdField2,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'geo_id_field_1': geoIdField1,
      'geo_id_field_2': geoIdField2,
    });

    final response = await _post('/get-percentage-overlap-two-fields',
        query: {}, body: body);
    _checkOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['percentage'] as num).toDouble();
  }

  Future<List<String>> getDomains() async {
    final uri = _baseUri.replace(path: '/domains');
    final response = await http.get(uri).timeout(timeout);
    _checkOk(response);
    return List<String>.from(jsonDecode(response.body) as List<dynamic>);
  }

  Future<void> logout() async {
    final response = await _get('/logout', <String, dynamic>{});
    _checkOk(response);
  }

  // ---------------------------------------------------------------------------
  //  Private Helper Methods
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _getAuthInfo() async {
    if (accessKey != null && privateKey != null) {
      return {
        'accessKey': accessKey!,
        'privateKey': privateKey!,
      };
    }

    if (userRegistryService != null) {
      if (useBearerAuth) {
        // For Bearer authentication, use the User Registry access token directly
        final accessToken = userRegistryService!.accessToken;
        if (accessToken == null) {
          throw Exception('User is not logged in - no access token available');
        }
        return {
          'bearerToken': accessToken,
        };
      } else {
        // For HMAC authentication, get authority token and extract keys
        final token = await userRegistryService!.getAuthorityToken(
          domain: assetRegistryDomain,
        );

        if (token == null) {
          throw Exception(
            'Failed to get authority token for domain $assetRegistryDomain',
          );
        }

        final tokenData = jsonDecode(token) as Map<String, dynamic>;
        return {
          'accessKey': tokenData['accessKey'] as String,
          'privateKey': tokenData['privateKey'] as String,
        };
      }
    }

    throw Exception('No authentication method available');
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> query,
    required Object body,
  }) async {
    query = {...query};
    final authInfo = await _getAuthInfo();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    Uri uri;

    if (authInfo.containsKey('bearerToken')) {
      // Bearer authentication: add token to headers, no query auth
      headers['Authorization'] = 'Bearer ${authInfo['bearerToken']}';
      uri = _baseUri.replace(
        path: path,
        queryParameters: query.isNotEmpty ? _stringify(query) : null,
      );
    } else {
      // HMAC authentication: add auth to query parameters
      await _appendAuth(query, authInfo);
      uri = _baseUri.replace(
        path: path,
        queryParameters: _stringify(query),
      );
    }

    // Debug: Print request details
    // 
    // 
    // 

    return http
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(timeout);
  }

  Future<http.Response> _get(String path, Map<String, dynamic> query) async {
    query = {...query};
    final authInfo = await _getAuthInfo();

    final headers = {'Accept': 'application/json'};
    Uri uri;

    if (authInfo.containsKey('bearerToken')) {
      // Bearer authentication: add token to headers, no query auth
      headers['Authorization'] = 'Bearer ${authInfo['bearerToken']}';
      uri = _baseUri.replace(
        path: path,
        queryParameters: query.isNotEmpty ? _stringify(query) : null,
      );
    } else {
      // HMAC authentication: add auth to query parameters
      await _appendAuth(query, authInfo);
      uri = _baseUri.replace(
        path: path,
        queryParameters: _stringify(query),
      );
    }

return http.get(uri, headers: headers).timeout(timeout);
  }

  Future<void> _appendAuth(
      Map<String, dynamic> query, Map<String, dynamic> authInfo) async {
    query['accessKey'] = authInfo['accessKey'];
    query['signature'] = _signature(query, authInfo['privateKey']);
  }

  String _signature(Map<String, dynamic> query, String privateKey) {
    final entries = query.entries.where((e) => e.key != 'signature').toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final canonical = entries.map((e) => '${e.key}=${e.value}').join('&');
    final hmac = Hmac(sha256, utf8.encode(privateKey));
    final digest = hmac.convert(utf8.encode(canonical));
    return digest.toString();
  }

  Map<String, String> _stringify(Map<String, dynamic> map) =>
      map.map((k, v) => MapEntry(k, v.toString()));

  void _checkOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw http.ClientException(
        'AssetRegistryService: HTTP ${r.statusCode}: ${r.body}',
        r.request?.url,
      );
    }
  }
}

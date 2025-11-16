/// User Registry Service
/// ------------------------------------------------------------
/// A Dart service for interacting with the AgStack User Registry API
/// based on the provided OpenAPI structure.
///
/// Dependencies:
///   flutter pub add http
///   flutter pub add shared_preferences (for token storage)
///
/// Copyright 2025, Apache-2.0

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// {@template user_registry_service}
/// A service that encapsulates all important endpoints of the AgStack User Registry.
/// {@endtemplate}
class UserRegistryService {
  /// Base URL for the User Registry API
  final String baseUrl;

  /// Timeout for HTTP requests (optional)
  final Duration timeout;

  /// Access token for authenticated requests
  String? _accessToken;

  /// Refresh token for obtaining new access tokens
  String? _refreshToken;

  /// Creates a new instance of the UserRegistryService.
  UserRegistryService({
    this.baseUrl = 'https://user-registry.agstack.org',
    this.timeout = const Duration(seconds: 30),
  });

  /// Get the current access token
  String? get accessToken => _accessToken;

  /// Initialize the service by loading stored tokens
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('agstack_access_token');
    _refreshToken = prefs.getString('agstack_refresh_token');
  }

  /// Returns true if the user is currently logged in (has a valid token)
  bool get isLoggedIn => _accessToken != null;

  // ---------------------------------------------------------------------------
  //  Public Methods – correspond to the REST endpoints of the API
  // ---------------------------------------------------------------------------

  /// Sign up a new user
  /// Returns true if the signup was successful
  Future<bool> signup({
    required String email,
    required String password,
    required String confirmPassword,
    String? phoneNumber,
    bool discoverable = true,
    bool newsletter = false,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      'confirm_pass': confirmPassword,
      'phone_num': phoneNumber ?? '',
      'discoverable': discoverable.toString(),
      'newsletter': newsletter ? 'checked' : '',
    });

    final uri = Uri.parse('$baseUrl/signup');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(timeout);

    return response.statusCode == 200;
  }

  /// Login with email and password
  /// Returns true if login was successful and sets the access token
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    final uri = Uri.parse('$baseUrl/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Store the tokens
      _accessToken = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;

      // Save tokens to persistent storage
      if (_accessToken != null && _refreshToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('agstack_access_token', _accessToken!);
        await prefs.setString('agstack_refresh_token', _refreshToken!);
      }

      return true;
    } else{
      
    }

    return false;
  }

  /// Update user information
  /// Currently supports updating phone number only
  Future<bool> updateUser({required String phoneNumber}) async {
    if (_accessToken == null) {
      throw Exception('Not logged in');
    }

    final body = jsonEncode({'phone_num': phoneNumber});

    final uri = Uri.parse('$baseUrl/update');
    final response = await http
        .patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: body,
        )
        .timeout(timeout);

    return response.statusCode == 200;
  }

  /// Get List of allowed domains
  Future<List<String>> getDomains() async {

final uri = Uri.parse('$baseUrl/domains');
    final response = await http.get(
      uri,
      
    ).timeout(timeout);

    // Clear tokens regardless of the response

if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['Domains'] as List<dynamic>).cast<String>();
    }
    
    throw http.ClientException(
      'Failed to get domains: HTTP ${response.statusCode}: ${response.body}',
      uri,
    );
  }

  /// Log out the current user
  Future<bool> logout() async {
    if (_accessToken == null) {
      return true; // Already logged out
    }

    final uri = Uri.parse('$baseUrl/logout');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    ).timeout(timeout);

    // Clear tokens regardless of the response
    _accessToken = null;
    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('agstack_access_token');
    await prefs.remove('agstack_refresh_token');

    return response.statusCode == 200;
  }

  /// Get an authority token for a specific domain
  /// This token is required for accessing domain-specific services like Asset Registry
  Future<String?> getAuthorityToken({required String domain}) async {
    if (_accessToken == null) {
      throw Exception('Not logged in');
    }

    final uri = Uri.parse('$baseUrl/authority-token?domain=$domain');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['authority_token'] as String?;
    }

    if (response.statusCode == 404) {
      return null; // Authority token not found for this domain
    }

    throw http.ClientException(
      'Failed to get authority token: HTTP ${response.statusCode}: ${response.body}',
      uri,
    );
  }

  // Helper method to handle common error checking
  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'UserRegistryService: HTTP ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }
  }
}

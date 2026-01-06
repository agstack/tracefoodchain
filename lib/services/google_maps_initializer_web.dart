/// Web-spezifische Implementierung für Google Maps Initialisierung
/// Diese Datei wird nur auf Web-Plattformen geladen

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool _isLoading = false;

/// Initialisiert Google Maps API auf Web-Plattform
Future<void> initializeGoogleMapsWeb() async {
  // Bereits wird gerade geladen
  if (_isLoading) {
    // Warte bis Initialisierung abgeschlossen ist
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return;
  }

  _isLoading = true;

  try {
    // Hole API Key aus .env
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      debugPrint('WARNING: GOOGLE_MAPS_API_KEY not found in .env file');
      _isLoading = false;
      return;
    }

    // Prüfe ob Google Maps bereits geladen ist
    if (js.context.hasProperty('google') &&
        js.context['google'] != null &&
        js.context['google']['maps'] != null) {
      debugPrint('Google Maps API already loaded');
      _isLoading = false;
      return;
    }

    // Erstelle Script-Tag
    final script = html.ScriptElement()
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
      ..type = 'text/javascript'
      ..async = true;

    // Füge Script zum Head hinzu
    html.document.head?.append(script);

    // Warte bis Script geladen ist
    await script.onLoad.first;

    debugPrint('Google Maps API successfully loaded');
  } catch (e) {
    debugPrint('Error initializing Google Maps API: $e');
  } finally {
    _isLoading = false;
  }
}

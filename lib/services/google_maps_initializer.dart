import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'google_maps_initializer_stub.dart'
    if (dart.library.html) 'google_maps_initializer_web.dart';

/// Service zum dynamischen Laden der Google Maps API auf Web-Plattform
class GoogleMapsInitializer {
  static bool _isInitialized = false;

  /// Initialisiert Google Maps API auf Web-Plattform
  /// Lädt den API Key aus .env und fügt das Script dynamisch hinzu
  static Future<void> initialize() async {
    // Nur auf Web-Plattform ausführen
    if (!kIsWeb) {
      _isInitialized = true;
      return;
    }

    // Bereits initialisiert
    if (_isInitialized) {
      return;
    }

    await initializeGoogleMapsWeb();
    _isInitialized = true;
  }

  /// Gibt zurück ob Google Maps initialisiert wurde
  static bool get isInitialized => _isInitialized;
}

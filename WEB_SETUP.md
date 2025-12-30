# Google Maps für Flutter Web Setup

## Konfiguration

Die Google Maps Integration ist für die Web-Plattform konfiguriert mit sicherem API Key Management.

### Durchgeführte Änderungen:

1. **web/index.html** - Google Maps wird NICHT mehr statisch geladen (API Key ist nicht mehr öffentlich sichtbar)

2. **lib/services/google_maps_initializer.dart** - Neuer Service zum dynamischen Laden der Google Maps API:
   - Lädt API Key aus `.env` Datei (nicht öffentlich zugänglich)
   - Fügt Google Maps Script zur Laufzeit hinzu
   - Nur auf Web-Plattform aktiv

3. **lib/main.dart** - Initialisierung vor App-Start:
   ```dart
   if (kIsWeb) {
     await GoogleMapsInitializer.initialize();
   }
   ```

4. **pubspec.yaml** - `google_maps_flutter: ^2.10.0` (inkl. Web-Plugin)

## API Key Sicherheit

### ✅ Der API Key ist jetzt sicher:
- **NICHT** mehr in der index.html (wäre öffentlich sichtbar)
- Wird aus `.env` Datei geladen (nicht im Git Repository)
- Zur Laufzeit dynamisch eingefügt

### .env Datei
```
GOOGLE_MAPS_API_KEY="YOUR_API_KEY_HERE"
```

### Zusätzliche Absicherung (empfohlen für Production):

In der Google Cloud Console sollten Sie **HTTP Referrer Restrictions** setzen:
1. Gehen Sie zu: https://console.cloud.google.com/apis/credentials
2. Wählen Sie Ihren API Key aus
3. Unter "Application restrictions" → "HTTP referrers"
4. Fügen Sie hinzu:
   - `https://yourdomain.com/*` (Ihre Production Domain)
   - `http://localhost:*` (für lokale Entwicklung)
   - `https://localhost:*` (für lokale HTTPS-Entwicklung)

## Web App starten

```bash
flutter run -d chrome
```

oder für Production Build:

```bash
flutter build web
```

## Wichtige Hinweise

- Der API Key wird NICHT mehr in der index.html gespeichert ✅
- Die `.env` Datei sollte NICHT ins Git Repository committed werden
- Für Production: Domain-Restrictions in Google Cloud Console setzen
- Die Google Maps JavaScript API muss in der Google Cloud Console aktiviert sein

## Unterstützte Features auf Web

- ✅ Marker für currentGeolocation
- ✅ Polygone für boundaries
- ✅ Zoom und Pan
- ✅ InfoWindows
- ✅ Bildschirmfüllende Map-Ansicht
- ✅ Sicherer API Key (nicht öffentlich sichtbar)

## Bekannte Limitierungen

- My Location Button funktioniert nur mit HTTPS
- Einige native Features (z.B. Kompass) sind nicht verfügbar
- API Key muss in `.env` vorhanden sein (wird beim ersten Aufruf geladen)

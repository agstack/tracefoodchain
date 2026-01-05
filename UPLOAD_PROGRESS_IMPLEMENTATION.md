# Professioneller Bild-/Datei-Upload mit Progress-Tracking

## Überblick

Die TraceFoodChain App unterstützt jetzt professionellen Datei-Upload mit Echtzeit-Fortschrittsanzeige für **Web** und **Native** Plattformen (Android/iOS).

## Technische Details

### 1. Globaler Upload-Progress ValueNotifier

In `lib/main.dart` wurde ein globaler `TrackedValueNotifier` hinzugefügt:

```dart
TrackedValueNotifier<double> uploadProgress =
    TrackedValueNotifier<double>(0.0, "uploadProgress");
```

Dieser Notifier wird von 0.0 (0%) bis 100.0 (100%) aktualisiert und kann von jedem Widget genutzt werden.

### 2. Professionelle Upload-Funktion

Die neue Methode `_uploadFileWithProgress` in `lib/services/cloud_sync_service.dart` bietet:

- **Platform-Detection**: Automatische Erkennung von Web vs. Native
- **Web**: Verwendet `putData()` mit `Uint8List` bytes
- **Native**: Verwendet `putFile()` mit `File` Objekt
- **Progress-Tracking**: Echtzeit-Updates über `uploadProgress` ValueNotifier
- **Error Handling**: Umfassende Fehlerbehandlung für alle Upload-States

#### Signatur:

```dart
Future<Map<String, String?>?> _uploadFileWithProgress({
  required String fileName,
  required String contentType,
  File? file,        // Für Native
  Uint8List? bytes,  // Für Web
})
```

#### Rückgabewert:

```dart
{
  'downloadURL': 'https://...',  // Firebase Download URL
  'storagePath': 'images/...'    // Firebase Storage Pfad
}
```

Gibt `null` zurück bei Fehler.

### 3. Lokalisierte UI-Strings

Alle Upload-Nachrichten sind vollständig lokalisiert in 4 Sprachen (EN, DE, ES, FR):

| Key | Deutsch | English |
|-----|---------|---------|
| `uploadingFile` | Datei wird hochgeladen... | Uploading your file... |
| `uploadProgress` | {progress}% hochgeladen | {progress}% uploaded |
| `uploadSuccess` | Upload erfolgreich | Upload successful |
| `uploadFailed` | Upload fehlgeschlagen | Upload failed |
| `uploadCanceled` | Upload abgebrochen | Upload canceled |

## UI-Integration

### Option 1: SnackBar mit Progress (Empfohlen)

Verwende die Helper-Funktionen aus `lib/widgets/upload_progress_snackbar.dart`:

```dart
import 'package:trace_foodchain_app/widgets/upload_progress_snackbar.dart';

// Upload starten und SnackBar anzeigen
showUploadProgressSnackBar(context);

// Nach erfolgreichem Upload
closeUploadProgressSnackBar(context, success: true);

// Bei Upload-Fehler
closeUploadProgressSnackBar(context, success: false);
```

### Option 2: Dialog mit Progress

```dart
import 'package:trace_foodchain_app/widgets/upload_progress_snackbar.dart';

// Upload starten und Dialog anzeigen
UploadProgressDialog.show(context);

// Nach Upload schließen
UploadProgressDialog.close(context);
```

### Option 3: Eigenes UI mit ValueListenableBuilder

```dart
import 'package:trace_foodchain_app/main.dart';

ValueListenableBuilder<double>(
  valueListenable: uploadProgress,
  builder: (context, double value, child) {
    return Column(
      children: [
        LinearProgressIndicator(value: value / 100.0),
        Text('${value.toStringAsFixed(1)}% hochgeladen'),
      ],
    );
  },
)
```

## Beispiel: Vollständiger Upload-Workflow

```dart
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/widgets/upload_progress_snackbar.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> uploadImageExample(BuildContext context, File imageFile) async {
  final l10n = AppLocalizations.of(context)!;
  final cloudSyncService = CloudSyncService('tracefoodchain.org');
  
  // Zeige Upload-Progress SnackBar
  showUploadProgressSnackBar(context);
  
  try {
    // Upload durchführen (interne Funktion nutzt automatisch uploadProgress)
    // Deine Upload-Logik hier...
    
    // Bei Erfolg
    closeUploadProgressSnackBar(context, success: true);
    
  } catch (e) {
    // Bei Fehler
    closeUploadProgressSnackBar(context, success: false);
    debugPrint('Upload error: $e');
  }
}
```

## Automatische Integration

Die Upload-Funktion wird **automatisch** verwendet bei:

1. **Sync von lokalem localStorage zu Cloud**: 
   - `CloudSyncService.syncMethods()` ruft `_uploadPendingPhotosAndUpdateObjects()` auf
   - Alle Objekte mit `localDownloadURL` oder `*LocalPath` Properties werden hochgeladen

2. **Image Objects**:
   - Template: `RALType == "image"`
   - Property: `localDownloadURL` → wird zu `downloadURL` (Cloud URL)

3. **Document Properties**:
   - Properties: `nationalIDPhotoLocalPath`, etc.
   - Werden automatisch zu: `nationalIDPhotoURL`, etc.

## Platform-Spezifische Hinweise

### Web
- Verwendet `putData()` mit `Uint8List`
- **Voll implementiert**: Liest Bytes direkt aus XFile blob-URLs via `File.readAsBytes()`
- XFile.path auf Web enthält blob-URL (z.B. `blob:http://localhost:8080/...`)
- Benötigt CORS-Konfiguration in Firebase Storage

### Native (Android/iOS)
- Verwendet `putFile()` mit `File` Objekt
- Voller Zugriff auf lokales Dateisystem
- Benötigt Storage-Permissions in `AndroidManifest.xml` / `Info.plist`

### Technische Details: Web-Upload

Auf Web speichert `XFile.path` eine Browser-Blob-URL. Der Upload-Code liest die Bytes wie folgt:

```dart
if (kIsWeb) {
  // Read bytes from blob URL via File API
  final webFile = File(localPath); // localPath = blob:http://...
  bytes = await webFile.readAsBytes();
  
  // Upload via putData
  await _uploadFileWithProgress(
    fileName: fileName,
    contentType: 'image/jpeg',
    bytes: bytes, // Bytes from blob
  );
}
```

## Fehlerbehandlung

Die Upload-Funktion behandelt folgende Fehler:

- `TaskState.error`: Netzwerkfehler, Firebase-Fehler
- `TaskState.canceled`: Upload vom Benutzer abgebrochen
- File nicht gefunden (Native)
- Bytes nicht verfügbar (Web)
- Fehlende Firebase-Authentifizierung

Alle Fehler werden geloggt via `debugPrint()`.

## Best Practices

1. **Immer SnackBar/Dialog anzeigen**: Benutzer muss sehen, dass Upload läuft
2. **Lokalisierte Strings verwenden**: Nie hardcoded deutsche/englische Texte
3. **Error Handling**: Immer `try-catch` um Upload-Code
4. **Progress zurücksetzen**: `uploadProgress.value = 0.0` vor neuem Upload
5. **Cleanup**: SnackBar/Dialog nach Upload schließen

## Migration: Alter Code → Neuer Code

### Vorher (Alt):
```dart
final ref = FirebaseStorage.instance.ref().child(fileName);
final uploadTask = ref.putData(bytes);
final snapshot = await uploadTask;
final downloadURL = await snapshot.ref.getDownloadURL();
```

### Nachher (Neu):
```dart
showUploadProgressSnackBar(context); // UI-Feedback

final result = await _uploadFileWithProgress(
  fileName: fileName,
  contentType: 'image/jpeg',
  file: file,      // oder: bytes: bytes
);

if (result != null) {
  final downloadURL = result['downloadURL'];
  closeUploadProgressSnackBar(context, success: true);
} else {
  closeUploadProgressSnackBar(context, success: false);
}
```

## Zukünftige Erweiterungen

Mögliche Verbesserungen:

- [ ] Cancel-Button während Upload
- [ ] Retry-Logik bei Netzwerkfehlern
- [ ] Multiple simultane Uploads mit Queue
- [ ] Pause/Resume für große Dateien
- [ ] Thumbnail-Generation während Upload
- [ ] Compression vor Upload

## Support

Bei Fragen oder Problemen:
- Siehe Debug-Logs: `debugPrint()` Ausgaben
- Check Firebase Console: Storage Rules & CORS
- Test Platform: Web vs. Native unterschiedlich verhalten

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../helpers/national_id.dart';

/// Was die Texterkennung auf dem Ausweisfoto gefunden hat.
class IdCardOcrResult {
  IdCardOcrResult({required this.idCandidates, required this.words});

  /// 13-stellige Nummern auf dem Foto (nur Ziffern).
  final List<String> idCandidates;

  /// Alle Wörter des Fotos, normalisiert - zum Abgleich der Namen.
  final Set<String> words;

  bool containsId(String typed) =>
      idCandidates.contains(normalizeNationalId(typed));

  /// Mindestens ein eingegebener Vor- und ein Nachname stehen auf dem Foto.
  bool containsNames(String firstName, String lastName) {
    bool any(String value) => nameTokens(value).any(words.contains);
    return any(firstName) && any(lastName);
  }
}

/// Texterkennung des Ausweisfotos auf dem Gerät (ML Kit, offline).
///
/// Das Foto verlässt dafür das Telefon nicht, und es wird nichts gespeichert:
/// das Ergebnis dient nur dem Hinweis an den Registrar, bevor er weitergeht.
/// Im Web und auf Desktop gibt es ML Kit nicht - dort liefert [read] null.
class IdCardOcrService {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<IdCardOcrResult?> read(String imagePath) async {
    if (!isSupported) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return IdCardOcrResult(
        idCandidates: findIdCandidates(recognized.text),
        words: nameTokens(recognized.text).toSet(),
      );
    } catch (e) {
      debugPrint('ID OCR failed: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }
}

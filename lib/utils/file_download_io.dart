// Mobile/Desktop-spezifische Implementierung
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile(List<int> fileBytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes);

// Optional: Hier könnten Sie auch eine Benachrichtigung anzeigen
  // oder das Teilen-Interface öffnen
}

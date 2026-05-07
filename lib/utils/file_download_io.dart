// Mobile/Desktop-spezifische Implementierung
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(List<int> fileBytes, String fileName) async {
  if (Platform.isIOS) {
    // iOS: kein Dateisystem-Speicherdialog – Share-Sheet verwenden
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    await Share.shareXFiles([XFile(file.path)]);
    return;
  }

  // Android & Desktop: nativer "Speichern unter"-Dialog via SAF / System-Dialog
  // Auf Android schreibt file_picker die Bytes selbst via ACTION_CREATE_DOCUMENT (SAF)
  // – keine Storage-Permission erforderlich.
  final outputPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Datei speichern',
    fileName: fileName,
    bytes: Uint8List.fromList(fileBytes),
  );

  // Auf Desktop gibt file_picker nur den Pfad zurück – Bytes manuell schreiben
  if (outputPath != null &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await File(outputPath).writeAsBytes(fileBytes);
  }
}

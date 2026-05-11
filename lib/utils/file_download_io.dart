// Mobile/Desktop-spezifische Implementierung
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(List<int> fileBytes, String fileName) async {
  if (Platform.isAndroid) {
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';

    String customMime;
    switch (ext) {
      case 'kml':
        customMime = 'application/vnd.google-earth.kml+xml';
        break;
      case 'geojson':
        customMime = 'application/geo+json';
        break;
      case 'xlsx':
        customMime =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
      case 'pdf':
        customMime = 'application/pdf';
        break;
      case 'csv':
        customMime = 'text/csv';
        break;
      default:
        customMime = 'application/octet-stream';
    }

    // SAF-Dialog: User wählt Speicherort – keine Storage-Permission nötig
    await FileSaver.instance.saveAs(
      name: nameWithoutExt,
      bytes: Uint8List.fromList(fileBytes),
      ext: ext,
      mimeType: MimeType.custom,
      customMimeType: customMime,
    );
    return;
  }

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

  // Desktop: nativer "Speichern unter"-Dialog via file_picker
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

// Mobile/Desktop-spezifische Implementierung
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(List<int> fileBytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes);

  await Share.shareXFiles([XFile(file.path)]);
}

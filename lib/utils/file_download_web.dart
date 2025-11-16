// Web-spezifische Implementierung
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<void> downloadFile(List<int> fileBytes, String fileName) async {
  final blob = html.Blob([fileBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);

}

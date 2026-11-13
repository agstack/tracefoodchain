import 'dart:convert';

import 'package:archive/archive.dart';

/// Holt den Produzenten-Export aus einer gewählten Datei.
///
/// IHCafe liefert den Export als ZIP mit drei Dateien: productores.json,
/// paraiso.json (identisch mit productores.json) und fincas.json. Gebraucht
/// wird nur der Produzenten-Export; eine einzelne JSON-Datei wird unverändert
/// durchgereicht.
///
/// Wirft [FormatException], wenn das ZIP keinen Produzenten-Export enthält.
({String json, String sourceName}) readIhcafeExportFile(
    List<int> bytes, String fileName) {
  if (!fileName.toLowerCase().endsWith('.zip')) {
    return (
      json: utf8.decode(bytes, allowMalformed: true),
      sourceName: fileName,
    );
  }

  final archive = ZipDecoder().decodeBytes(bytes);
  // macOS legt "__MACOSX/._datei"-Begleiter mit ab - die sind kein JSON.
  final jsonFiles = archive.files.where((f) {
    if (!f.isFile) return false;
    final name = f.name.replaceAll('\\', '/');
    final base = name.split('/').last;
    return !name.startsWith('__MACOSX/') &&
        !base.startsWith('._') &&
        base.toLowerCase().endsWith('.json');
  }).toList();

  ArchiveFile? pick(String baseName) {
    for (final f in jsonFiles) {
      if (f.name.replaceAll('\\', '/').split('/').last.toLowerCase() ==
          baseName) {
        return f;
      }
    }
    return null;
  }

  final chosen = pick('productores.json') ?? pick('paraiso.json');
  if (chosen == null) {
    throw FormatException(
        'Das ZIP enthält weder productores.json noch paraiso.json '
        '(gefunden: ${jsonFiles.map((f) => f.name).join(', ')}).');
  }

  return (
    json: utf8.decode(chosen.content as List<int>, allowMalformed: true),
    sourceName: '$fileName › ${chosen.name}',
  );
}

import 'dart:convert';

/// Erstellt eine tiefe Kopie einer Map mit korrekter Typumwandlung
/// Löst das Problem: type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>'
Map<String, dynamic> deepCopyMap(dynamic value) {
  if (value == null) return {};

  // Verwende json.decode(json.encode()) für eine sichere tiefe Kopie
  // Dies garantiert, dass alle verschachtelten Maps korrekt als Map<String, dynamic> typisiert werden
  try {
    return json.decode(json.encode(value)) as Map<String, dynamic>;
  } catch (e) {
    // Fallback für den Fall, dass json encode/decode fehlschlägt
    if (value is! Map) return {};

    final result = <String, dynamic>{};
    (value as Map).forEach((key, val) {
      final stringKey = key.toString();
      if (val is Map) {
        result[stringKey] = deepCopyMap(val);
      } else if (val is List) {
        result[stringKey] = val.map((item) {
          if (item is Map) return deepCopyMap(item);
          return item;
        }).toList();
      } else {
        result[stringKey] = val;
      }
    });
    return result;
  }
}

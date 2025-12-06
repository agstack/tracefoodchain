import 'deep_copy_map.dart';

dynamic sortJsonAlphabetically(dynamic json) {
  // Primitive type or null
  if (json == null || (json is! Map && json is! List)) {
    return json;
  }

  // Array
  if (json is List) {
    return json.map((item) => sortJsonAlphabetically(item)).toList();
  }

  // Object - use deepCopyMap to ensure proper type casting
  Map<String, dynamic> typedMap = deepCopyMap(json);

  // Sort entries alphabetically
  final sortedEntries = typedMap.entries.toList()
    ..sort((a, b) {
      // Ensure keys are strings for comparison
      final keyA = a.key.toString();
      final keyB = b.key.toString();
      return keyA.compareTo(keyB);
    });

  return Map<String, dynamic>.fromEntries(
    sortedEntries.map(
      (entry) => MapEntry(entry.key, sortJsonAlphabetically(entry.value)),
    ),
  );
}

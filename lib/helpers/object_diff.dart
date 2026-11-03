/// Field-level difference between two versions of an openRAL object.
///
/// Goes into the `changedFields` property of a changeObjectData job, so an
/// auditor can read "what changed" straight from the signed method without
/// comparing the full input and output objects by hand.
///
/// Paths are JSONPath. List entries are addressed by their identifying key
/// where one exists and is unique (`specificProperties[?(@.key=='firstName')]`,
/// `alternateIDs[?(@.issuedBy=='National ID')]`), so a path stays meaningful
/// even if entries are reordered. Lists without such a key are compared as a
/// whole.
library;

/// Keys that change on every write and say nothing about the data itself.
const Set<String> _ignoredTopLevelKeys = {
  'methodHistoryRef',
  'needsSync',
  'digitalSignatures',
};

/// Candidate keys that identify an entry within a list of maps, in order of
/// preference. Keys within one group share an id space.
const List<List<String>> _identifyingKeys = [
  ['key', 'name'],
  ['issuedBy'],
  ['role'],
];

/// Each entry: `path`, `oldValue`, `newValue` (null where the value did not
/// exist on that side).
List<Map<String, dynamic>> diffObjectVersions(
  Map<String, dynamic> oldVersion,
  Map<String, dynamic> newVersion,
) {
  final changes = <Map<String, dynamic>>[];
  final keys = {...oldVersion.keys, ...newVersion.keys}
    ..removeAll(_ignoredTopLevelKeys);
  for (final key in keys.toList()..sort()) {
    _diff(r'$.' + key, oldVersion[key], newVersion[key], changes);
  }
  return changes;
}

void _diff(
  String path,
  dynamic oldValue,
  dynamic newValue,
  List<Map<String, dynamic>> changes,
) {
  if (oldValue is Map && newValue is Map) {
    final keys = {...oldValue.keys, ...newValue.keys}.map((k) => k.toString());
    for (final key in keys.toList()..sort()) {
      _diff('$path.$key', oldValue[key], newValue[key], changes);
    }
    return;
  }

  if (oldValue is List && newValue is List) {
    final idKeys = _identifyingKeysFor(oldValue, newValue);
    if (idKeys != null) {
      // specificProperties mix "key" and "name" entries - one id space.
      String? keyOf(Map e) => idKeys.firstWhere((k) => e[k] != null);
      final oldById = {for (final e in oldValue) _idOf(e, idKeys): e as Map};
      final newById = {for (final e in newValue) _idOf(e, idKeys): e as Map};
      for (final id in {...oldById.keys, ...newById.keys}) {
        final key = keyOf(newById[id] ?? oldById[id]!);
        _diff("$path[?(@.$key=='$id')]", oldById[id], newById[id], changes);
      }
      return;
    }
  }

  if (_equal(oldValue, newValue)) return;
  changes.add({
    'path': path,
    'oldValue': _plain(oldValue),
    'newValue': _plain(newValue),
  });
}

String _idOf(dynamic entry, List<String> idKeys) =>
    (entry as Map)[idKeys.firstWhere((k) => entry[k] != null)].toString();

/// The key group that identifies every entry of both lists uniquely, if any.
List<String>? _identifyingKeysFor(List oldList, List newList) {
  final all = [...oldList, ...newList];
  if (all.isEmpty || all.any((e) => e is! Map)) return null;
  for (final keys in _identifyingKeys) {
    if (!all.every((e) => keys.any((k) => (e as Map)[k] != null))) continue;
    bool unique(List list) =>
        list.map((e) => _idOf(e, keys)).toSet().length == list.length;
    if (unique(oldList) && unique(newList)) return keys;
  }
  return null;
}

bool _equal(dynamic a, dynamic b) {
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    return a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_equal(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is DateTime || b is DateTime) return _plain(a) == _plain(b);
  return a == b;
}

/// JSON-safe copy - the job is hashed, signed and stored in Firestore.
dynamic _plain(dynamic value) {
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return {for (final e in value.entries) e.key.toString(): _plain(e.value)};
  }
  if (value is List) return value.map(_plain).toList();
  return value;
}

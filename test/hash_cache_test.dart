import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
import 'package:trace_foodchain_app/services/hash_cache_service.dart';

Map<String, dynamic> _doc(String uid, int v) => {
      "identity": {"UID": uid},
      "methodHistoryRef": [],
      "v": v,
    };

void main() {
  late Directory dir;
  late Box<Map<dynamic, dynamic>> storage;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hash_cache_test');
    Hive.init(dir.path);
    storage = await Hive.openBox<Map<dynamic, dynamic>>('localStorage_u1');
    await hashCache.open('u1', storage);
  });

  tearDown(() async {
    await hashCache.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  // Like the sync scan: hash the stored document (without needsSync)
  String scan(String uid) {
    final doc = storage.get(uid)!;
    final copy = Map<String, dynamic>.from(doc)..remove("needsSync");
    return hashCache.hashFor(uid, doc, copy);
  }

  test('stores hashes and reuses them until the document is written again',
      () async {
    await storage.put("a", _doc("a", 1));
    await Future.delayed(Duration.zero);

    expect(scan("a"), generateStableHash(_doc("a", 1)));
    await hashCache.flush(storage);

    // From the cache: hashFor does not hash the given copy again
    final doc = storage.get("a")!;
    expect(hashCache.hashFor("a", doc, _doc("a", 999)),
        generateStableHash(_doc("a", 1)));

    // A write invalidates the entry
    await storage.put("a", _doc("a", 2));
    await Future.delayed(Duration.zero);
    expect(scan("a"), generateStableHash(_doc("a", 2)));
  });

  test('a document replaced during the scan is not cached', () async {
    await storage.put("a", _doc("a", 1));
    await Future.delayed(Duration.zero);

    scan("a"); // computed from version 1
    await storage.put("a", _doc("a", 2)); // replaced before the flush
    await Future.delayed(Duration.zero);
    await hashCache.flush(storage);

    expect(scan("a"), generateStableHash(_doc("a", 2)));
  });

  test('putAll and delete invalidate the entries', () async {
    await storage.putAll({"a": _doc("a", 1), "b": _doc("b", 1)});
    await Future.delayed(Duration.zero);
    scan("a");
    scan("b");
    await hashCache.flush(storage);

    await storage.putAll({"a": _doc("a", 2)});
    await storage.delete("b");
    await storage.put("b", _doc("b", 3));
    await Future.delayed(Duration.zero);

    expect(scan("a"), generateStableHash(_doc("a", 2)));
    expect(scan("b"), generateStableHash(_doc("b", 3)));
  });

  test('survives a reopen', () async {
    await storage.put("a", _doc("a", 1));
    await Future.delayed(Duration.zero);
    scan("a");
    await hashCache.flush(storage);

    await hashCache.close();
    await hashCache.open('u1', storage);

    final doc = storage.get("a")!;
    expect(hashCache.hashFor("a", doc, _doc("a", 999)),
        generateStableHash(_doc("a", 1)));
  });
}

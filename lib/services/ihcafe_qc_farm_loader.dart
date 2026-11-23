import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:trace_foodchain_app/helpers/json_full_double_to_int.dart';
import 'package:trace_foodchain_app/helpers/sort_json_alphabetically.dart';
import 'package:trace_foodchain_app/models/country_config.dart';
import 'package:trace_foodchain_app/services/country_config_service.dart';
import 'package:trace_foodchain_app/services/ihcafe_farm_matching.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/role_management_service.dart';

/// Lädt die QC-geprüften Farmen samt Farmer und schreibt die IHCafe-Kennungen.
///
/// Als geprüft gilt - wie in der Field Registry - nur, was ein
/// performQualityControl-Job mit qcDecision 'approved' ausgegeben hat.
/// Freigaben aus der Zeit davor liefen als changeObjectData ohne Entscheidung
/// und zählen nicht.

/// Kontext der Änderung im signierten changeObjectData-Job.
const String changeContextIhcafeMatching = 'ihcafeMatching';

typedef MatchLog = void Function(String line);

/// Eine geprüfte Farm mit den Rohobjekten, aus denen [match] gebildet wurde.
class QcFarmRecord {
  final Map<String, dynamic> farm;
  final Map<String, dynamic>? farmer;
  final FarmToMatch match;
  const QcFarmRecord(this.farm, this.farmer, this.match);
}

String _addr(Map<String, dynamic>? obj, String key) =>
    obj?['currentGeolocation']?['postalAddress']?[key]?.toString().trim() ?? '';

String _text(dynamic v) =>
    (v == null || v == '-no data found-') ? '' : v.toString().trim();

List<String> _altIds(Map<String, dynamic>? obj, String issuer,
    {bool onlyWithoutName = false}) {
  final list = obj?['identity']?['alternateIDs'];
  if (list is! List) return const [];
  return [
    for (final a in list)
      if (a is Map &&
          a['issuedBy'] == issuer &&
          _text(a['UID']).isNotEmpty &&
          (!onlyWithoutName || _text(a['idName']).isEmpty))
        _text(a['UID']),
  ];
}

String? ownerUidOfFarm(Map<String, dynamic> farm) {
  final links = farm['linkedObjectRef'];
  if (links is! List) return null;
  for (final link in links) {
    if (link is Map && link['role'] == 'owner') {
      final uid = link['UID']?.toString();
      if (uid != null && uid.isNotEmpty) return uid;
    }
  }
  return null;
}

String farmerDisplayName(Map<String, dynamic>? farmer) {
  if (farmer == null) return '';
  final first = _text(getSpecificPropertyfromJSON(farmer, 'firstName'));
  final last = _text(getSpecificPropertyfromJSON(farmer, 'lastName'));
  final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
  return combined.isNotEmpty ? combined : _text(farmer['identity']?['name']);
}

FarmToMatch farmToMatchFromObjects(
    Map<String, dynamic> farm, Map<String, dynamic>? farmer) {
  String pick(String key) {
    final v = _addr(farm, key);
    return v.isNotEmpty ? v : _addr(farmer, key);
  }

  final ids = _altIds(farmer, nationalIdIssuer);
  return FarmToMatch(
    farmUid: farm['identity']?['UID']?.toString() ?? '',
    farmName: _text(farm['identity']?['name']),
    farmerUid: farmer?['identity']?['UID']?.toString(),
    // Ohne Farmer-Objekt bleibt der Farmname - bei Importen ist das der
    // Personenname.
    farmerName: farmer != null
        ? farmerDisplayName(farmer)
        : _text(farm['identity']?['name']),
    nationalId: ids.isEmpty ? '' : ids.first,
    municipio: pick('municipalityName'),
    departamento: pick('stateName'),
    aldea: pick('cityName'),
    farmerIhcafeIds: _altIds(farmer, ihcafeIssuer),
    farmIhcafeIds: _altIds(farm, ihcafeIssuer),
    farmerIhcafeIdsWithoutName:
        _altIds(farmer, ihcafeIssuer, onlyWithoutName: true),
    farmIhcafeIdsWithoutName:
        _altIds(farm, ihcafeIssuer, onlyWithoutName: true),
  );
}

/// Objekte zu UIDs, je 30 in einem Abruf.
Future<Map<String, Map<String, dynamic>>> _fetchObjects(
    List<String> uids) async {
  final result = <String, Map<String, dynamic>>{};
  for (var i = 0; i < uids.length; i += 30) {
    final chunk = uids.sublist(i, math.min(i + 30, uids.length));
    final snap = await FirebaseFirestore.instance
        .collection('TFC_objects')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      result[doc.id] = doc.data();
    }
  }
  return result;
}

/// Lädt alle Farmen, die eine QC-Freigabe haben und in einem Land mit
/// IHCafe-Verzeichnis liegen (und im Gebiet des Nutzers, falls beschränkt).
Future<List<QcFarmRecord>> loadQcApprovedFarms({
  required MatchLog log,
  bool Function()? cancelled,
}) async {
  // 1. QC-Jobs durchgehen. Ohne orderBy auf existenceStarts - dafür bräuchte
  // es einen zusammengesetzten Index, und die Reihenfolge ist hier egal.
  const pageSize = 50;
  final farmUids = <String>{};
  final unknownTypeUids = <String>{};
  var methods = 0;
  var approved = 0;
  DocumentSnapshot<Map<String, dynamic>>? cursor;

  log('Loading performQualityControl jobs from TFC_methods ...');
  while (true) {
    if (cancelled?.call() == true) return const [];
    var q = FirebaseFirestore.instance
        .collection('TFC_methods')
        .where('template.RALType', isEqualTo: 'performQualityControl')
        .orderBy(FieldPath.documentId)
        .limit(pageSize);
    if (cursor != null) q = q.startAfterDocument(cursor);
    final snap = await q.get();

    for (final doc in snap.docs) {
      methods++;
      final m = doc.data();
      if (getSpecificPropertyfromJSON(m, 'qcDecision') != 'approved') continue;
      approved++;
      for (final out in [
        ...(m['outputObjects'] as List? ?? const []),
        ...(m['outputObjectsRef'] as List? ?? const []),
      ]) {
        if (out is! Map) continue;
        final uid = (out['identity']?['UID'] ?? out['UID'])?.toString();
        if (uid == null || uid.isEmpty) continue;
        final type = out['template']?['RALType'] ?? out['RALType'];
        if (type == 'farm') {
          farmUids.add(uid);
        } else if (type == 'field') {
          // Felder, die an eine früher freigegebene Farm gehängt wurden.
          final container =
              out['currentGeolocation']?['container']?['UID']?.toString();
          if (container != null &&
              container.isNotEmpty &&
              container != 'unknown') {
            farmUids.add(container);
          }
        } else if (type == null) {
          unknownTypeUids.add(uid);
        }
      }
    }
    log('  ... $methods QC jobs read, $approved approved, '
        '${farmUids.length} farm UIDs so far');
    if (snap.docs.length < pageSize) break;
    cursor = snap.docs.last;
  }

  // Referenzen ohne Typ: nachladen und nur Farmen behalten.
  if (unknownTypeUids.isNotEmpty) {
    log('Resolving ${unknownTypeUids.length} output refs without RALType ...');
    final objs = await _fetchObjects(unknownTypeUids.toList());
    for (final e in objs.entries) {
      if (e.value['template']?['RALType'] == 'farm') farmUids.add(e.key);
    }
  }

  // 2. Aktuelle Fassung der Farmen.
  log('Fetching ${farmUids.length} farms ...');
  final farms = await _fetchObjects(farmUids.toList());

  final scope = RoleManagementService().currentUserScope();
  var skippedState = 0, skippedCountry = 0, skippedScope = 0;
  final kept = <Map<String, dynamic>>[];
  for (final farm in farms.values) {
    if (farm['template']?['RALType'] != 'farm') continue;
    if (farm['objectState'] != 'active') {
      skippedState++;
      continue;
    }
    final country = countryConfigService.resolve(_addr(farm, 'country'));
    if (country?.producerRegistry != CountryConfig.producerRegistryIhcafe) {
      skippedCountry++;
      continue;
    }
    if (scope != null &&
        !scope.isEmpty &&
        !scope.countries.contains(country!.code)) {
      skippedScope++;
      continue;
    }
    kept.add(farm);
  }
  log('Farms: ${farms.length} loaded, ${kept.length} kept '
      '(not active: $skippedState, country without IHCafe registry: '
      '$skippedCountry, outside your scope: $skippedScope)');

  // 3. Farmer.
  final ownerUids = kept.map(ownerUidOfFarm).whereType<String>().toSet();
  log('Fetching ${ownerUids.length} farmers ...');
  final farmers = await _fetchObjects(ownerUids.toList());
  final withoutOwner = kept.where((f) => ownerUidOfFarm(f) == null).length;
  final ownerMissing = ownerUids.where((u) => !farmers.containsKey(u)).length;
  if (withoutOwner > 0 || ownerMissing > 0) {
    log('  warning: $withoutOwner farm(s) without owner link, '
        '$ownerMissing owner object(s) not found');
  }

  final records = <QcFarmRecord>[];
  for (final farm in kept) {
    final farmer = farmers[ownerUidOfFarm(farm)];
    records.add(QcFarmRecord(farm, farmer, farmToMatchFromObjects(farm, farmer)));
  }
  records.sort((a, b) => a.match.farmerName.compareTo(b.match.farmerName));
  log('Ready: ${records.length} QC-approved farms to match.');
  return records;
}

/// Fügt [adds] als alternateIDs hinzu, soweit noch nicht vorhanden, und
/// trägt bei vorhandenen IHCafe-Einträgen ein fehlendes `idName` nach.
/// Liefert die tatsächlich geänderten.
List<PlannedAltId> _addAltIds(
    Map<String, dynamic> obj, Iterable<PlannedAltId> adds) {
  final identity = obj['identity'] as Map;
  final list = (identity['alternateIDs'] as List?) ?? <dynamic>[];
  final added = <PlannedAltId>[];
  for (final a in adds) {
    final existing = list.whereType<Map>().where(
        (x) => x['issuedBy'] == a.issuedBy && _text(x['UID']) == a.uid);
    if (existing.isEmpty) {
      list.add(a.toJson());
      added.add(a);
      continue;
    }
    if (a.issuedBy == ihcafeIssuer) {
      var named = false;
      for (final x in existing) {
        if (_text(x['idName']).isEmpty) {
          x['idName'] = a.label;
          named = true;
        }
      }
      if (named) added.add(a);
    }
  }
  identity['alternateIDs'] = list;
  return added;
}

/// Schreibt die geplanten Kennungen als signierte changeObjectData-Jobs -
/// je Objekt einer, mit Matching-Stufe und Begründung im Job.
///
/// Mehrere Farmen desselben Farmers ergeben am Farmer nur einen Job.
Future<({int written, int failed})> applyIhcafeMatches({
  required List<IhcafeFarmMatch> matches,
  required IhcafeCatalogMeta catalogMeta,
  required MatchLog log,
  bool Function()? cancelled,
}) async {
  var written = 0, failed = 0;

  Map<String, dynamic> jobInfo(IhcafeFarmMatch m) => {
        'level': m.level.name,
        'clave': m.producer?.clave ?? '',
        'productorId': '${m.producer?.productorId ?? ''}',
        'fincaId': '${m.finca?.fincaId ?? ''}',
        'nameScore': (m.nameScore * 100).round(),
        'reasons': m.reasons,
        'catalogContract': catalogMeta.contract,
        'catalogProject': catalogMeta.proyectoUid,
        'catalogExportedAt': catalogMeta.exportedAt,
      };

  Future<void> write(String uid, String what, List<PlannedAltId> adds,
      IhcafeFarmMatch m) async {
    try {
      final current = await getCurrentObjectVersion(uid);
      if (current.isEmpty) throw Exception('object not found');
      final updated = deepCopyMap(current);
      final added = _addAltIds(updated, adds);
      if (added.isEmpty) {
        log('  = $what $uid: already up to date');
        return;
      }
      final processed = jsonFullDoubleToInt(sortJsonAlphabetically(updated))
          as Map<String, dynamic>;
      await changeObjectData(
        processed,
        syncFromCloud: false,
        changeReason: 'IHCafe matching (${m.level.name}) against export '
            '${catalogMeta.exportedAt.split('T').first}',
        changeContext: changeContextIhcafeMatching,
        jobProperties: {'ihcafeMatch': jobInfo(m)},
      );
      written++;
      log('  + $what $uid: ${added.map((a) => '${a.label}=${a.uid}'
          '${a.onlyName ? ' (idName added)' : ''}').join(', ')}');
    } catch (e) {
      failed++;
      log('  ! $what $uid FAILED: $e');
    }
  }

  final doneFarmers = <String>{};
  for (final m in matches) {
    if (cancelled?.call() == true) {
      log('Cancelled.');
      break;
    }
    log('${m.farm.farmerName} -> ${m.producer?.nombreCompleto} [${m.level.name}]');
    final farmerUid = m.farm.farmerUid;
    if (farmerUid != null &&
        m.farmerAdds.isNotEmpty &&
        doneFarmers.add(farmerUid)) {
      await write(farmerUid, 'farmer', m.farmerAdds, m);
    }
    if (m.farmAdds.isNotEmpty) {
      await write(m.farm.farmUid, 'farm', m.farmAdds, m);
    }
  }
  return (written: written, failed: failed);
}

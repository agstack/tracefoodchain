import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:trace_foodchain_app/services/ihcafe_farm_matching.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

/// Sync-Stand mit IHCafe (`TFC_ihcafe_sync`, ein Eintrag je QC-freigegebenem
/// Plot) - gepflegt von der Cloud, gelesen vom IHCafe-Connector.
///
/// Die App liefert dafür nur die Ergebnisse der Matching-Läufe zu: ob eine
/// Farm "gematcht" ist, liest die Cloud selbst aus den alternateIDs, aber
/// "kein Treffer" lässt sich an den Objekten nicht ablesen.
///
/// Details zum Zustandsmodell und zur Connector-Schnittstelle:
/// IHCAFE_SYNC.md im Repo der Cloud Functions.
class IhcafeSyncService {
  static const String _base =
      'https://europe-west3-tracefoodchain.cloudfunctions.net';

  static Future<Map<String, dynamic>> _post(
      String function, Map<String, dynamic> body) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_base/$function'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('$function ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Meldet die Ergebnisse eines Laufs, in Paketen zu 200 Farmen.
  ///
  /// [written] enthält die Farmen, deren Kennungen in diesem Lauf geschrieben
  /// wurden. Je Farm zählt nur das letzte gemeldete Ergebnis.
  static Future<int> recordMatchResults({
    required List<IhcafeFarmMatch> results,
    required IhcafeCatalogMeta catalogMeta,
    Set<String> written = const {},
    void Function(int done, int total)? onProgress,
  }) async {
    // Mehrere Farmen desselben Farmers stehen einzeln drin; eine Farm ohne UID
    // lässt sich nicht zuordnen.
    final byFarm = <String, IhcafeFarmMatch>{
      for (final r in results)
        if (r.farm.farmUid.isNotEmpty) r.farm.farmUid: r,
    };
    final entries = [
      for (final r in byFarm.values)
        {
          'farmUid': r.farm.farmUid,
          'farmerUid': r.farm.farmerUid,
          'level': r.level.name,
          'clave': r.producer?.clave,
          'productorId': r.producer?.productorId?.toString(),
          'fincaId': r.finca?.fincaId?.toString(),
          'written': written.contains(r.farm.farmUid),
        },
    ];

    var recorded = 0;
    for (var i = 0; i < entries.length; i += 200) {
      final chunk = entries.sublist(
          i, i + 200 > entries.length ? entries.length : i + 200);
      final result = await _post('recordIhcafeMatchResults', {
        'catalog': {
          'contract': catalogMeta.contract,
          'proyectoUid': catalogMeta.proyectoUid,
          'exportedAt': catalogMeta.exportedAt,
        },
        'results': chunk,
      });
      recorded += (result['recorded'] as num?)?.toInt() ?? 0;
      onProgress?.call(i + chunk.length, entries.length);
    }
    return recorded;
  }

  /// Baut den Sync-Index aus allen aktiven Feldern auf (nur SUPERADMIN).
  /// Lässt sich jederzeit wiederholen; die Push-Buchführung des Connectors
  /// bleibt erhalten.
  static Future<Map<String, int>> rebuild(
      {void Function(int processed)? onProgress}) async {
    String? startAfter;
    final totals = <String, int>{};
    // Obergrenze als Notbremse gegen eine Schleife, die nicht vorankommt.
    for (var page = 0; page < 2000; page++) {
      final result = await _post('rebuildIhcafeSync', {
        if (startAfter != null) 'startAfter': startAfter,
        'pageSize': 200,
      });
      for (final key in [
        'processed',
        'written',
        'unchanged',
        'withdrawn',
        'skipped',
        'noCountry',
      ]) {
        totals[key] = (totals[key] ?? 0) + ((result[key] as num?)?.toInt() ?? 0);
      }
      onProgress?.call(totals['processed']!);
      startAfter = result['nextStartAfter'] as String?;
      if (startAfter == null) return totals;
    }
    throw Exception('rebuildIhcafeSync did not finish');
  }
}

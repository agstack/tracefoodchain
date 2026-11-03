import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Aufbau des QC-Suchindex (`TFC_qc_index`) über die Cloud Function
/// rebuildQcIndex - nur SUPERADMIN.
///
/// Laufend gepflegt wird der Index von der Cloud selbst (onRalObjectChanged).
/// Der Aufbau ist nur einmal nötig, für alles, was vorher schon offen war, und
/// lässt sich jederzeit wiederholen.
class QcIndexService {
  static const String _rebuildUrl =
      'https://europe-west3-tracefoodchain.cloudfunctions.net/rebuildQcIndex';

  /// Blättert durch alle offenen Objekte; [onProgress] erhält die Zahl der
  /// bisher verarbeiteten. Am Ende meldet die Cloud den Index als fertig.
  static Future<int> rebuild({void Function(int processed)? onProgress}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    String? startAfter;
    int processed = 0;
    // Obergrenze als Notbremse gegen eine Schleife, die nicht vorankommt.
    for (int page = 0; page < 1000; page++) {
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_rebuildUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (startAfter != null) 'startAfter': startAfter,
          'pageSize': 200,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('rebuildQcIndex ${response.statusCode}: '
            '${response.body}');
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      processed += (result['processed'] as num?)?.toInt() ?? 0;
      onProgress?.call(processed);
      startAfter = result['nextStartAfter'] as String?;
      if (startAfter == null) return processed;
    }
    throw Exception('rebuildQcIndex did not finish');
  }
}

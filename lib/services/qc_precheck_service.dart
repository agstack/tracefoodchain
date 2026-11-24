import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Ampel eines Prüfpunkts der automatischen QC-Vorprüfung.
enum PrecheckStatus { green, yellow, red }

PrecheckStatus _statusOf(dynamic value) => switch (value) {
      'green' => PrecheckStatus.green,
      'red' => PrecheckStatus.red,
      _ => PrecheckStatus.yellow,
    };

/// Ergebnis für einen Punkt der QC-Checkliste - [id] entspricht der ID des
/// Prüfpunkts im QC-Screen (`objectUid|check`).
class PrecheckCheck {
  PrecheckCheck({
    required this.objectUid,
    required this.check,
    required this.status,
    required this.reasons,
  });

  final String objectUid;
  final String check;
  final PrecheckStatus status;

  /// Gründe als Codes (z. B. `idMismatch`) - übersetzt wird in der App.
  final List<String> reasons;

  String get id => '$objectUid|$check';
}

/// Vorprüfung eines QC-Bündels (`TFC_qc_precheck/{bundleKey}`).
///
/// Die Vorprüfung entscheidet nichts: sie zeigt dem Registrar Coordinator,
/// wo er genau hinsehen muss. Freigeben und signieren tut weiter er.
class QcPrecheck {
  QcPrecheck({
    required this.bundleKey,
    required this.overall,
    required this.checks,
    required this.aiUsed,
    required this.model,
    required this.complete,
    required this.computedAt,
  });

  final String bundleKey;
  final PrecheckStatus overall;
  final Map<String, PrecheckCheck> checks;
  final bool aiUsed;
  final String? model;

  /// false, solange etwas fehlte, das sich noch ändern kann (Foto nicht
  /// hochgeladen, KI nicht erreichbar) - dann lohnt ein neuer Lauf.
  final bool complete;
  final DateTime? computedAt;

  static QcPrecheck? fromJson(Map<String, dynamic>? data) {
    if (data == null) return null;
    final checks = <String, PrecheckCheck>{};
    for (final raw in (data['checks'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final check = PrecheckCheck(
        objectUid: raw['objectUid']?.toString() ?? '',
        check: raw['check']?.toString() ?? '',
        status: _statusOf(raw['status']),
        reasons: [
          for (final r in (raw['reasons'] as List?) ?? const []) r.toString()
        ],
      );
      checks[check.id] = check;
    }
    final computed = data['computedAt'];
    return QcPrecheck(
      bundleKey: data['bundleKey']?.toString() ?? '',
      overall: _statusOf(data['overall']),
      checks: checks,
      aiUsed: data['aiUsed'] == true,
      model: data['model']?.toString(),
      complete: data['complete'] == true,
      computedAt: computed is Timestamp
          ? computed.toDate()
          : DateTime.tryParse(computed?.toString() ?? ''),
    );
  }
}

/// Zugriff auf die Cloud Function qcPrecheck und ihre gespeicherten Ergebnisse.
class QcPrecheckService {
  static const String _url =
      'https://europe-west3-tracefoodchain.cloudfunctions.net/qcPrecheck';
  static const String _collection = 'TFC_qc_precheck';

  /// So viele Bündel nimmt die Function je Aufruf an.
  static const int _batchSize = 10;

  /// Gespeicherte Ergebnisse - nur lesen, kostet nichts.
  static Future<Map<String, QcPrecheck>> load(Iterable<String> keys) async {
    final result = <String, QcPrecheck>{};
    final list = keys.toSet().toList();
    // whereIn erlaubt höchstens 30 Werte.
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, (i + 30).clamp(0, list.length));
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final precheck = QcPrecheck.fromJson(doc.data());
        if (precheck != null) result[doc.id] = precheck;
      }
    }
    return result;
  }

  /// Startet die Vorprüfung für [keys]. Unveränderte Bündel liefert die Cloud
  /// aus dem Speicher, ohne die KI erneut zu fragen - außer mit [force].
  /// [onProgress] erhält die Zahl der fertigen Bündel.
  static Future<Map<String, QcPrecheck>> run(
    List<String> keys, {
    bool force = false,
    void Function(int done)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final result = <String, QcPrecheck>{};
    for (var i = 0; i < keys.length; i += _batchSize) {
      final chunk = keys.sublist(i, (i + _batchSize).clamp(0, keys.length));
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'bundleKeys': chunk, 'force': force}),
      );
      if (response.statusCode != 200) {
        throw Exception('qcPrecheck ${response.statusCode}: ${response.body}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List?) ?? const [];
      for (var j = 0; j < results.length && j < chunk.length; j++) {
        final raw = results[j];
        final precheck =
            raw is Map ? QcPrecheck.fromJson(raw.cast<String, dynamic>()) : null;
        if (precheck != null) result[chunk[j]] = precheck;
      }
      onProgress?.call(i + chunk.length);
    }
    return result;
  }
}

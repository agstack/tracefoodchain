import 'package:cloud_firestore/cloud_firestore.dart';

/// Zeitstempel, die gespeichert werden (openRAL-Objekte und -Methoden,
/// Firestore-Dokumente), sind immer UTC im Format ISO 8601 mit `Z`,
/// sekundengenau: `2026-11-24T17:04:51Z`.
///
/// Sie werden direkt als Text geschrieben, nie als `DateTime`: ein
/// `DateTime`-Objekt wird erst beim Signieren und Hochladen in Text
/// umgewandelt (`convertToJson`), und diese Umwandlung muss für bereits
/// signierte, noch nicht hochgeladene Methoden unverändert bleiben.
///
/// Ältere Daten tragen Ortszeit des erfassenden Geräts ohne Zeitzone
/// (`2026-11-24T11:04:51`). Sie lassen sich nicht nachträglich zuordnen und
/// werden beim Lesen als Ortszeit behandelt.
String utcNowIso() => toUtcIso(DateTime.now());

/// [time] als UTC-Text im Speicherformat (siehe [utcNowIso]).
String toUtcIso(DateTime time) {
  final utc = time.toUtc();
  return '${utc.toIso8601String().split('.').first.replaceAll('Z', '')}Z';
}

/// Liest einen gespeicherten Zeitpunkt - Text (mit oder ohne Zeitzone),
/// `DateTime` oder Firestore-`Timestamp` - und gibt ihn in Ortszeit zurück,
/// so wie er angezeigt wird. Null, wenn sich nichts lesen lässt.
DateTime? parseStoredTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../helpers/deep_copy_map.dart';
import '../utils/polygon_geometry.dart';
import 'open_ral_service.dart';

/// Das Ergebnis einer Polygon-Korrektur im QC.
///
/// [points] ist der offene Ring, [accuracies] ist punktgleich dazu - beim
/// Schreiben wird der Ring geschlossen, die Genauigkeiten bleiben bei der
/// offenen Länge (genau die Kombination, die die Aufnahme ablegt).
class FieldGeometryEdit {
  const FieldGeometryEdit({
    required this.points,
    required this.accuracies,
    this.movedCorners = 0,
    this.addedCorners = 0,
    this.deletedCorners = 0,
    this.reason = '',
    this.description,
  });

  final List<LatLng> points;
  final List<double> accuracies;
  final int movedCorners;
  final int addedCorners;
  final int deletedCorners;

  /// Begründung des Prüfers - geht als changeReason in den signierten Job.
  final String reason;

  /// Beschreibung der Änderung statt der Eckenzählung - etwa beim Ersetzen
  /// durch ein Polygon aus einer Datei.
  final String? description;

  bool get hasChanges =>
      description != null ||
      movedCorners > 0 ||
      addedCorners > 0 ||
      deletedCorners > 0;

  /// Landet so in der Objekt-Historie - deshalb englisch, wie alle openRAL-Texte.
  String get summary =>
      description ??
      '$movedCorners moved, $addedCorners added, $deletedCorners deleted';
}

/// Schreibt eine im QC korrigierte Feldgrenze zurück.
///
/// Der Schreibvorgang läuft über [changeObjectData]: damit entsteht eine
/// changeObjectData-Methode mit dem QC-Nutzer als Executor, die alte Geometrie
/// bleibt als Input-Objekt in der Methodenhistorie erhalten, und die Methode
/// wird signiert und zur Cloud synchronisiert.
///
/// Mitgezogen werden die abgeleiteten Werte: Fläche, Schwerpunkt und - weil die
/// Erfassung sie als Summe der Feldflächen führt - die Gesamtfläche der
/// zugehörigen Farm.
/// Gibt die geschriebene Objektversion zurück, damit der aufrufende Screen sie
/// sofort anzeigen kann - der Weg über die Cloud zurück wäre ein Rennen gegen
/// den asynchronen Sync.
///
/// [changeContext] und [jobProperties] gehen in den Job - für das Ersetzen
/// durch eine extern korrigierte Geometrie etwa
/// [changeContextExternalGeometryReplacement] mit `externalCorrection`.
Future<Map<String, dynamic>> saveFieldGeometry({
  required Map<String, dynamic> field,
  required FieldGeometryEdit edit,
  String changeContext = changeContextQcCorrection,
  Map<String, dynamic> jobProperties = const {},
}) async {
  final closed = closeRing(edit.points);
  if (closed.length < 4) {
    throw ArgumentError('A field polygon needs at least three corners');
  }

  final previousArea = _readArea(field);
  final newArea = polygonAreaInHectares(closed);

  Map<String, dynamic> updated = deepCopyMap(field);

  final coordinates =
      closed.map((p) => <double>[p.latitude, p.longitude]).toList();
  updated = setSpecificPropertyJSON(updated, 'boundaries',
      jsonEncode({'coordinates': coordinates}), 'String');
  updated = setSpecificPropertyJSON(
      updated, 'boundaryAccuracies', jsonEncode(edit.accuracies), 'String');
  updated = setSpecificPropertyJSON(updated, 'area', newArea, 'double');

  // Nachvollziehbar auch ohne Methodenhistorie: was wurde geändert.
  final note = 'QC boundary edit ${DateTime.now().toUtc().toIso8601String()}: '
      '${edit.summary}';
  updated = setSpecificPropertyJSON(
      updated, 'boundaryEditNotes', _appendNote(field, note), 'String');

  // Schwerpunkt nachziehen - er hängt an der Geometrie und wird an anderer
  // Stelle als Position des Feldes gelesen.
  final centroid = polygonCentroid(closed);
  final geolocation = updated['currentGeolocation'];
  if (geolocation is Map) {
    geolocation['geoCoordinates'] = {
      'latitude': centroid.latitude,
      'longitude': centroid.longitude,
    };
  }

  final reason = edit.reason.trim().isEmpty
      ? 'Boundary corrected in QC (${edit.summary})'
      : '${edit.reason.trim()} (${edit.summary})';
  await changeObjectData(updated,
      syncFromCloud: false,
      changeReason: reason,
      changeContext: changeContext,
      jobProperties: jobProperties);

  await _updateFarmTotalArea(field, previousArea, newArea);

  return updated;
}

double _readArea(Map<String, dynamic> field) => _readHectares(field, 'area');

double _readHectares(Map<String, dynamic> obj, String key) {
  final raw = getSpecificPropertyfromJSON(obj, key);
  if (raw is num) return raw.toDouble();
  if (raw is String && raw != '-no data found-') {
    return double.tryParse(raw) ?? 0.0;
  }
  return 0.0;
}

/// Fläche eines Feldes in Hektar, 0 wenn nicht erfasst.
double fieldAreaHa(Map<String, dynamic> field) => _readArea(field);

/// Die Farm mit um [delta] Hektar geänderter Gesamtfläche (nie negativ).
Map<String, dynamic> farmWithAdjustedTotalArea(
    Map<String, dynamic> farm, double delta) {
  final newTotal = _readHectares(farm, 'totalAreaHa') + delta;
  return setSpecificPropertyJSON(
      farm, 'totalAreaHa', newTotal < 0 ? 0.0 : newTotal, 'double');
}

/// Zieht die Gesamtfläche einer Farm um [delta] Hektar nach - als eigener,
/// signierter changeObjectData-Job mit [changeReason].
///
/// Setzt auf der aktuellen Fassung auf (lokal vor Cloud): direkt nach einem
/// QC-Job ist die Cloud noch nicht nachgezogen, und deren ältere Fassung würde
/// sonst die Entscheidung überschreiben.
Future<void> adjustFarmTotalArea(
  String farmUid,
  double delta, {
  required String changeReason,
}) async {
  if (delta == 0) return;
  final farm = await getCurrentObjectVersion(farmUid);
  if (farm.isEmpty) {
    debugPrint('Field geometry: farm $farmUid not found, area not adjusted');
    return;
  }
  await changeObjectData(farmWithAdjustedTotalArea(deepCopyMap(farm), delta),
      syncFromCloud: false,
      changeReason: changeReason,
      changeContext: changeContextQcCorrection);
}

String _appendNote(Map<String, dynamic> field, String note) {
  final previous = getSpecificPropertyfromJSON(field, 'boundaryEditNotes');
  if (previous == null ||
      previous == '-no data found-' ||
      previous.toString().trim().isEmpty) {
    return note;
  }
  return '$previous\n$note';
}

/// Zieht die Gesamtfläche der verknüpften Farm um die Differenz nach.
///
/// Die Erfassung addiert die Fläche jedes neuen Feldes auf `totalAreaHa` der
/// Farm; ohne diesen Schritt würde die Summe nach einer Korrektur auseinander
/// laufen. Scheitert der Schritt, bleibt die Feldänderung trotzdem gültig - sie
/// ist zu diesem Zeitpunkt bereits geschrieben und signiert.
Future<void> _updateFarmTotalArea(
  Map<String, dynamic> field,
  double previousArea,
  double newArea,
) async {
  final delta = newArea - previousArea;
  if (delta == 0) return;

  try {
    final farmUid = _linkedFarmUid(field);
    if (farmUid == null) {
      debugPrint('Field geometry: no linked farm, total area not adjusted');
      return;
    }

    final farmDoc = await FirebaseFirestore.instance
        .collection('TFC_objects')
        .doc(farmUid)
        .get();
    if (!farmDoc.exists || farmDoc.data() == null) {
      debugPrint('Field geometry: linked farm $farmUid not found');
      return;
    }

    final farm = Map<String, dynamic>.from(farmDoc.data()!);
    final updatedFarm = farmWithAdjustedTotalArea(farm, delta);

    await changeObjectData(updatedFarm,
        syncFromCloud: false,
        changeReason: 'Total area adjusted after boundary correction of field '
            '${field['identity']?['name'] ?? field['identity']?['UID']}',
        changeContext: changeContextQcCorrection);
    debugPrint('Field geometry: farm $farmUid total area adjusted by '
        '$delta ha');
  } catch (e) {
    debugPrint('Field geometry: could not adjust farm total area: $e');
  }
}

String? _linkedFarmUid(Map<String, dynamic> field) {
  final links = field['linkedObjectRef'];
  if (links is! List) return null;
  for (final link in links) {
    if (link is Map && link['RALType'] == 'farm') {
      final uid = link['UID']?.toString();
      if (uid != null && uid.isNotEmpty) return uid;
    }
  }
  return null;
}

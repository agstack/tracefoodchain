import 'dart:convert';

import 'package:trace_foodchain_app/services/open_ral_service.dart';

/// Einzelne Prüfpunkte des Vertrauens- und Qualitätslabels eines Feldes.
enum FieldTrustCriterion {
  /// Das Feld wurde in der QC freigegeben (objectState == 'active').
  qcApproved,

  /// Die Freigabe ist als signierter performQualityControl-Job dokumentiert.
  qcSigned,

  /// Die Asset Registry hat eine GeoID vergeben.
  geoId,

  /// Es gibt ein auswertbares Polygon mit mindestens drei Punkten.
  polygon,

  /// Das Polygon wurde aufgenommen und nicht aus einem Mittelpunkt konstruiert.
  surveyedPolygon,

  /// Eine Fläche > 0 ist angegeben.
  area,

  /// Das Feld hängt an einer auffindbaren Farm.
  farm,

  /// Die Farm hat einen auffindbaren Farmer als Owner.
  farmer,

  /// Ein Foto der Feldregistrierung ist verknüpft.
  photo,
}

enum FieldTrustLevel { high, medium, low }

class FieldTrustAssessment {
  const FieldTrustAssessment(this.met);

  /// Erfüllt (true) oder nicht erfüllt (false), je Prüfpunkt.
  final Map<FieldTrustCriterion, bool> met;

  int get metCount => met.values.where((v) => v).length;
  int get total => met.length;

  bool has(FieldTrustCriterion c) => met[c] ?? false;

  /// - hoch:    freigegeben, vermessenes Polygon, GeoID, Farm und Farmer
  /// - mittel:  freigegeben und mit Polygon, aber etwas davon fehlt
  /// - niedrig: nicht freigegeben oder ohne Polygon
  FieldTrustLevel get level {
    if (!has(FieldTrustCriterion.qcApproved) ||
        !has(FieldTrustCriterion.polygon)) {
      return FieldTrustLevel.low;
    }
    const required = [
      FieldTrustCriterion.surveyedPolygon,
      FieldTrustCriterion.geoId,
      FieldTrustCriterion.farm,
      FieldTrustCriterion.farmer,
    ];
    return required.every(has) ? FieldTrustLevel.high : FieldTrustLevel.medium;
  }
}

/// UID der Farm, an der ein Feld hängt - über den Container oder den Link.
String? farmUidOfField(Map<String, dynamic> field) {
  final container =
      field['currentGeolocation']?['container']?['UID']?.toString();
  if (container != null && container.isNotEmpty && container != 'unknown') {
    return container;
  }
  final links = field['linkedObjectRef'];
  if (links is List) {
    for (final link in links) {
      if (link is Map && link['RALType'] == 'farm') {
        final uid = link['UID']?.toString();
        if (uid != null && uid.isNotEmpty) return uid;
      }
    }
  }
  return null;
}

/// UID des Farmers, der als Owner an der Farm verlinkt ist.
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

bool _hasGeoId(Map<String, dynamic> field) {
  final altIds = field['identity']?['alternateIDs'];
  if (altIds is! List) return false;
  return altIds.any((id) =>
      id is Map &&
      id['issuedBy'] == 'Asset Registry' &&
      (id['UID']?.toString().isNotEmpty ?? false));
}

bool _hasPolygon(Map<String, dynamic> field) {
  final raw = getSpecificPropertyfromJSON(field, 'boundaries');
  if (raw == null || raw.toString().isEmpty) return false;
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    var coords = decoded is Map ? decoded['coordinates'] : decoded;
    // Polygon: [[[lng, lat], ...]] - bis auf die Punktliste auspacken.
    while (coords is List &&
        coords.isNotEmpty &&
        coords.first is List &&
        (coords.first as List).isNotEmpty &&
        (coords.first as List).first is List) {
      coords = coords.first;
    }
    return coords is List && coords.length >= 3;
  } catch (_) {
    return false;
  }
}

bool _hasArea(Map<String, dynamic> field) {
  final raw = getSpecificPropertyfromJSON(field, 'area');
  final value = raw is num ? raw : double.tryParse(raw?.toString() ?? '');
  return value != null && value > 0;
}

bool _isPseudoPolygon(Map<String, dynamic> field) {
  final source = getSpecificPropertyfromJSON(field, 'boundarySource');
  return source != null && source.toString().startsWith('pseudoPolygon');
}

bool _hasMethod(Map<String, dynamic> field, String ralType) {
  final history = field['methodHistoryRef'];
  if (history is! List) return false;
  return history.any((m) => m is Map && m['RALType'] == ralType);
}

bool _hasLinkedPhoto(Map<String, dynamic> field) {
  final links = field['linkedObjectRef'];
  if (links is! List) return false;
  return links.any((l) =>
      l is Map && l['RALType'] == 'image' && l['role'] == 'fieldRegistrationPhoto');
}

/// Bewertet, wie belastbar die Informationen zu einem Feld sind.
///
/// [farm] und [farmer] sind die tatsächlich gefundenen Objekte - ein Link auf
/// eine Farm, die es nicht gibt, zählt nicht als Zuordnung.
FieldTrustAssessment assessFieldTrust(
  Map<String, dynamic> field, {
  Map<String, dynamic>? farm,
  Map<String, dynamic>? farmer,
}) {
  final polygon = _hasPolygon(field);
  return FieldTrustAssessment({
    FieldTrustCriterion.qcApproved: field['objectState'] == 'active',
    FieldTrustCriterion.qcSigned: _hasMethod(field, 'performQualityControl'),
    FieldTrustCriterion.geoId: _hasGeoId(field),
    FieldTrustCriterion.polygon: polygon,
    FieldTrustCriterion.surveyedPolygon: polygon && !_isPseudoPolygon(field),
    FieldTrustCriterion.area: _hasArea(field),
    FieldTrustCriterion.farm: farm != null,
    FieldTrustCriterion.farmer: farmer != null,
    FieldTrustCriterion.photo: _hasLinkedPhoto(field),
  });
}

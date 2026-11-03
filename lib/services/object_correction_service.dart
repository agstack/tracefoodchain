import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/deep_copy_map.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import 'open_ral_service.dart';

/// Korrektur von Farmer-, Farm- und Felddaten samt Fotos.
///
/// Jede Korrektur wird als signierter changeObjectData-Job geschrieben, mit
/// Grund, Kontext und der Liste der geänderten Felder - siehe
/// [changeObjectData].

/// Korrigierbare Werte je Objekttyp, in der Reihenfolge der Eingabemaske.
const Map<String, List<String>> correctableFields = {
  'human': ['firstName', 'lastName', 'nationalID', 'phoneNumber'],
  'farm': ['farmName', 'farmID', 'stateName', 'municipalityName', 'cityName'],
  'field': ['fieldName'],
};

/// Fotorollen je Objekttyp.
const Map<String, List<String>> photoRolesByType = {
  'human': ['nationalIDPhoto'],
  'farm': ['consentFormPhoto', 'consentFormPhoto2'],
  'field': ['fieldRegistrationPhoto'],
};

/// Fotos, ohne die eine Registrierung nicht freigegeben werden kann. Die
/// zweite Aufnahme der Einverständniserklärung ist optional.
const Set<String> requiredPhotoRoles = {
  'nationalIDPhoto',
  'consentFormPhoto',
  'fieldRegistrationPhoto',
};

const String _nationalIdIssuer = 'National ID';
const String _farmRegistryIssuer = 'Farm Registry';

String _ralType(Map<String, dynamic> obj) =>
    obj['template']?['RALType']?.toString() ?? '';

String _text(dynamic value) {
  if (value == null || value == '-no data found-') return '';
  return value.toString();
}

String? _alternateId(Map<String, dynamic> obj, String issuer) {
  final altIds = obj['identity']?['alternateIDs'];
  if (altIds is! List) return null;
  for (final a in altIds) {
    if (a is Map && a['issuedBy'] == issuer) return a['UID']?.toString();
  }
  return null;
}

/// Setzt die Kennung von [issuer]; ein leerer Wert entfernt sie.
void _setAlternateId(Map<String, dynamic> obj, String issuer, String value) {
  final identity = obj['identity'] as Map;
  final altIds = (identity['alternateIDs'] as List?) ?? <dynamic>[];
  final index =
      altIds.indexWhere((a) => a is Map && a['issuedBy'] == issuer);
  if (value.isEmpty) {
    if (index >= 0) altIds.removeAt(index);
  } else if (index >= 0) {
    altIds[index]['UID'] = value;
  } else {
    altIds.add({'issuedBy': issuer, 'UID': value});
  }
  identity['alternateIDs'] = altIds;
}

Map _postalAddress(Map<String, dynamic> obj) {
  final geo = obj['currentGeolocation'] ??= <String, dynamic>{};
  return (geo as Map)['postalAddress'] ??= <String, dynamic>{};
}

/// Aktueller Wert eines korrigierbaren Feldes, '' wenn nicht gesetzt.
String readCorrectableValue(Map<String, dynamic> obj, String key) {
  switch (key) {
    case 'firstName':
    case 'lastName':
    case 'phoneNumber':
      return _text(getSpecificPropertyfromJSON(obj, key));
    case 'nationalID':
      return _alternateId(obj, _nationalIdIssuer) ?? '';
    case 'farmID':
      return _alternateId(obj, _farmRegistryIssuer) ?? '';
    case 'farmName':
    case 'fieldName':
      return _text(obj['identity']?['name']);
    case 'stateName':
    case 'municipalityName':
    case 'cityName':
      return _text(obj['currentGeolocation']?['postalAddress']?[key]);
  }
  return '';
}

/// Überträgt die geänderten [values] auf eine Kopie von [obj].
Map<String, dynamic> applyCorrectedValues(
  Map<String, dynamic> obj,
  Map<String, String> values,
) {
  var doc = deepCopyMap(obj);
  for (final MapEntry(:key, :value) in values.entries) {
    final v = value.trim();
    switch (key) {
      case 'firstName':
      case 'lastName':
      case 'phoneNumber':
        doc = setSpecificPropertyJSON(doc, key, v, 'String');
      case 'nationalID':
        _setAlternateId(doc, _nationalIdIssuer, v);
      case 'farmID':
        _setAlternateId(doc, _farmRegistryIssuer, v);
      case 'farmName':
      case 'fieldName':
        doc['identity']['name'] = v;
      case 'stateName':
      case 'municipalityName':
      case 'cityName':
        _postalAddress(doc)[key] = v;
    }
  }

  // Der Anzeigename des Farmers setzt sich aus Vor- und Nachname zusammen.
  if (_ralType(doc) == 'human' &&
      (values.containsKey('firstName') || values.containsKey('lastName'))) {
    doc['identity']['name'] = [
      readCorrectableValue(doc, 'firstName'),
      readCorrectableValue(doc, 'lastName'),
    ].where((s) => s.isNotEmpty).join(' ');
  }
  return doc;
}

/// Legt für [file] ein neues image-Objekt an (eigener, signierter
/// generateDigitalSibling-Job) und hängt es unter [role] an [doc] - ein
/// bisher verknüpftes Foto derselben Rolle wird dabei ersetzt.
///
/// [doc] muss anschließend noch über [changeObjectData] geschrieben werden:
/// erst damit ist die neue Verknüpfung signiert.
Future<void> attachPhotoByRole(
  Map<String, dynamic> doc, {
  required String role,
  required String imageName,
  required XFile file,
}) async {
  // On web the path is a blob URL that cannot be fetched back later, so the
  // bytes are read here while the file is still accessible.
  final imageObj = await createImageObject(
    localPath: file.path,
    position: null,
    imageName: imageName,
    bytes: kIsWeb ? await file.readAsBytes() : null,
  );

  final processedImage = jsonFullDoubleToInt(sortJsonAlphabetically(imageObj))
      as Map<String, dynamic>;
  await generateDigitalSibling(processedImage, syncFromCloud: false);

  final newImageUid = getObjectMethodUID(processedImage);

  final linkedRefs = (doc['linkedObjectRef'] as List?) ?? <dynamic>[];
  linkedRefs.removeWhere((ref) {
    if (ref is! Map) return false;
    return ref['RALType']?.toString() == 'image' &&
        ref['role']?.toString() == role;
  });
  linkedRefs.add({
    'UID': newImageUid,
    'RALType': 'image',
    'role': role,
  });
  doc['linkedObjectRef'] = linkedRefs;
}

/// Bildname eines Fotos - so wie ihn auch die Registrierung vergibt.
String photoImageName(String role, Map<String, dynamic> obj) {
  final name = _text(obj['identity']?['name']);
  return switch (role) {
    'nationalIDPhoto' => 'National ID - $name',
    'consentFormPhoto' => 'Consent Form - $name',
    'consentFormPhoto2' => 'Consent Form 2 - $name',
    'fieldRegistrationPhoto' => 'Field Photo - $name',
    _ => '$role - $name',
  };
}

/// Schreibt eine Korrektur von [current] als signierten changeObjectData-Job
/// und gibt die geschriebene Fassung zurück.
///
/// [values] enthält nur die geänderten Felder, [photos] die neuen Fotos je
/// Rolle. [reason] ist Pflicht - ohne Grund ist die Änderung im Audit nicht
/// nachvollziehbar.
Future<Map<String, dynamic>> saveObjectCorrection({
  required Map<String, dynamic> current,
  required Map<String, String> values,
  required Map<String, XFile> photos,
  required String reason,
  String changeContext = changeContextQcCorrection,
}) async {
  if (reason.trim().isEmpty) {
    throw ArgumentError('A correction needs a reason');
  }
  if (values.isEmpty && photos.isEmpty) {
    throw ArgumentError('A correction needs at least one change');
  }

  final updated = applyCorrectedValues(current, values);
  for (final MapEntry(key: role, value: file) in photos.entries) {
    await attachPhotoByRole(
      updated,
      role: role,
      imageName: photoImageName(role, updated),
      file: file,
    );
  }

  final processed = jsonFullDoubleToInt(sortJsonAlphabetically(updated))
      as Map<String, dynamic>;
  await changeObjectData(
    processed,
    syncFromCloud: false,
    changeReason: reason.trim(),
    changeContext: changeContext,
  );
  return getCurrentObjectVersion(getObjectMethodUID(processed));
}

import 'dart:convert';

import 'package:trace_foodchain_app/services/excel_farmer_import_service.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:uuid/uuid.dart';

/// TEMPORÄRER Importer, Teil 2: baut aus den eingelesenen Excel-Zeilen den
/// openRAL-Objektgraphen auf.
///
/// Der Aufbau folgt dem Registrar-Workflow
/// ([stepper_registrar_registration.dart] für farmer/farm,
/// [field_boundary_recorder.dart] für field), NICHT dem First-Sale-Pfad.
///
/// WICHTIG: Hier wird ausschließlich im Speicher gebaut. Es wird nichts
/// persistiert, nichts signiert und keine Methode ausgeführt - kein
/// setObjectMethod, kein generateDigitalSibling, kein updateMethodHistories.

/// Farmer plus zugehörige Farm und deren Felder.
class FarmerBundle {
  final Map<String, dynamic> farmer;
  final Map<String, dynamic> farm;
  final List<Map<String, dynamic>> fields;

  /// Die Excel-Zeilen, aus denen dieses Bündel entstanden ist.
  final List<ImportedPlotRow> sourceRows;

  const FarmerBundle({
    required this.farmer,
    required this.farm,
    required this.fields,
    required this.sourceRows,
  });

  String get personName => sourceRows.first.personName;
}

/// Vollständiger Objektgraph eines Import-Laufs.
class ImportObjectGraph {
  /// Intermediaries als company-Objekte, je Name genau eines.
  final List<Map<String, dynamic>> companies;

  final List<FarmerBundle> farmers;

  /// Hinweise auf getroffene Annahmen, die ein Mensch prüfen sollte.
  final List<String> notes;

  const ImportObjectGraph({
    required this.companies,
    required this.farmers,
    required this.notes,
  });

  int get fieldCount =>
      farmers.fold<int>(0, (sum, b) => sum + b.fields.length);
}

/// Zerlegt einen spanischen Namen heuristisch in Vor- und Nachname.
///
/// Konvention: Vorname(n) + Vatername + Muttername. Ab drei Bestandteilen
/// werden die letzten beiden als Nachname gewertet, bei zweien der letzte.
/// Das ist eine Heuristik - `identity.name` bleibt der maßgebliche Wert.
({String firstName, String lastName}) splitSpanishName(String fullName) {
  final parts =
      fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return (firstName: '', lastName: '');
  if (parts.length == 1) return (firstName: parts.first, lastName: '');
  if (parts.length == 2) {
    return (firstName: parts.first, lastName: parts.last);
  }
  return (
    firstName: parts.sublist(0, parts.length - 2).join(' '),
    lastName: parts.sublist(parts.length - 2).join(' '),
  );
}

/// Mittelpunkt mehrerer Plot-Centroide - nur zur groben Verortung der Farm.
({double latitude, double longitude}) _averageCentroid(
    List<ImportedPlotRow> rows) {
  double lat = 0, lon = 0;
  for (final r in rows) {
    lat += r.latitude;
    lon += r.longitude;
  }
  return (latitude: lat / rows.length, longitude: lon / rows.length);
}

/// Häufigster nicht-leerer Wert einer Eigenschaft über mehrere Zeilen.
String _dominant(List<ImportedPlotRow> rows, String Function(ImportedPlotRow) f) {
  final counts = <String, int>{};
  for (final r in rows) {
    final v = f(r);
    if (v.isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return '';
  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return sorted.first.key;
}

/// Baut den Objektgraphen: je Person ein farmer (human) mit genau einer farm,
/// je Excel-Zeile ein field, je Intermediary ein company.
///
/// [registrarUID] ist der importierende App-User; er wird - wie im
/// Registrar-Workflow - currentOwner von farmer, farm und company.
/// Der currentOwner des Feldes ist dagegen die Farm.
/// [ihcafeByPerson] ordnet einem Personennamen den bestätigten IHCafe-Produzenten
/// zu. Übernommen werden daraus ausschließlich clave und productor_id am Farmer
/// sowie finca_id an der Farm, jeweils mit issuedBy "IHCafe" - alle übrigen
/// IHCafe-Felder bleiben im lokalen Verzeichnis.
Future<ImportObjectGraph> buildImportObjects({
  required List<ImportedPlotRow> plots,
  required String registrarUID,
  Map<String, IhcafeProducer> ihcafeByPerson = const {},
  String country = 'Honduras',
  String objectState = 'qcPending',
}) async {
  const uuid = Uuid();
  final notes = <String>[];
  final now = DateTime.now().toUtc().toIso8601String();

  // ── 1. Intermediaries als company-Objekte ───────────────────────────────
  // Buyer ist in der Quelldatei ein Logo-Dateiname und hängt 1:1 am
  // Intermediary - er wandert daher als companyLogo an dieselbe Firma.
  final companiesByName = <String, Map<String, dynamic>>{};
  for (final p in plots) {
    if (p.intermediary.isEmpty) continue;
    if (companiesByName.containsKey(p.intermediary)) continue;

    Map<String, dynamic> company = await getOpenRALTemplate('company');
    if (company.isEmpty) {
      throw StateError(
          'openRAL-Template "company" nicht verfügbar (Templates geladen?)');
    }
    setObjectMethodUID(company, uuid.v4());
    company['identity']['name'] = p.intermediary;
    company['objectState'] = objectState;
    company['existenceStarts'] = now;
    if (p.buyer.isNotEmpty) {
      company = setSpecificPropertyJSON(company, 'companyLogo', p.buyer, 'URL');
    }
    company['currentGeolocation']['postalAddress']['country'] = country;
    company['currentOwners'] = [
      {'UID': registrarUID, 'role': 'registrar'}
    ];
    company['linkedObjectRef'].add({
      'UID': registrarUID,
      'RALType': 'human',
      'role': 'registrar',
    });
    companiesByName[p.intermediary] = company;
  }
  if (companiesByName.isNotEmpty) {
    notes.add('Intermediaries werden als company-Objekte angelegt '
        '(${companiesByName.keys.join(', ')}). Die Buyer-Spalte enthält einen '
        'Logo-Dateinamen und wird als companyLogo an derselben Firma abgelegt.');
  }

  // ── 2. Gruppierung: Farm = Farmer ───────────────────────────────────────
  // Identität über den Namen, da der DNI in der Quelldatei auf 3 signifikante
  // Stellen gerundet und damit unbrauchbar ist.
  final rowsByPerson = <String, List<ImportedPlotRow>>{};
  for (final p in plots) {
    rowsByPerson.putIfAbsent(p.personName, () => []).add(p);
  }
  final multiPlot =
      rowsByPerson.entries.where((e) => e.value.length > 1).toList();
  if (multiPlot.isNotEmpty) {
    notes.add('${multiPlot.length} Personen haben mehrere Plots und bekommen '
        'eine Farm mit mehreren Feldern: '
        '${multiPlot.map((e) => '${e.key} (${e.value.length})').join(', ')}. '
        'Ob es sich wirklich um dieselbe Person handelt, ist über den Namen '
        'allein nicht belegbar.');
  }

  final bundles = <FarmerBundle>[];

  for (final entry in rowsByPerson.entries) {
    final personName = entry.key;
    final rows = entry.value;
    final farmerUID = uuid.v4();
    final farmUID = uuid.v4();

    final municipality = _dominant(rows, (r) => r.municipality);
    final community = _dominant(rows, (r) => r.community);
    final intermediary = _dominant(rows, (r) => r.intermediary);
    final centroid = _averageCentroid(rows);

    // ── 2a. Farmer (human) ────────────────────────────────────────────
    Map<String, dynamic> farmer = await getOpenRALTemplate('human');
    if (farmer.isEmpty) {
      throw StateError('openRAL-Template "human" nicht verfügbar');
    }
    setObjectMethodUID(farmer, farmerUID);
    farmer['identity']['name'] = personName;
    farmer['objectState'] = objectState;
    farmer['existenceStarts'] = now;

    final name = splitSpanishName(personName);
    farmer = setSpecificPropertyJSON(farmer, 'firstName', name.firstName, 'String');
    farmer = setSpecificPropertyJSON(farmer, 'lastName', name.lastName, 'String');
    farmer = setSpecificPropertyJSON(farmer, 'userRole', 'Farmer', 'String');

    // Bewusst KEIN nationalID aus der Excel-Spalte: der DNI der Quelldatei ist
    // auf 3 signifikante Stellen gerundet. Ein falscher Ausweis ist schlechter
    // als gar keiner - der belastbare Wert kommt aus dem IHCafe-Match.
    final producer = ihcafeByPerson[personName];
    if (producer != null) {
      if (producer.identidad.isNotEmpty) {
        farmer['identity']['alternateIDs'].add({
          'UID': producer.identidad,
          'issuedBy': 'National ID',
        });
      }
      if (producer.clave.isNotEmpty) {
        farmer['identity']['alternateIDs'].add({
          'UID': producer.clave,
          'issuedBy': 'IHCafe',
        });
      }
      if (producer.productorId != null) {
        farmer['identity']['alternateIDs'].add({
          'UID': '${producer.productorId}',
          'issuedBy': 'IHCafe',
        });
      }
    }

    farmer['currentGeolocation']['geoCoordinates'] = {
      'latitude': centroid.latitude,
      'longitude': centroid.longitude,
    };
    farmer['currentGeolocation']['postalAddress']['country'] = country;
    if (municipality.isNotEmpty) {
      farmer['currentGeolocation']['postalAddress']['municipalityName'] =
          municipality;
    }
    if (community.isNotEmpty) {
      farmer['currentGeolocation']['postalAddress']['cityName'] = community;
    }
    farmer['currentOwners'] = [
      {'UID': registrarUID, 'role': 'registrar'}
    ];
    farmer['linkedObjectRef'].add({
      'UID': registrarUID,
      'RALType': 'human',
      'role': 'registrar',
    });

    // ── 2b. Farm (Farm = Farmer) ──────────────────────────────────────
    Map<String, dynamic> farm = await getOpenRALTemplate('farm');
    if (farm.isEmpty) {
      throw StateError('openRAL-Template "farm" nicht verfügbar');
    }
    setObjectMethodUID(farm, farmUID);
    farm['identity']['name'] = personName;
    farm['objectState'] = objectState;
    farm['existenceStarts'] = now;

    // finca_id nur übernehmen, wenn sie eindeutig ist. Hat der Produzent
    // mehrere Fincas, lässt sich ohne Rückfrage nicht entscheiden, welche zu
    // dieser Farm gehört - das wird gemeldet statt geraten.
    if (producer != null) {
      final fincaIds =
          producer.fincas.map((f) => f.fincaId).whereType<int>().toList();
      if (fincaIds.length == 1) {
        farm['identity']['alternateIDs'].add({
          'UID': '${fincaIds.first}',
          'issuedBy': 'IHCafe',
        });
      } else if (fincaIds.length > 1) {
        notes.add('${producer.nombreCompleto} hat ${fincaIds.length} Fincas '
            'bei IHCafe (${fincaIds.join(', ')}). Die finca_id wurde NICHT '
            'gesetzt, weil nicht entscheidbar ist, welche zu dieser Farm '
            'gehört.');
      }
    }

    farm['linkedObjectRef'].add({
      'UID': farmerUID,
      'RALType': 'human',
      'role': 'owner',
    });
    farm['linkedObjectRef'].add({
      'UID': registrarUID,
      'RALType': 'human',
      'role': 'registrar',
    });

    // Intermediary NICHT als Käufer, sondern als bevorzugter Vermittler.
    final company = companiesByName[intermediary];
    if (company != null) {
      farm['linkedObjectRef'].add({
        'UID': getObjectMethodUID(company),
        'RALType': 'company',
        'role': 'preferredIntermediary',
      });
    }

    // totalAreaHa ist die Summe der Feldflächen - dieselbe Semantik, die
    // field_boundary_recorder beim Anlegen eines Feldes fortschreibt.
    // totalAreaEstimatedHa bleibt leer: das ist im Registrar-Workflow die
    // separat erfragte Schätzung des Bauern, für die es hier keine Entsprechung
    // gibt.
    final totalArea = rows.fold<double>(0, (sum, r) => sum + r.areaHectares);
    farm = setSpecificPropertyJSON(farm, 'farmerCount', 1, 'int');
    farm = setSpecificPropertyJSON(farm, 'totalAreaHa', totalArea, 'double');

    farm['currentGeolocation']['geoCoordinates'] = {
      'latitude': centroid.latitude,
      'longitude': centroid.longitude,
    };
    farm['currentGeolocation']['postalAddress']['country'] = country;
    if (municipality.isNotEmpty) {
      farm['currentGeolocation']['postalAddress']['municipalityName'] =
          municipality;
    }
    if (community.isNotEmpty) {
      farm['currentGeolocation']['postalAddress']['cityName'] = community;
    }
    farm['currentOwners'] = [
      {'UID': registrarUID, 'role': 'registrar'}
    ];

    // ── 2c. Felder ────────────────────────────────────────────────────
    final fields = <Map<String, dynamic>>[];
    for (final row in rows) {
      Map<String, dynamic> field = await getOpenRALTemplate('field');
      if (field.isEmpty) {
        throw StateError('openRAL-Template "field" nicht verfügbar');
      }
      setObjectMethodUID(field, uuid.v4());
      field['identity']['name'] = row.fieldName;
      field['objectState'] = objectState;
      field['existenceStarts'] = now;

      // Tote Asset-Registry-GeoID nur dokumentieren, nicht auflösen.
      for (final alt in row.plannedAlternateIds) {
        field['identity']['alternateIDs'].add(alt);
      }

      field = setSpecificPropertyJSON(field, 'boundaries',
          jsonEncode({'coordinates': row.polygon}), 'String');
      // Einheit-Parameter analog zum Registrar-Pfad ('double'); der Wert ist
      // in Hektar, weil field_boundary_recorder die Feldflächen genau so in
      // totalAreaHa der Farm aufsummiert.
      field = setSpecificPropertyJSON(field, 'area', row.areaHectares, 'double');

      // Kennzeichnung, dass die Grenze konstruiert und nicht vermessen ist -
      // ohne diese Markierung wäre ein Pseudo-Polygon später nicht mehr von
      // einer echten GPS-Aufnahme zu unterscheiden.
      field = setSpecificPropertyJSON(field, 'boundarySource',
          'pseudoPolygonFromCentroid (excel import)', 'String');

      field['currentGeolocation']['container']['UID'] = farmUID;
      field['linkedObjectRef'].add({
        'UID': farmUID,
        'RALType': 'farm',
        'role': 'location',
      });
      field['currentGeolocation']['geoCoordinates'] = {
        'latitude': row.latitude,
        'longitude': row.longitude,
      };
      field['currentGeolocation']['postalAddress']['country'] = country;
      if (row.municipality.isNotEmpty) {
        field['currentGeolocation']['postalAddress']['municipalityName'] =
            row.municipality;
      }
      if (row.community.isNotEmpty) {
        field['currentGeolocation']['postalAddress']['cityName'] =
            row.community;
      }

      // Owner des Feldes ist die Farm.
      field['currentOwners'] = [
        {'UID': farmUID, 'role': 'owner'}
      ];

      fields.add(field);
    }

    bundles.add(FarmerBundle(
      farmer: farmer,
      farm: farm,
      fields: fields,
      sourceRows: rows,
    ));
  }

  notes.add('Felder tragen die specificProperty "boundarySource", damit '
      'Pseudo-Polygone später von vermessenen Grenzen unterscheidbar bleiben.');
  notes.add('Vor-/Nachname werden heuristisch getrennt (letzte zwei '
      'Bestandteile = Nachname); identity.name bleibt maßgeblich.');
  notes.add('Alle Objekte erhalten objectState "$objectState" - sie laufen '
      'damit wie Registrar-Registrierungen durch die QC.');

  return ImportObjectGraph(
    companies: companiesByName.values.toList(),
    farmers: bundles,
    notes: notes,
  );
}

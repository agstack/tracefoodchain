import 'package:trace_foodchain_app/services/excel_farmer_import_service.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

/// Gleicht importierte Personen mit dem IHCafe-Verzeichnis ab.
///
/// Zweck ist vor allem, den vollständigen DNI ("identidad") zu gewinnen - in
/// der Excel-Quelldatei ist er auf drei signifikante Stellen gerundet und damit
/// unbrauchbar.

enum IhcafeMatchQuality {
  /// Genau ein Kandidat, dessen Finca im selben Municipio liegt.
  confirmed,

  /// Genau ein Kandidat, aber ohne geografische Bestätigung.
  nameOnly,

  /// Mehrere Kandidaten - ohne weitere Angaben nicht entscheidbar.
  ambiguous,

  /// Kein Kandidat gefunden.
  none,
}

class IhcafeMatch {
  final String personName;
  final String municipality;
  final IhcafeMatchQuality quality;

  /// Bei [IhcafeMatchQuality.confirmed] und [IhcafeMatchQuality.nameOnly] der
  /// eindeutige Treffer, sonst null.
  final IhcafeProducer? best;

  /// Alle Namenskandidaten, auch bei Mehrdeutigkeit.
  final List<IhcafeProducer> candidates;

  final String reason;

  const IhcafeMatch({
    required this.personName,
    required this.municipality,
    required this.quality,
    required this.best,
    required this.candidates,
    required this.reason,
  });
}

class IhcafeMatchReport {
  final List<IhcafeMatch> matches;

  /// Municipios der Importdaten, die im Katalog überhaupt nicht vorkommen.
  final List<String> municipalitiesOutsideCatalog;

  /// True, wenn KEIN einziges Municipio der Importdaten im Katalog vorkommt -
  /// dann ist mit hoher Wahrscheinlichkeit der falsche Export geladen.
  final bool scopeMismatch;

  const IhcafeMatchReport({
    required this.matches,
    required this.municipalitiesOutsideCatalog,
    required this.scopeMismatch,
  });

  int countOf(IhcafeMatchQuality q) =>
      matches.where((m) => m.quality == q).length;
}

/// Eine zu prüfende Person aus dem Import.
class PersonToMatch {
  final String name;
  final String municipality;
  const PersonToMatch({required this.name, required this.municipality});
}

/// Sammelt die eindeutigen Personen aus den eingelesenen Excel-Zeilen.
List<PersonToMatch> personsFromPlots(List<ImportedPlotRow> plots) {
  final byName = <String, PersonToMatch>{};
  for (final p in plots) {
    if (p.personName.trim().isEmpty) continue;
    byName.putIfAbsent(
        p.personName,
        () => PersonToMatch(
              name: p.personName,
              municipality: p.municipality,
            ));
  }
  return byName.values.toList();
}

IhcafeMatchReport matchPersonsAgainstCatalog({
  required IhcafeCatalog catalog,
  required List<PersonToMatch> persons,
}) {
  // Municipios des Katalogs einmalig als Vergleichsschlüssel vorbereiten.
  final catalogMunicipioKeys =
      catalog.municipios.map(placeKey).where((k) => k.isNotEmpty).toSet();

  final importMunicipalities = persons
      .map((p) => p.municipality)
      .where((m) => m.trim().isNotEmpty)
      .toSet();
  final outside = importMunicipalities
      .where((m) => !catalogMunicipioKeys.contains(placeKey(m)))
      .toList()
    ..sort();
  final scopeMismatch = importMunicipalities.isNotEmpty &&
      outside.length == importMunicipalities.length;

  final matches = <IhcafeMatch>[];

  for (final person in persons) {
    final key = personNameKey(person.name);

    // Erst der exakte Namensschlüssel, dann die Token-Menge als Rückfallebene
    // (fängt vertauschte Namensbestandteile ab).
    var candidates = catalog.byNameKey[key] ?? const <IhcafeProducer>[];
    var viaTokenSet = false;
    if (candidates.isEmpty && key.isNotEmpty) {
      final tokenKey = (key.split(' ')..sort()).join(' ');
      candidates = catalog.byTokenSet[tokenKey] ?? const <IhcafeProducer>[];
      viaTokenSet = candidates.isNotEmpty;
    }

    if (candidates.isEmpty) {
      matches.add(IhcafeMatch(
        personName: person.name,
        municipality: person.municipality,
        quality: IhcafeMatchQuality.none,
        best: null,
        candidates: const [],
        reason: 'no producer with this name in the catalog',
      ));
      continue;
    }

    // Geografische Bestätigung über das Municipio der Finca.
    final munKey = placeKey(person.municipality);
    final geoConfirmed = munKey.isEmpty
        ? const <IhcafeProducer>[]
        : candidates
            .where((c) => c.municipios.map(placeKey).contains(munKey))
            .toList();

    if (geoConfirmed.length == 1) {
      matches.add(IhcafeMatch(
        personName: person.name,
        municipality: person.municipality,
        quality: IhcafeMatchQuality.confirmed,
        best: geoConfirmed.first,
        candidates: candidates,
        reason: viaTokenSet
            ? 'name tokens match, municipio confirms'
            : 'name and municipio match',
      ));
      continue;
    }

    if (geoConfirmed.length > 1) {
      matches.add(IhcafeMatch(
        personName: person.name,
        municipality: person.municipality,
        quality: IhcafeMatchQuality.ambiguous,
        best: null,
        candidates: geoConfirmed,
        reason: '${geoConfirmed.length} producers share this name in the '
            'same municipio',
      ));
      continue;
    }

    if (candidates.length == 1) {
      matches.add(IhcafeMatch(
        personName: person.name,
        municipality: person.municipality,
        quality: IhcafeMatchQuality.nameOnly,
        best: candidates.first,
        candidates: candidates,
        reason: munKey.isEmpty
            ? 'single name match, no municipio in the import data'
            : 'single name match, but municipio differs '
                '(${candidates.first.municipios.join('/')})',
      ));
      continue;
    }

    matches.add(IhcafeMatch(
      personName: person.name,
      municipality: person.municipality,
      quality: IhcafeMatchQuality.ambiguous,
      best: null,
      candidates: candidates,
      reason: '${candidates.length} producers share this name, municipio does '
          'not disambiguate',
    ));
  }

  return IhcafeMatchReport(
    matches: matches,
    municipalitiesOutsideCatalog: outside,
    scopeMismatch: scopeMismatch,
  );
}

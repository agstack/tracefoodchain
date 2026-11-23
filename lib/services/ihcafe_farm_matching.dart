import 'dart:math' as math;

import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

/// Abgleich bereits QC-geprüfter Farmen (samt Farmer) mit dem IHCafe-Export.
///
/// Ziel: an Farmer und Farm die IHCafe-Kennungen als alternateIDs setzen -
/// am Farmer `clave` und `productor_id`, an der Farm die `finca_id`, jeweils
/// mit `issuedBy: 'IHCafe'` und `idName` (dieselbe Konvention wie bei der
/// Registrierung über das Verzeichnis und beim Fast Upload, siehe
/// [ihcafeAlternateId]). Der DNI wird nie übernommen.
///
/// Vorhandene IHCafe-Einträge ohne `idName` (aus der Zeit vor diesem Feld)
/// werden beim Schreiben nachgetragen.
///
/// Diese Datei ist reine Logik ohne Firebase, damit sie testbar bleibt. Das
/// Laden der Farmen und das Schreiben liegen in `ihcafe_qc_farm_loader.dart`.
///
/// Reihenfolge der Kriterien, vom belastbarsten zum schwächsten:
/// 1. Farmer trägt bereits eine IHCafe-Kennung -> nur noch die Finca fehlt ggf.
/// 2. DNI (National ID) stimmt exakt mit `identidad` überein.
/// 3. Name exakt (bzw. gleiche Namensbestandteile) und Municipio bestätigt.
/// 4. Name unscharf (Tippfehler, fehlende Zweitnamen) und im Municipio
///    eindeutig.
/// 4b. Name im Municipio mehrdeutig, aber nur ein Kandidat hat eine Finca,
///    deren Name zu Farmname oder Aldea der Farm passt.
/// 5. Name eindeutig im ganzen Export, Municipio passt aber nicht.
/// Alles, was mehrdeutig ist oder einem anderen Kriterium widerspricht, wird
/// gemeldet statt geraten.

const String nationalIdIssuer = 'National ID';

enum IhcafeLinkLevel {
  /// Farmer trägt schon eine IHCafe-Kennung; ggf. fehlt nur die finca_id.
  alreadyLinked,

  /// DNI identisch, Name plausibel.
  dni,

  /// DNI identisch, aber der Name weicht stark ab - Tippfehler im DNI oder
  /// falsch zugeordnete Person.
  dniNameMismatch,

  /// Name (exakt oder gleiche Bestandteile) und Municipio bestätigen sich.
  nameMunicipio,

  /// Unscharfer Name, im Municipio aber eindeutig.
  nameFuzzy,

  /// Name im Municipio mehrdeutig, aber nur bei einem Kandidaten passt der
  /// Finca-Name zu Farmname oder Aldea der Farm.
  nameFinca,

  /// Name im Export eindeutig, Municipio fehlt oder passt nicht.
  nameOnly,

  /// Der Farmer hat einen DNI, der zum Namenstreffer nicht passt.
  conflict,

  /// Mehrere Produzenten kommen in Frage.
  ambiguous,

  /// Derselbe Produzent wurde mehreren Farmern zugeordnet.
  duplicate,

  /// Municipio der Farm liegt außerhalb des Exports.
  outOfScope,

  /// Kein Kandidat.
  none,
}

/// Stufen, die standardmäßig geschrieben werden dürfen.
const Set<IhcafeLinkLevel> defaultApplyLevels = {
  IhcafeLinkLevel.alreadyLinked,
  IhcafeLinkLevel.dni,
  IhcafeLinkLevel.nameMunicipio,
};

/// Stufen, die überhaupt einen Produzenten liefern und damit schreibbar sind.
const Set<IhcafeLinkLevel> applicableLevels = {
  IhcafeLinkLevel.alreadyLinked,
  IhcafeLinkLevel.dni,
  IhcafeLinkLevel.dniNameMismatch,
  IhcafeLinkLevel.nameMunicipio,
  IhcafeLinkLevel.nameFuzzy,
  IhcafeLinkLevel.nameFinca,
  IhcafeLinkLevel.nameOnly,
};

/// Eine geprüfte Farm mit ihrem Farmer, auf die Vergleichswerte reduziert.
class FarmToMatch {
  final String farmUid;
  final String farmName;
  final String? farmerUid;
  final String farmerName;

  /// National ID des Farmers, so wie gespeichert.
  final String nationalId;

  /// Municipio/Departamento/Aldea der Farm (ersatzweise des Farmers).
  final String municipio;
  final String departamento;
  final String aldea;

  /// Vorhandene alternateIDs mit issuedBy IHCafe.
  final List<String> farmerIhcafeIds;
  final List<String> farmIhcafeIds;

  /// Teilmenge davon ohne `idName` - wird beim Schreiben nachgetragen.
  final List<String> farmerIhcafeIdsWithoutName;
  final List<String> farmIhcafeIdsWithoutName;

  const FarmToMatch({
    required this.farmUid,
    required this.farmName,
    required this.farmerUid,
    required this.farmerName,
    this.nationalId = '',
    this.municipio = '',
    this.departamento = '',
    this.aldea = '',
    this.farmerIhcafeIds = const [],
    this.farmIhcafeIds = const [],
    this.farmerIhcafeIdsWithoutName = const [],
    this.farmIhcafeIdsWithoutName = const [],
  });
}

/// Eine geplante alternateID.
class PlannedAltId {
  final String uid;
  final String issuedBy;
  final String label; // 'clave', 'productor_id', 'finca_id' -> idName

  /// Die Kennung steht schon am Objekt, nur `idName` fehlt noch.
  final bool onlyName;

  const PlannedAltId(this.uid, this.label,
      {this.issuedBy = ihcafeIssuer, this.onlyName = false});

  Map<String, String> toJson() => issuedBy == ihcafeIssuer
      ? ihcafeAlternateId(uid, label)
      : {'UID': uid, 'issuedBy': issuedBy};
}

class IhcafeFarmMatch {
  final FarmToMatch farm;
  IhcafeLinkLevel level;

  /// Stufe vor einer nachträglichen Herabstufung (z.B. [IhcafeLinkLevel.duplicate]).
  IhcafeLinkLevel? originalLevel;

  final IhcafeProducer? producer;
  IhcafeFinca? finca;

  /// Weitere Kandidaten (für mehrdeutige Fälle und das Log), höchstens fünf.
  final List<IhcafeProducer> candidates;

  /// Ähnlichster Name, wenn nichts gefunden wurde - nur zur Diagnose.
  final IhcafeProducer? bestGuess;
  final double bestGuessScore;

  /// Namensähnlichkeit Farmer <-> Produzent (0..1).
  final double nameScore;

  /// Nachvollziehbare Begründung, Zeile für Zeile.
  final List<String> reasons;

  final List<PlannedAltId> farmerAdds;
  final List<PlannedAltId> farmAdds;

  IhcafeFarmMatch({
    required this.farm,
    required this.level,
    this.producer,
    this.finca,
    List<IhcafeProducer>? candidates,
    this.bestGuess,
    this.bestGuessScore = 0,
    this.nameScore = 0,
    List<String>? reasons,
    List<PlannedAltId>? farmerAdds,
    List<PlannedAltId>? farmAdds,
  })  : candidates = candidates ?? [],
        reasons = reasons ?? [],
        farmerAdds = farmerAdds ?? [],
        farmAdds = farmAdds ?? [];

  bool get hasChanges => farmerAdds.isNotEmpty || farmAdds.isNotEmpty;

  bool isApplicable(Set<IhcafeLinkLevel> allowed) =>
      producer != null && hasChanges && allowed.contains(level);
}

// ── Namensvergleich ─────────────────────────────────────────────────────────

List<String> _tokens(String name) =>
    personNameKey(name).split(' ').where((t) => t.isNotEmpty).toList();

String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[b.length];
}

/// Zwei Namensbestandteile gelten als gleich bei Identität oder einem
/// Tippfehler (ab 4 Zeichen ein, ab 8 Zeichen zwei Abweichungen).
bool _tokenEquals(String a, String b) {
  if (a == b) return true;
  final shorter = math.min(a.length, b.length);
  if (shorter < 4) return false;
  if ((a.length - b.length).abs() > 2) return false;
  final allowed = shorter >= 8 ? 2 : 1;
  return _levenshtein(a, b) <= allowed;
}

/// Ergebnis eines Namensvergleichs.
class NameSimilarity {
  /// Anteil gleicher Bestandteile am längeren Namen (0..1).
  final double score;

  /// Alle Bestandteile des kürzeren Namens kommen im längeren vor (bei
  /// mindestens zwei Bestandteilen) - typisch für fehlende Zweitnamen.
  final bool subset;

  /// Mindestens ein Bestandteil stimmte nur unscharf überein.
  final bool fuzzy;

  const NameSimilarity(this.score, this.subset, this.fuzzy);
}

NameSimilarity compareNames(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return const NameSimilarity(0, false, false);
  final (short, long) = a.length <= b.length ? (a, b) : (b, a);
  final used = List<bool>.filled(long.length, false);
  var matched = 0;
  var fuzzy = false;
  for (final t in short) {
    // Erst exakt, dann unscharf - sonst verbraucht ein unscharfer Treffer den
    // Platz eines exakten.
    var idx = -1;
    for (var i = 0; i < long.length; i++) {
      if (!used[i] && long[i] == t) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      for (var i = 0; i < long.length; i++) {
        if (!used[i] && _tokenEquals(long[i], t)) {
          idx = i;
          fuzzy = true;
          break;
        }
      }
    }
    if (idx >= 0) {
      used[idx] = true;
      matched++;
    }
  }
  return NameSimilarity(
    matched / long.length,
    short.length >= 2 && matched == short.length,
    fuzzy,
  );
}

// ── Finca-Name ─────────────────────────────────────────────────────────────
//
// Der Export hat keine Koordinaten, Flächen oder Adressen; nombre_finca ist
// meist ein Ortsname ("LAS VEGAS DE VERACRUZ TROJES", "LA BENDICION") und
// vielfach vergeben. Er taugt daher nur zur Entscheidung zwischen wenigen
// Kandidaten, nie als eigenständiges Kriterium.

/// Füllwörter, die in Finca- und Ortsnamen nichts unterscheiden.
const Set<String> _placeStopwords = {
  'FINCA', 'LA', 'EL', 'LOS', 'LAS', 'DE', 'DEL', 'Y', 'N', 'I', 'NI',
};

/// Unterscheidende Bestandteile eines Ortsnamens; [drop] (z.B. Municipio und
/// Departamento der Finca) fällt mit heraus.
List<String> _placeTokens(String raw, [Iterable<String> drop = const []]) {
  final dropTokens = {
    for (final d in drop) ..._tokens(d),
  };
  return _tokens(raw)
      .where((t) => !_placeStopwords.contains(t) && !dropTokens.contains(t))
      .toList();
}

/// Jeder Bestandteil von [small] kommt (ggf. mit Tippfehler) in [big] vor.
bool _allIn(List<String> small, List<String> big) =>
    small.isNotEmpty &&
    small.every((t) => big.any((b) => _tokenEquals(b, t)));

/// Begründung, warum [x] zur Farm [f] passt - oder null.
///
/// Verglichen wird der Finca-Name mit dem Farmnamen (in beide Richtungen
/// enthalten) und die Aldea der Farm mit Finca-Name bzw. Finca-Aldea. Ist der
/// Farmname nur der Personenname (so bei Importen), zählt er nicht.
String? fincaEvidence(IhcafeFinca x, FarmToMatch f) {
  final fincaTokens =
      _placeTokens(x.nombreFinca ?? '', [x.municipio, x.departamento]);
  final aldeaTokens = _placeTokens(f.aldea);

  if (aldeaTokens.isNotEmpty) {
    final fincaAldea = _placeTokens(x.aldea ?? '');
    if (fincaAldea.isNotEmpty &&
        _allIn(aldeaTokens, fincaAldea) &&
        _allIn(fincaAldea, aldeaTokens)) {
      return 'finca ${x.fincaId} aldea "${x.aldea}" = farm aldea';
    }
    if (_allIn(aldeaTokens, fincaTokens)) {
      return 'finca ${x.fincaId} "${x.nombreFinca}" contains farm aldea '
          '"${f.aldea}"';
    }
  }

  final farmIsPerson =
      personNameKey(f.farmName) == personNameKey(f.farmerName);
  final farmTokens = farmIsPerson ? const <String>[] : _placeTokens(f.farmName);
  if (farmTokens.isNotEmpty &&
      fincaTokens.isNotEmpty &&
      (_allIn(farmTokens, fincaTokens) || _allIn(fincaTokens, farmTokens))) {
    return 'finca ${x.fincaId} "${x.nombreFinca}" fits farm name '
        '"${f.farmName}"';
  }
  return null;
}

// ── Matcher ────────────────────────────────────────────────────────────────

class IhcafeFarmMatcher {
  final IhcafeCatalog catalog;

  final Map<String, IhcafeProducer> _byDni = {};
  final Map<String, IhcafeProducer> _byClave = {};
  final Map<String, IhcafeProducer> _byProductorId = {};

  /// Municipio-Schlüssel -> Namensbestandteil -> Produzenten. Grenzt die
  /// unscharfe Suche auf Produzenten mit mindestens einem gemeinsamen
  /// Bestandteil ein, statt jeden Farmer gegen 30k Namen zu rechnen.
  final Map<String, Map<String, Set<IhcafeProducer>>> _tokenIndexByMunicipio =
      {};

  /// Municipio-Schlüssel des Exports.
  final Set<String> municipioKeys = {};

  /// DNI-Werte, die im Export mehrfach vorkommen - darüber wird nicht gematcht.
  final Set<String> duplicateDnis = {};

  IhcafeFarmMatcher(this.catalog) {
    for (final p in catalog.producers) {
      final dni = _digits(p.identidad);
      if (dni.length >= 8) {
        if (_byDni.containsKey(dni)) {
          duplicateDnis.add(dni);
        } else {
          _byDni[dni] = p;
        }
      }
      if (p.clave.isNotEmpty) _byClave[p.clave] = p;
      if (p.productorId != null) _byProductorId['${p.productorId}'] = p;

      final tokens = _tokens(p.nombreCompleto);
      for (final m in p.municipios.map(personNameKey)) {
        if (m.isEmpty) continue;
        municipioKeys.add(m);
        final idx = _tokenIndexByMunicipio.putIfAbsent(m, () => {});
        for (final t in tokens) {
          idx.putIfAbsent(t, () => {}).add(p);
        }
      }
    }
    for (final d in duplicateDnis) {
      _byDni.remove(d);
    }
  }

  IhcafeProducer? _producerFromExistingIds(List<String> ids) {
    for (final id in ids) {
      final p = _byClave[id] ?? _byProductorId[id];
      if (p != null) return p;
    }
    return null;
  }

  bool _inMunicipio(IhcafeProducer p, String munKey) =>
      munKey.isNotEmpty && p.municipios.map(personNameKey).contains(munKey);

  String _describe(IhcafeProducer p) =>
      '${p.nombreCompleto} (clave ${p.clave.isEmpty ? '-' : p.clave}, '
      'DNI ${p.identidad.isEmpty ? '-' : p.identidad}, '
      '${p.municipios.isEmpty ? 'no municipio' : p.municipios.join('/')}'
      '${p.esVigente ? '' : ', no vigente'})';

  /// Gleicht eine Farm ab. [matchAll] danach aufrufen bzw.
  /// [resolveCollisions] über alle Ergebnisse, damit doppelte Zuordnungen
  /// erkannt werden.
  IhcafeFarmMatch matchOne(FarmToMatch f) {
    final reasons = <String>[];
    final munKey = personNameKey(f.municipio);
    final nameTokens = _tokens(f.farmerName);
    final dni = _digits(f.nationalId);

    reasons.add('farmer "${f.farmerName}", municipio '
        '"${f.municipio.isEmpty ? '-' : f.municipio}", '
        'DNI ${f.nationalId.isEmpty ? '-' : f.nationalId}');

    if (f.farmerUid == null) {
      reasons.add('farm has no owner link - only the farm could be linked');
    }

    // 1. Bereits verknüpft.
    final linked = _producerFromExistingIds(f.farmerIhcafeIds);
    if (linked != null) {
      reasons.add('farmer already carries IHCafe id(s) '
          '${f.farmerIhcafeIds.join(', ')} -> ${_describe(linked)}');
      return _finish(
        f,
        IhcafeLinkLevel.alreadyLinked,
        linked,
        reasons,
        nameScore: compareNames(nameTokens, _tokens(linked.nombreCompleto)).score,
      );
    }
    if (f.farmerIhcafeIds.isNotEmpty) {
      reasons.add('farmer carries IHCafe id(s) ${f.farmerIhcafeIds.join(', ')} '
          'that are not in this export - matching anyway');
    }

    // 2. DNI.
    IhcafeProducer? byDni;
    if (dni.isNotEmpty) {
      if (dni.length != 13) {
        reasons.add('national ID has ${dni.length} digits (Honduras: 13)');
      }
      if (duplicateDnis.contains(dni)) {
        reasons.add('DNI occurs several times in the export - not used');
      } else {
        byDni = _byDni[dni];
      }
    }
    if (byDni != null) {
      final sim = compareNames(nameTokens, _tokens(byDni.nombreCompleto));
      reasons.add('DNI matches ${_describe(byDni)}; name similarity '
          '${(sim.score * 100).round()}%${sim.subset ? ' (subset)' : ''}');
      final plausible = sim.subset || sim.score >= 0.5;
      if (munKey.isNotEmpty && !_inMunicipio(byDni, munKey)) {
        reasons.add('note: producer fincas are not in "${f.municipio}"');
      }
      return _finish(
        f,
        plausible ? IhcafeLinkLevel.dni : IhcafeLinkLevel.dniNameMismatch,
        byDni,
        reasons,
        nameScore: sim.score,
      );
    } else if (dni.length >= 8) {
      reasons.add('DNI not found in the export');
    }

    if (nameTokens.isEmpty) {
      reasons.add('farmer has no usable name');
      return IhcafeFarmMatch(farm: f, level: IhcafeLinkLevel.none, reasons: reasons);
    }

    // Steht der DNI des Farmers fest, darf ein Namenstreffer ihm nicht
    // widersprechen.
    bool contradictsDni(IhcafeProducer p) {
      final pd = _digits(p.identidad);
      return dni.length >= 8 && pd.isNotEmpty && pd != dni;
    }

    // 3. Name exakt bzw. gleiche Bestandteile.
    final key = nameTokens.join(' ');
    var exact = catalog.byNameKey[key] ?? const <IhcafeProducer>[];
    var viaTokens = false;
    if (exact.isEmpty) {
      exact = catalog.byTokenSet[(List.of(nameTokens)..sort()).join(' ')] ??
          const <IhcafeProducer>[];
      viaTokens = exact.isNotEmpty;
    }

    if (exact.isNotEmpty) {
      final geo = exact.where((p) => _inMunicipio(p, munKey)).toList();
      reasons.add('${exact.length} exact name hit(s)'
          '${viaTokens ? ' (same name parts, different order)' : ''}, '
          '${geo.length} in municipio');
      if (geo.length == 1) {
        final p = geo.first;
        if (contradictsDni(p)) {
          reasons.add('CONFLICT: ${_describe(p)} has a different DNI');
          return IhcafeFarmMatch(
              farm: f,
              level: IhcafeLinkLevel.conflict,
              candidates: [p],
              reasons: reasons);
        }
        // Ein kurzer Name ("CARLOS COLINDRES") passt exakt auf einen
        // Produzenten, aber ebenso auf "CARLOS ANTONIO COLINDRES MEJIA" - in
        // der App werden Zweitnamen oft weggelassen. Dann ist der exakte
        // Treffer nur wahrscheinlich, nicht sicher.
        // Rivalen sind nur längere Namen, die den Farmernamen enthalten, und
        // gleich lange Tippfehler-Varianten - ein kürzerer Name ("PEDRO
        // MARTINEZ") stellt den exakten "PEDRO PABLO MARTINEZ" nicht in Frage.
        final rivals = _fuzzyHits(nameTokens, munKey).hits.where((h) {
          if (h.$1 == p || contradictsDni(h.$1)) return false;
          final len = _tokens(h.$1.nombreCompleto).length;
          return len > nameTokens.length ||
              (len == nameTokens.length && h.$2.score >= 0.75);
        }).toList();
        if (rivals.isNotEmpty) {
          reasons.add('-> ${_describe(p)}, but ${rivals.length} longer/similar '
              'name(s) in municipio fit as well:');
          for (final h in rivals.take(4)) {
            reasons.add('  rival ${_describe(h.$1)} '
                '${(h.$2.score * 100).round()}%');
          }
          return _finish(f, IhcafeLinkLevel.nameFuzzy, p, reasons, nameScore: 1)
            ..candidates.addAll(rivals.take(4).map((h) => h.$1));
        }
        reasons.add('-> ${_describe(p)}, no other name in municipio fits');
        return _finish(f, IhcafeLinkLevel.nameMunicipio, p, reasons, nameScore: 1);
      }
      if (geo.length > 1) {
        for (final p in geo.take(5)) {
          reasons.add('  candidate ${_describe(p)}');
        }
        final tie = _tieBreakByFinca(
            geo.where((p) => !contradictsDni(p)).toList(), f, munKey);
        if (tie != null) {
          reasons.add('-> ${_describe(tie.producer)}: ${tie.evidence}, '
              'no other candidate has a fitting finca');
          return _finish(f, IhcafeLinkLevel.nameFinca, tie.producer, reasons,
              nameScore: 1, preferredFinca: tie.finca);
        }
        return IhcafeFarmMatch(
            farm: f,
            level: IhcafeLinkLevel.ambiguous,
            candidates: geo.take(5).toList(),
            reasons: reasons);
      }
      // Kein Treffer im Municipio - unscharf im Municipio kann noch helfen,
      // sonst unten "nur Name".
    }

    // 4. Unscharf innerhalb des Municipios.
    if (munKey.isNotEmpty && !municipioKeys.contains(munKey)) {
      reasons.add('municipio "${f.municipio}" is not covered by the export '
          '(${catalog.meta.scopeDepartamento})');
      if (exact.length == 1 && !contradictsDni(exact.first)) {
        reasons.add('single name hit elsewhere: ${_describe(exact.first)}');
      }
      return IhcafeFarmMatch(
          farm: f,
          level: IhcafeLinkLevel.outOfScope,
          candidates: exact.take(5).toList(),
          reasons: reasons);
    }

    IhcafeProducer? guess;
    var guessScore = 0.0;
    if (munKey.isNotEmpty) {
      final fz = _fuzzyHits(nameTokens, munKey);
      final hits = fz.hits;
      guess = fz.guess;
      guessScore = fz.guessScore;
      reasons.add('${fz.poolSize} producer(s) in municipio share a name part, '
          '${hits.length} fuzzy hit(s)');

      final usable = hits.where((h) => !contradictsDni(h.$1)).toList();
      if (usable.length == 1) {
        final (p, sim) = usable.first;
        reasons.add('-> ${_describe(p)}; similarity '
            '${(sim.score * 100).round()}%'
            '${sim.subset ? ', subset' : ''}${sim.fuzzy ? ', typo' : ''}');
        return _finish(f, IhcafeLinkLevel.nameFuzzy, p, reasons,
            nameScore: sim.score);
      }
      if (usable.length > 1) {
        // Ein klar bester Treffer (exakte Länge, deutlich höherer Score)
        // reicht hier bewusst nicht: zwei Teilmengen-Treffer sind echte
        // Mehrdeutigkeit.
        for (final h in usable.take(5)) {
          reasons.add('  candidate ${_describe(h.$1)} '
              '${(h.$2.score * 100).round()}%');
        }
        final tie = _tieBreakByFinca(
            usable.map((h) => h.$1).toList(), f, munKey);
        if (tie != null) {
          final sim = usable.firstWhere((h) => h.$1 == tie.producer).$2;
          reasons.add('-> ${_describe(tie.producer)}: ${tie.evidence}, '
              'no other candidate has a fitting finca');
          return _finish(f, IhcafeLinkLevel.nameFinca, tie.producer, reasons,
              nameScore: sim.score, preferredFinca: tie.finca);
        }
        return IhcafeFarmMatch(
            farm: f,
            level: IhcafeLinkLevel.ambiguous,
            candidates: usable.take(5).map((h) => h.$1).toList(),
            reasons: reasons);
      }
      if (hits.isNotEmpty) {
        reasons.add('CONFLICT: fuzzy hit(s) carry a different DNI');
        return IhcafeFarmMatch(
            farm: f,
            level: IhcafeLinkLevel.conflict,
            candidates: hits.take(5).map((h) => h.$1).toList(),
            reasons: reasons);
      }
    } else {
      reasons.add('no municipio on farm or farmer - no geographic check');
    }

    // 5. Nur Name, ohne Municipio-Bestätigung.
    if (exact.length == 1) {
      final p = exact.first;
      if (contradictsDni(p)) {
        reasons.add('CONFLICT: ${_describe(p)} has a different DNI');
        return IhcafeFarmMatch(
            farm: f,
            level: IhcafeLinkLevel.conflict,
            candidates: [p],
            reasons: reasons);
      }
      reasons.add('single name hit outside municipio -> ${_describe(p)}');
      return _finish(f, IhcafeLinkLevel.nameOnly, p, reasons, nameScore: 1);
    }
    if (exact.length > 1) {
      for (final p in exact.take(5)) {
        reasons.add('  candidate ${_describe(p)}');
      }
      return IhcafeFarmMatch(
          farm: f,
          level: IhcafeLinkLevel.ambiguous,
          candidates: exact.take(5).toList(),
          reasons: reasons);
    }

    if (guess != null) {
      reasons.add('closest name in municipio: ${_describe(guess)} '
          '${(guessScore * 100).round()}%');
    }
    return IhcafeFarmMatch(
      farm: f,
      level: IhcafeLinkLevel.none,
      bestGuess: guess,
      bestGuessScore: guessScore,
      reasons: reasons,
    );
  }

  /// Produzenten im Municipio, deren Name unscharf passt: alle Bestandteile
  /// des kürzeren Namens im längeren (bei mindestens zwei) oder mindestens
  /// 75 % gleiche Bestandteile. Absteigend nach Ähnlichkeit.
  ({
    List<(IhcafeProducer, NameSimilarity)> hits,
    IhcafeProducer? guess,
    double guessScore,
    int poolSize,
  }) _fuzzyHits(List<String> nameTokens, String munKey) {
    final idx = _tokenIndexByMunicipio[munKey] ?? const {};
    final pool = <IhcafeProducer>{};
    for (final t in nameTokens) {
      pool.addAll(idx[t] ?? const {});
    }
    // Tippfehler im einzigen gemeinsamen Bestandteil: dann über alle
    // Bestandteile des Municipios gehen (nur für ähnlich lange Tokens).
    for (final entry in idx.entries) {
      if (nameTokens.any((t) => t != entry.key && _tokenEquals(t, entry.key))) {
        pool.addAll(entry.value);
      }
    }

    IhcafeProducer? guess;
    var guessScore = 0.0;
    final hits = <(IhcafeProducer, NameSimilarity)>[];
    for (final p in pool) {
      final sim = compareNames(nameTokens, _tokens(p.nombreCompleto));
      if (sim.score > guessScore) {
        guessScore = sim.score;
        guess = p;
      }
      if (sim.subset || sim.score >= 0.75) hits.add((p, sim));
    }
    hits.sort((a, b) => b.$2.score.compareTo(a.$2.score));
    return (
      hits: hits,
      guess: guess,
      guessScore: guessScore,
      poolSize: pool.length,
    );
  }

  /// Unter mehrdeutigen Kandidaten den einzigen, der eine zur Farm passende
  /// Finca im Municipio hat (siehe [fincaEvidence]). Passen bei ihm mehrere
  /// Fincas, bleibt [finca] null und [chooseFinca] entscheidet.
  ({IhcafeProducer producer, IhcafeFinca? finca, String evidence})?
      _tieBreakByFinca(
          List<IhcafeProducer> candidates, FarmToMatch f, String munKey) {
    if (munKey.isEmpty || candidates.length < 2) return null;
    final fits = <(IhcafeProducer, IhcafeFinca, String)>[];
    for (final p in candidates) {
      for (final x in p.fincas) {
        if (x.fincaId == null || personNameKey(x.municipio) != munKey) {
          continue;
        }
        final e = fincaEvidence(x, f);
        if (e != null) fits.add((p, x, e));
      }
    }
    final producers = fits.map((e) => e.$1).toSet();
    if (producers.length != 1) return null;
    return (
      producer: producers.single,
      finca: fits.length == 1 ? fits.single.$2 : null,
      evidence: fits.first.$3,
    );
  }

  /// Ergänzt Finca-Auswahl und geplante alternateIDs.
  IhcafeFarmMatch _finish(
    FarmToMatch f,
    IhcafeLinkLevel level,
    IhcafeProducer p,
    List<String> reasons, {
    double nameScore = 0,
    IhcafeFinca? preferredFinca,
  }) {
    final match = IhcafeFarmMatch(
      farm: f,
      level: level,
      producer: p,
      nameScore: nameScore,
      reasons: reasons,
    );

    // Farmer: clave und productor_id, soweit noch nicht vorhanden - bzw.
    // idName nachtragen, wenn die Kennung ohne steht.
    if (f.farmerUid != null) {
      void plan(String uid, String label) {
        if (uid.isEmpty) return;
        if (!f.farmerIhcafeIds.contains(uid)) {
          match.farmerAdds.add(PlannedAltId(uid, label));
        } else if (f.farmerIhcafeIdsWithoutName.contains(uid)) {
          reasons.add('farmer carries $uid without idName -> "$label"');
          match.farmerAdds.add(PlannedAltId(uid, label, onlyName: true));
        }
      }

      plan(p.clave, ihcafeIdClave);
      plan(p.productorId == null ? '' : '${p.productorId}', ihcafeIdProductorId);
    }

    // Farm: finca_id, wenn eindeutig bestimmbar.
    final finca = preferredFinca ?? chooseFinca(p, f, reasons);
    if (preferredFinca != null) {
      reasons.add('finca: ${preferredFinca.fincaId} picked by finca name');
    }
    if (finca != null) {
      match.finca = finca;
      final id = '${finca.fincaId}';
      if (f.farmIhcafeIds.contains(id)) {
        if (f.farmIhcafeIdsWithoutName.contains(id)) {
          reasons.add('farm carries finca_id $id without idName -> add it');
          match.farmAdds
              .add(PlannedAltId(id, ihcafeIdFincaId, onlyName: true));
        } else {
          reasons.add('farm already carries finca_id $id');
        }
      } else {
        if (f.farmIhcafeIds.isNotEmpty) {
          reasons.add('note: farm already carries other IHCafe id(s) '
              '${f.farmIhcafeIds.join(', ')}');
        }
        match.farmAdds.add(PlannedAltId(id, ihcafeIdFincaId));
      }
    }

    if (!match.hasChanges) reasons.add('nothing to add');
    return match;
  }

  /// Wählt die Finca des Produzenten, die zu dieser Farm gehört - oder null,
  /// wenn das nicht eindeutig ist.
  IhcafeFinca? chooseFinca(IhcafeProducer p, FarmToMatch f, List<String> log) {
    final fincas = p.fincas.where((x) => x.fincaId != null).toList();
    if (fincas.isEmpty) {
      log.add('finca: producer has no finca in the export');
      return null;
    }

    // Schon an der Farm hinterlegt?
    for (final x in fincas) {
      if (f.farmIhcafeIds.contains('${x.fincaId}')) return x;
    }

    final munKey = personNameKey(f.municipio);
    String where(IhcafeFinca x) =>
        '${x.fincaId} (${x.municipio}${(x.aldea ?? '').isEmpty ? '' : ', ${x.aldea}'})';

    if (fincas.length == 1) {
      final x = fincas.first;
      if (munKey.isEmpty || personNameKey(x.municipio) == munKey) {
        log.add('finca: single finca ${where(x)}');
        return x;
      }
      log.add('finca: single finca ${where(x)} lies outside farm municipio '
          '"${f.municipio}" - finca_id NOT set');
      return null;
    }

    var narrowed = fincas
        .where((x) => munKey.isNotEmpty && personNameKey(x.municipio) == munKey)
        .toList();
    if (narrowed.length == 1) {
      log.add('finca: ${fincas.length} fincas, municipio picks '
          '${where(narrowed.first)}');
      return narrowed.first;
    }
    final pool = narrowed.isEmpty ? fincas : narrowed;
    final aldeaKey = personNameKey(f.aldea);
    if (aldeaKey.isNotEmpty) {
      final byAldea =
          pool.where((x) => personNameKey(x.aldea ?? '') == aldeaKey).toList();
      if (byAldea.length == 1) {
        log.add('finca: ${fincas.length} fincas, aldea picks '
            '${where(byAldea.first)}');
        return byAldea.first;
      }
    }
    // Finca-Name gegen Farmname bzw. Aldea der Farm.
    final byName = [
      for (final x in pool)
        if (fincaEvidence(x, f) case final e?) (x, e),
    ];
    if (byName.length == 1) {
      log.add('finca: ${fincas.length} fincas, finca name picks '
          '${where(byName.single.$1)} (${byName.single.$2})');
      return byName.single.$1;
    }
    log.add('finca: ${fincas.length} fincas (${fincas.map(where).join('; ')}) '
        '- not decidable, finca_id NOT set');
    return null;
  }

  /// Gleicht alle Farmen ab und löst Kollisionen auf.
  List<IhcafeFarmMatch> matchAll(List<FarmToMatch> farms) {
    final results = farms.map(matchOne).toList();
    resolveCollisions(results);
    return results;
  }
}

/// Stuft Treffer herab, die sich gegenseitig ausschließen:
/// - derselbe Produzent bei verschiedenen Farmern,
/// - dieselbe finca_id an verschiedenen Farmen.
///
/// Mehrere Farmen desselben Farmers dürfen denselben Produzenten haben.
void resolveCollisions(List<IhcafeFarmMatch> results) {
  final farmersByClave = <String, Set<String>>{};
  for (final r in results) {
    final p = r.producer;
    if (p == null) continue;
    final who = r.farm.farmerUid ?? 'farm:${r.farm.farmUid}';
    farmersByClave.putIfAbsent(p.clave, () => {}).add(who);
  }
  for (final r in results) {
    final p = r.producer;
    if (p == null) continue;
    final owners = farmersByClave[p.clave]!;
    if (owners.length > 1) {
      r.originalLevel = r.level;
      r.level = IhcafeLinkLevel.duplicate;
      r.reasons.add('DUPLICATE: producer ${p.clave} is matched to '
          '${owners.length} different farmers - nothing is written');
    }
  }

  final farmsByFinca = <String, Set<String>>{};
  for (final r in results) {
    final id = r.finca?.fincaId;
    if (id == null) continue;
    farmsByFinca.putIfAbsent('$id', () => {}).add(r.farm.farmUid);
  }
  for (final r in results) {
    final id = r.finca?.fincaId;
    if (id == null) continue;
    if (farmsByFinca['$id']!.length > 1) {
      r.reasons.add('finca_id $id would go to '
          '${farmsByFinca['$id']!.length} farms - finca_id NOT set');
      r.farmAdds.removeWhere((a) => a.label == ihcafeIdFincaId);
      r.finca = null;
    }
  }
}

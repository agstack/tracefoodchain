import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/country_config.dart';
import '../models/user_scope.dart';
import '../services/country_config_service.dart';
import '../services/open_ral_service.dart';
import '../services/role_management_service.dart';
import '../services/asset_registry_api_service.dart';
import '../services/user_registry_api_service.dart';
import '../helpers/deep_copy_map.dart';
import '../helpers/handbook_links.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import '../helpers/field_download_helper.dart';
import '../helpers/qc_search_tokens.dart';
import '../widgets/data_loading_indicator.dart';
import '../widgets/ihcafe_producer_widgets.dart';
import '../services/field_geometry_service.dart';
import '../services/object_correction_service.dart';
import '../services/permission_service.dart';
import '../services/qc_index_service.dart';
import '../widgets/field_polygon_editor.dart';
import '../widgets/map_type_selector.dart';
import '../widgets/qc_correction_dialog.dart';
import '../widgets/qc_polygon_replace_page.dart';
import '../widgets/qc_overview_map.dart';
import '../utils/gps_quality.dart';
import '../services/service_functions.dart';
import '../utils/file_download.dart';

/// Screen für QC-Review und Genehmigung von registrierten Farmen, Farmern und Feldern
class RegistrarQCScreen extends StatefulWidget {
  const RegistrarQCScreen({super.key});

  @override
  State<RegistrarQCScreen> createState() => _RegistrarQCScreenState();
}

/// Sort orders offered in the QC list.
enum _QcSort { dateDesc, dateAsc, registrar, name }

/// Fotorollen je Objekttyp, die im QC als Prüfpunkt abgehakt werden müssen.
/// Pflichtfotos ([requiredPhotoRoles]) sind immer ein Prüfpunkt - fehlt das
/// Foto, etwa bei Excel-Importen, muss es der Prüfer erst hochladen, bevor die
/// Registrierung freigegeben werden kann. Optionale Fotos nur, wenn vorhanden.
const Map<String, List<String>> _qcPhotoRoles = photoRolesByType;

/// Prüfpunkt-Schlüssel für die Freigabe der Feldgrenze.
const String _qcPolygonCheck = 'polygonGeometry';

/// Ein Punkt der QC-Checkliste. [check] ist die Fotorolle oder
/// [_qcPolygonCheck] und landet so im signierten QC-Job.
class _QcCheck {
  const _QcCheck({
    required this.object,
    required this.check,
  });

  final Map<String, dynamic> object;
  final String check;

  String get objectUid => object['identity']?['UID']?.toString() ?? '';
  String get objectType => object['template']?['RALType']?.toString() ?? '';
  String get id => '$objectUid|$check';
  bool get isPhoto => check != _qcPolygonCheck;
}

/// Eine Farm samt Farmer und offenen Feldern - die Einheit, die im QC am Stück
/// geprüft und entschieden wird.
///
/// Farm oder Farmer können bereits freigegeben sein (nachträglich erfasste
/// Felder, weitere Farm eines bekannten Farmers); sie stehen dann nur als
/// Kontext in der Karte und sind nicht Teil der Entscheidung.
class _QcBundle {
  _QcBundle({required this.key, this.farm, this.farmer});

  /// Farm-UID, oder die UID des offenen Objekts, wenn keine Farm gefunden wurde.
  final String key;
  Map<String, dynamic>? farm;
  Map<String, dynamic>? farmer;
  final List<Map<String, dynamic>> fields = [];

  DateTime? registeredAt;
  String registrarName = '-';
  String registrarUid = '';
  String registrarEmail = '';
  final Set<String> alternateIds = {};

  /// Suchbegriffe aus dem QC-Index, wenn das Bündel von dort kam - die Suche
  /// prüft dann gegen sie statt gegen [searchIndex].
  Set<String>? indexTokens;

  static String uidOf(Map<String, dynamic>? obj) =>
      obj?['identity']?['UID']?.toString() ?? '';

  static bool isPending(Map<String, dynamic>? obj) =>
      obj?['objectState'] == 'qcPending';

  List<Map<String, dynamic>> get members => [
        if (farmer != null) farmer!,
        if (farm != null) farm!,
        ...fields,
      ];

  List<Map<String, dynamic>> get pendingMembers =>
      members.where(isPending).toList();

  List<Map<String, dynamic>> get pendingFields =>
      fields.where(isPending).toList();

  bool contains(String uid) => members.any((m) => uidOf(m) == uid);

  static String _address(Map<String, dynamic>? obj, String key) =>
      obj?['currentGeolocation']?['postalAddress']?[key]?.toString().trim() ??
      '';

  /// Gespeichertes Land - bevorzugt der Farm, sonst des Farmers oder eines
  /// Feldes. Neuere Registrierungen tragen den ISO-Code, ältere den Namen.
  String get storedCountry {
    for (final obj in [farm, farmer, ...fields]) {
      final c = _address(obj, 'country');
      if (c.isNotEmpty && c != 'unknown') return c;
    }
    return '';
  }

  /// Oberste Verwaltungsebene (z.B. Departamento) - Felder tragen keine.
  String get stateName {
    final s = _address(farm, 'stateName');
    return s.isNotEmpty ? s : _address(farmer, 'stateName');
  }

  String get name {
    for (final obj in [farm, farmer, ...fields]) {
      final n = obj?['identity']?['name']?.toString() ?? '';
      if (n.isNotEmpty) return n;
    }
    return 'Unnamed';
  }

  String get farmerName =>
      farmer?['identity']?['name']?.toString().trim().isNotEmpty == true
          ? farmer!['identity']['name'].toString()
          : '-';

  /// Datum und Registrar übernimmt das Bündel aus den geladenen Einträgen -
  /// bevorzugt aus dem der Farm, sonst aus dem ersten mit Datum.
  void absorbEntry(_QcEntry entry) {
    alternateIds.addAll(entry.alternateIds);
    final takeOver = entry.registeredAt != null &&
        (registeredAt == null || entry.ralType == 'farm');
    if (takeOver || (registrarUid.isEmpty && entry.registrarUid.isNotEmpty)) {
      registeredAt = entry.registeredAt ?? registeredAt;
      registrarName = entry.registrarName;
      registrarUid = entry.registrarUid;
      registrarEmail = entry.registrarEmail;
    }
  }

  /// Setzt die neue Fassung eines Mitglieds ein (Polygonkorrektur, Entscheidung
  /// in einem anderen Bündel mit demselben Farmer).
  void replaceObject(Map<String, dynamic> updated) {
    final uid = uidOf(updated);
    if (uid.isEmpty) return;
    if (uidOf(farm) == uid) farm = updated;
    if (uidOf(farmer) == uid) farmer = updated;
    for (int i = 0; i < fields.length; i++) {
      if (uidOf(fields[i]) == uid) fields[i] = updated;
    }
  }

  /// Label for the registrar filter. Not everyone fills in a name, so the mail
  /// address is what actually identifies the person in that case.
  String get registrarLabel {
    final hasName = registrarName.isNotEmpty && registrarName != '-';
    if (hasName && registrarEmail.isNotEmpty) {
      return '$registrarName ($registrarEmail)';
    }
    if (registrarEmail.isNotEmpty) return registrarEmail;
    return registrarName;
  }

  /// Everything the search box may match against, lowercased.
  String get searchIndex => [
        for (final m in members) ...[
          m['identity']?['name']?.toString() ?? '',
          uidOf(m),
        ],
        registrarName,
        registrarEmail,
        ...alternateIds,
      ].join(' ').toLowerCase();
}

/// A pending registration together with the metadata the list needs for
/// sorting, filtering and searching.
///
/// The metadata lives NEXT TO the openRAL object, never inside it: the object
/// is written back to Firestore on approval and is hashed as a whole, so any
/// extra key would invalidate it.
class _QcEntry {
  _QcEntry({
    required this.object,
    required this.ralType,
    required this.name,
    this.registeredAt,
    this.registrarName = '-',
    this.registrarUid = '',
    this.registrarEmail = '',
    this.alternateIds = const [],
  });

  final Map<String, dynamic> object;
  final String ralType;
  final String name;
  final DateTime? registeredAt;
  final String registrarName;
  final String registrarUid;
  final String registrarEmail;
  final List<String> alternateIds;

  /// Neue Fassung desselben Eintrags mit korrigiertem Objekt - nach einer
  /// Polygonänderung, ohne die bereits aufgelösten Metadaten erneut zu laden.
  _QcEntry withObject(Map<String, dynamic> updated) => _QcEntry(
        object: updated,
        ralType: ralType,
        name: name,
        registeredAt: registeredAt,
        registrarName: registrarName,
        registrarUid: registrarUid,
        registrarEmail: registrarEmail,
        alternateIds: alternateIds,
      );

  String get uid => object['identity']?['UID']?.toString() ?? '';
}

class _RegistrarQCScreenState extends State<RegistrarQCScreen> {
  List<_QcEntry> _pendingRegistrations = [];
  bool _isLoading = true;

  /// What the screen is currently busy with. Loading and approving both take
  /// several network round trips; a bare spinner leaves the reviewer staring at
  /// an empty screen with no idea whether anything is happening.
  String? _loadingMessage;
  /// Übersichtskarte statt Liste: dieselben Einträge, dieselben Filter.
  bool _showMap = false;

  /// Seitengröße der Warteschlange. Die Registrierungen werden portionsweise
  /// geladen: bei mehreren tausend offenen Vorgängen wäre alles auf einmal
  /// minutenlanges Warten, bevor überhaupt etwas zu sehen ist.
  static const int _pageSize = 150;

  /// Wie viele Einträge ein Nachladevorgang mindestens liefern soll, bevor er
  /// die Liste aktualisiert.
  static const int _targetPerLoad = 50;

  /// Seitengröße der Methodenabfrage. Methoden-Dokumente tragen die vollen
  /// Ein- und Ausgangsobjekte, sind also deutlich schwerer als Objekte.
  static const int _methodPageSize = 60;

  /// Phase 1: Cursor über die Erzeugungsmethoden, neueste zuerst.
  DocumentSnapshot<Map<String, dynamic>>? _methodCursor;
  bool _methodsExhausted = false;

  /// Phase 2: Cursor über die Objekte selbst - das Sicherheitsnetz für
  /// Registrierungen, deren Erzeugungsmethode kein Datum trägt.
  DocumentSnapshot<Map<String, dynamic>>? _objectCursor;
  bool _objectsExhausted = false;

  /// Bereits geladene Objekt-UIDs, damit Phase 2 nichts doppelt anhängt.
  final Set<String> _loadedUids = {};

  bool _loadingMore = false;

  bool get _hasMore => _useIndex
      ? !_indexExhausted
      : (!_methodsExhausted || !_objectsExhausted);

  /// Gesetzt, wenn die nach Zeitpunkt sortierte Methodenabfrage nicht bedient
  /// werden konnte (in aller Regel: der zusammengesetzte Index fehlt noch).
  /// Dann stimmt "neueste zuerst" nur noch innerhalb des Geladenen - das darf
  /// nicht stillschweigend passieren.
  bool _dateOrderUnavailable = false;

  /// Gesamtzahl offener Vorgänge in der Cloud, über eine count()-Abfrage - die
  /// zählt serverseitig und lädt keine Dokumente.
  int? _totalPending;

  /// Die Prüfeinheiten: je Farm ein Bündel aus Farm, Farmer und Feldern.
  /// [_pendingRegistrations] bleibt die Liste der geladenen offenen Objekte,
  /// aus denen die Bündel gebildet werden.
  List<_QcBundle> _bundles = [];

  /// Abgehakte Prüfpunkte je Bündel: Prüfpunkt-ID -> Zeitpunkt des Abhakens.
  /// Der Zeitpunkt geht mit in den signierten QC-Job.
  final Map<String, Map<String, DateTime>> _checks = {};

  /// Foto-Abfragen je Objekt und Rolle. Ohne Cache würde jedes Abhaken die
  /// Karte neu bauen und alle Fotos erneut aus Firestore laden.
  final Map<String, Future<Map<String, dynamic>?>> _photoFutures = {};

  /// Bündel, das nach einem Sprung aus der Übersichtskarte aufgeklappt wird.
  String? _focusBundleKey;

  /// Gebiet des Prüfers; null heißt unbeschränkt (SUPERADMIN, tfcAdmin).
  /// Die QC zeigt nur Registrierungen daraus. Das ist eine Ansicht, keine
  /// Zugriffssperre - gelesen werden darf TFC_objects weiterhin.
  final UserScope? _scope = RoleManagementService().currentUserScope();

  /// Registrare im Team des angemeldeten Registrar Coordinators, er selbst
  /// eingeschlossen. Leer für alle anderen Rollen.
  Set<String> _teamUids = {};
  bool _teamOnly = false;

  /// Ob die Objektabfrage nach Land gefiltert werden kann. Fällt auf false,
  /// wenn Firestore die Abfrage ablehnt - dann filtert nur noch der Client.
  bool _serverCountryFilter = true;

  /// Ob die Warteschlange aus dem Suchindex `TFC_qc_index` kommt. Den baut
  /// die Cloud auf; erst wenn er vollständig ist (`TFC_qc_index_meta/state`),
  /// löst er das Laden über Methoden und Objekte ab. Nur über den Index finden
  /// Suche und Filter auch, was noch nicht geladen ist.
  bool _useIndex = false;

  /// Der Index war gemeldet, die Abfrage scheiterte aber - meist fehlt noch
  /// ein zusammengesetzter Firestore-Index. Dann gilt der alte Weg, mit Hinweis.
  bool _indexUnavailable = false;

  DocumentSnapshot<Map<String, dynamic>>? _indexCursor;
  bool _indexExhausted = false;
  static const int _indexPageSize = 30;

  /// Zählt jede neue Abfrage hoch - Ergebnisse einer überholten Abfrage
  /// (Filter während des Ladens geändert) werden verworfen.
  int _queryGeneration = 0;

  /// Land (ISO-Code) und oberste Verwaltungsebene, auf die die Liste
  /// eingeschränkt ist; null = alles im Gebiet.
  String? _countryFilter;
  String? _stateFilter;

  /// Suchtext, mit dem der Index zuletzt abgefragt wurde. Die Abfrage folgt
  /// der Eingabe erst nach einer Tipp-Pause.
  String _serverQuery = '';
  Timer? _searchDebounce;

  /// Alle bisher gesehenen Registrare. Die Auswahl darf nicht schrumpfen, nur
  /// weil die Liste gerade auf einen Registrar gefiltert ist.
  final Map<String, ({String name, String email, String label})>
      _knownRegistrars = {};

  String _registrarFilter = 'all'; // 'all' or a registrar UID
  _QcSort _sortMode = _QcSort.dateDesc;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Registrar lookups resolved at load time, reused by the detail rows so the
  /// same method document is not fetched twice per card.
  final Map<String, Map<String, String>> _registrarCache = {};

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations(fromInitState: true);
    unawaited(_loadTeam());
  }

  /// Holt das Team aus TFC_user_assignments - dort schreibt nur manageUser,
  /// die Angabe am Nutzerobjekt könnte veraltet sein.
  Future<void> _loadTeam() async {
    if (RoleManagementService().getCurrentUserRole() != 'registrarCoordinator') {
      return;
    }
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('TFC_user_assignments')
          .where('coordinatorUid', isEqualTo: myUid)
          .get();
      if (!mounted) return;
      setState(() {
        _teamUids = {myUid, ...snapshot.docs.map((d) => d.id)};
        // Ohne Teammitglieder bliebe die Liste leer - dann alles zeigen.
        _teamOnly = _teamUids.length > 1;
      });
    } catch (e) {
      debugPrint('QC: could not load team: $e');
    }
  }

  /// Gespeicherte Länderwerte im Gebiet des Prüfers, für Firestore-`whereIn`
  /// (höchstens 30 Werte). null, wenn nicht nach Land gefiltert wird.
  List<String>? get _scopeCountryValues {
    final scope = _scope;
    if (scope == null || scope.isEmpty || !_serverCountryFilter) return null;
    final values = <String>{
      for (final code in scope.countries)
        ...(countryConfigService.byCode(code)?.storedValues ?? [code]),
    }.toList();
    return values.length <= 30 ? values : null;
  }

  /// Ob ein geladenes Objekt überhaupt im Gebiet liegen kann - nur nach Land.
  /// Ohne lesbares Land entscheidet später das Bündel, dessen Farm es trägt.
  bool _mayBeInScope(_QcEntry entry) {
    final scope = _scope;
    if (scope == null) return true;
    final stored = _QcBundle._address(entry.object, 'country');
    final code = countryConfigService.resolve(stored)?.code;
    return code == null || scope.countries.contains(code);
  }

  /// Ob ein Bündel im Gebiet des Prüfers liegt: Land, und bei Gebieten mit
  /// Regionen die oberste Verwaltungsebene der Farm.
  bool _inScope(_QcBundle bundle) {
    final scope = _scope;
    if (scope == null) return true;
    final code = countryConfigService.resolve(bundle.storedCountry)?.code;
    final entry = code == null ? null : scope.entryFor(code);
    if (entry == null) return false;
    if (entry.wholeCountry) return true;
    final state = bundle.stateName;
    return entry.regions.any((r) => CountryConfig.sameRegion(r, state));
  }

  /// Bündel im Gebiet - und, wenn gewählt, nur die des eigenen Teams.
  List<_QcBundle> get _visibleBundles => _bundles.where(_isVisible).toList();

  bool _isVisible(_QcBundle b) =>
      _inScope(b) &&
      _matchesLocation(b) &&
      (!_teamOnly || _teamUids.contains(b.registrarUid));

  /// Land- und Regionsfilter. Mit Index filtert schon die Abfrage; hier greift
  /// er für den alten Ladeweg und für alles, was vorher geladen war.
  bool _matchesLocation(_QcBundle bundle) {
    final country = _countryFilter;
    if (country != null &&
        countryConfigService.resolve(bundle.storedCountry)?.code != country) {
      return false;
    }
    final state = _stateFilter;
    if (state != null && !CountryConfig.sameRegion(bundle.stateName, state)) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Drops a decided bundle from the in-memory queue.
  ///
  /// Its objects have just left `qcPending`, so a full reload would return this
  /// exact list minus that bundle - at the price of the whole query chain
  /// again. [decided] are the written object versions: another bundle may share
  /// the farmer (second farm of the same person) and must show the new state.
  void _removeBundleLocally(
      _QcBundle bundle, List<Map<String, dynamic>> decided) {
    if (!mounted) return;
    final decidedUids = decided.map(_QcBundle.uidOf).toSet();

    setState(() {
      _bundles = _bundles.where((b) => b.key != bundle.key).toList();
      for (final other in _bundles) {
        for (final obj in decided) {
          other.replaceObject(obj);
        }
      }
      // Ein Bündel, in dem dadurch nichts Offenes mehr steht, ist erledigt.
      _bundles = _bundles.where((b) => b.pendingMembers.isNotEmpty).toList();

      _pendingRegistrations = _pendingRegistrations
          .where((e) => !decidedUids.contains(e.uid))
          .toList();
      for (final uid in decidedUids) {
        _registrarCache.remove(uid);
      }
      _checks.remove(bundle.key);

      // Deciding the last entry of the registrar currently filtered on would
      // otherwise leave an empty list behind with no visible reason.
      if (_registrarFilter != 'all' &&
          !_bundles.any((b) => b.registrarUid == _registrarFilter)) {
        _registrarFilter = 'all';
      }
    });

    // Wer die obersten Vorgänge abarbeitet, soll nicht vor einer leeren Liste
    // stehen, während in der Cloud noch tausende offen sind.
    if (_hasMore && _pendingRegistrations.length < _pageSize ~/ 3) {
      unawaited(_loadNextPage());
    }
  }

  /// Shows the busy state with an explanation of the current step.
  void _setBusy(String? message) {
    if (!mounted) return;
    setState(() {
      _isLoading = message != null;
      _loadingMessage = message;
    });
  }

  /// [fromInitState] suppresses the initial setState: at that point this
  /// element is being built, and marking it dirty from inside its own build
  /// forces a rebuild within the running build/layout pass. With a
  /// LayoutBuilder above the route - device_preview wraps the whole app in one
  /// while `!kReleaseMode` - that surfaces as
  /// "_RenderLayoutBuilder was mutated in performLayout" when the screen opens.
  /// The fields are simply assigned instead; the first build reads them anyway.
  /// Abfrage der offenen Vorgänge, nach Dokument-ID geordnet.
  ///
  /// Nach Datum liesse sich hier nicht sortieren: das Registrierungsdatum steht
  /// nicht am Objekt, sondern an der zugehörigen Methode. Die Sortierung
  /// "neueste zuerst" passiert deshalb im Client über das, was geladen ist.
  /// Mit Gebiet nur die Objekte seiner Länder.
  Query<Map<String, dynamic>> _pendingQuery() {
    var query = FirebaseFirestore.instance
        .collection('TFC_objects')
        .where('objectState', isEqualTo: 'qcPending');
    final countries = _scopeCountryValues;
    if (countries != null) {
      query = query.where('currentGeolocation.postalAddress.country',
          whereIn: countries);
    }
    return query.orderBy(FieldPath.documentId).limit(_pageSize);
  }

  /// [fromInitState] suppresses the initial setState: at that point this
  /// element is being built, and marking it dirty from inside its own build
  /// forces a rebuild within the running build/layout pass. With a
  /// LayoutBuilder above the route - device_preview wraps the whole app in one
  /// while `!kReleaseMode` - that surfaces as
  /// "_RenderLayoutBuilder was mutated in performLayout" when the screen opens.
  /// The fields are simply assigned instead; the first build reads them anyway.
  /// [keepReviewState] lädt nur die Liste neu (Filter oder Suche geändert) und
  /// behält abgehakte Prüfpunkte und geladene Fotos - der Refresh-Knopf
  /// setzt alles zurück.
  Future<void> _loadPendingRegistrations({
    bool fromInitState = false,
    bool keepReviewState = false,
  }) async {
    final generation = ++_queryGeneration;
    // Eine laufende Seite gehört zur alten Abfrage - abwarten, ihr Ergebnis
    // verwirft die Generationsprüfung.
    final running = _pageInFlight;
    if (running != null) {
      try {
        await running;
      } catch (_) {}
      if (generation != _queryGeneration) return;
    }

    if (fromInitState) {
      _isLoading = true;
      _loadingMessage = null; // l10n is not safe to read from initState
    } else {
      setState(() {
        _isLoading = true;
        _loadingMessage = null;
      });
    }

    // Neu aufsetzen - der Refresh-Knopf führt hier ebenfalls herein.
    _pendingRegistrations = [];
    _bundles = [];
    if (!keepReviewState) {
      _checks.clear();
      _photoFutures.clear();
      _knownRegistrars.clear();
      _indexUnavailable = false;
    }
    _focusBundleKey = null;
    _registrarCache.clear();
    _loadedUids.clear();
    _methodCursor = null;
    _methodsExhausted = false;
    _dateOrderUnavailable = false;
    _objectCursor = null;
    _objectsExhausted = false;
    _indexCursor = null;
    _indexExhausted = false;
    _totalPending = null;

    try {
      if (!keepReviewState) {
        _useIndex = await _indexReady();
        _serverQuery = _searchQuery;
      }
      // Nur fürs Anzeigen ("150 von 2500 geladen"), deshalb ohne await im
      // kritischen Pfad.
      unawaited(_loadTotalCount());
      await _loadNextPage(initial: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    }
  }

  Future<void> _loadTotalCount() async {
    if (_useIndex) {
      final generation = _queryGeneration;
      try {
        final snapshot = await _indexQuery(ordered: false).count().get();
        if (mounted && generation == _queryGeneration) {
          setState(() => _totalPending = snapshot.count);
        }
      } catch (e) {
        debugPrint('QC: could not count index entries: $e');
      }
      return;
    }
    try {
      // Je Typ einzeln: offene Bild-Objekte tragen denselben Zustand, gehören
      // aber nicht in die Warteschlange - eine Gesamtzahl über alle wäre eine
      // andere Zahl als die Liste zeigt.
      // Mit Gebiet nur dessen Länder; Regionen kann die Zählung nicht
      // unterscheiden, sie zählt dann das ganze Land.
      final countries = _scopeCountryValues;
      final counts = await Future.wait(
        ['farm', 'human', 'field'].map((ralType) {
          var query = FirebaseFirestore.instance
              .collection('TFC_objects')
              .where('objectState', isEqualTo: 'qcPending')
              .where('template.RALType', isEqualTo: ralType);
          if (countries != null) {
            query = query.where('currentGeolocation.postalAddress.country',
                whereIn: countries);
          }
          return query.count().get();
        }),
      );

      final total =
          counts.fold<int>(0, (sum, snapshot) => sum + (snapshot.count ?? 0));
      if (mounted) setState(() => _totalPending = total);
    } catch (e) {
      debugPrint('QC: could not count pending registrations: $e');
    }
  }

  /// Die gerade laufende Seitenabfrage.
  ///
  /// Wer währenddessen nachlädt, bekommt dieselbe Zukunft zurück statt ein
  /// stilles "mache ich nicht" - sonst dreht [_loadAllRemaining] leer, während
  /// die Fusszeile schon eine Seite holt.
  Future<void>? _pageInFlight;

  Future<void> _loadNextPage({bool initial = false}) {
    final running = _pageInFlight;
    if (running != null) return running;
    if (!_hasMore && !initial) return Future.value();

    final future = _loadPage(initial: initial)
        .whenComplete(() => _pageInFlight = null);
    _pageInFlight = future;
    return future;
  }

  /// Lädt die nächste Portion und hängt sie an die Liste an.
  ///
  /// Zwei Phasen: zuerst über die Erzeugungsmethoden, die als einzige ein
  /// Datum tragen - das ergibt die global korrekte Reihenfolge "neueste
  /// zuerst". Sind die durch, folgt ein Durchlauf über die Objekte selbst, der
  /// alles einsammelt, was dabei nicht aufgetaucht ist.
  Future<void> _loadPage({bool initial = false}) async {
    if (_useIndex) {
      await _loadIndexPage(initial: initial);
      return;
    }
    final generation = _queryGeneration;
    _loadingMore = true;
    if (!initial && mounted) setState(() {});

    final collected = <_QcEntry>[];

    try {
      // Eine Methodenseite liefert nur die Registrierungen, die noch offen
      // sind - der Rest ist längst entschieden. Deshalb weitersuchen, bis
      // genug zusammenkommt.
      int rounds = 0;
      while (collected.length < _targetPerLoad &&
          !_methodsExhausted &&
          rounds < 5) {
        rounds++;
        // Was sicher außerhalb des Gebiets liegt, zählt nicht mit - sonst
        // stünde ein Koordinator in Kenia vor einer fast leeren Seite.
        collected.addAll(
            (await _loadFromCreationMethods()).where(_mayBeInScope));
      }

      if (collected.length < _targetPerLoad && _methodsExhausted) {
        collected.addAll((await _loadFromObjects()).where(_mayBeInScope));
      }

      final newBundles = await _groupIntoBundles(collected);

      if (!mounted || generation != _queryGeneration) return;
      setState(() {
        _pendingRegistrations = [..._pendingRegistrations, ...collected];
        _bundles = [..._bundles, ...newBundles];
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading pending registrations from cloud: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Phase 1: eine Seite Erzeugungsmethoden, absteigend nach Zeitpunkt.
  ///
  /// Datum und Registrar stehen damit schon fest, bevor das Objekt geladen ist
  /// - der frühere Einzelabruf je Eintrag entfällt vollständig.
  Future<List<_QcEntry>> _loadFromCreationMethods() async {
    try {
      var query = FirebaseFirestore.instance
          .collection('TFC_methods')
          .where('template.RALType', isEqualTo: 'generateDigitalSibling')
          .orderBy('existenceStarts', descending: true)
          .limit(_methodPageSize);
      if (_methodCursor != null) {
        query = query.startAfterDocument(_methodCursor!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.length < _methodPageSize) _methodsExhausted = true;
      if (snapshot.docs.isNotEmpty) _methodCursor = snapshot.docs.last;

      // Objekt-UID je Methode - das Ziel der Erzeugung.
      final methodByObjectUid = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = _createdObjectUid(data);
        if (uid == null || uid.isEmpty) continue;
        if (_loadedUids.contains(uid)) continue;
        methodByObjectUid.putIfAbsent(uid, () => data);
      }
      if (methodByObjectUid.isEmpty) return const [];

      final objects = await _fetchObjects(methodByObjectUid.keys.toList());

      final entries = <_QcEntry>[];
      for (final entry in methodByObjectUid.entries) {
        final obj = objects[entry.key];
        if (obj == null) continue;
        // Nur was noch zur Entscheidung ansteht - der Rest ist erledigt.
        if (obj['objectState'] != 'qcPending') continue;
        final ralType = obj['template']?['RALType'];
        if (ralType != 'farm' && ralType != 'human' && ralType != 'field') {
          continue;
        }
        _loadedUids.add(entry.key);
        entries.add(_entryFromObject(obj, entry.value));
      }
      return entries;
    } catch (e) {
      // Fehlt der zusammengesetzte Index, liefert Firestore hier einen Fehler
      // samt Anlege-Link. Die Warteschlange soll deswegen nicht leer bleiben:
      // Phase 2 übernimmt, dann eben ohne globale Datumssortierung.
      debugPrint('QC: creation-method query unavailable ($e) - '
          'falling back to scanning objects');
      _methodsExhausted = true;
      // Nur melden, wenn noch gar nichts über die Methoden hereinkam - sonst
      // war es das reguläre Ende der Liste.
      if (_methodCursor == null) _dateOrderUnavailable = true;
      return const [];
    }
  }

  /// UID des Objekts, das eine Erzeugungsmethode hervorgebracht hat.
  String? _createdObjectUid(Map<String, dynamic> method) {
    final outputs = method['outputObjects'];
    if (outputs is List) {
      for (final output in outputs) {
        if (output is Map) {
          final uid = output['identity']?['UID']?.toString();
          if (uid != null && uid.isNotEmpty) return uid;
        }
      }
    }
    final refs = method['outputObjectsRef'];
    if (refs is List) {
      for (final ref in refs) {
        if (ref is Map) {
          final uid = ref['UID']?.toString();
          if (uid != null && uid.isNotEmpty) return uid;
        }
      }
    }
    return null;
  }

  /// Phase 2: Durchlauf über die offenen Objekte selbst.
  ///
  /// Fängt auf, was in Phase 1 nicht auftauchen konnte - etwa Registrierungen,
  /// deren Erzeugungsmethode kein `existenceStarts` trägt. Solche Einträge
  /// haben kein Datum und sortieren deshalb ans Ende.
  Future<List<_QcEntry>> _loadFromObjects() async {
    if (_objectsExhausted) return const [];

    Query<Map<String, dynamic>> pageQuery() {
      var query = _pendingQuery();
      if (_objectCursor != null) {
        query = query.startAfterDocument(_objectCursor!);
      }
      return query;
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await pageQuery().get();
    } catch (e) {
      if (_scopeCountryValues == null) rethrow;
      // Lehnt Firestore den Länderfilter ab (z.B. fehlender Index), filtert
      // eben nur der Client - die Warteschlange darf nicht leer bleiben.
      debugPrint('QC: country filter unavailable ($e) - filtering locally');
      _serverCountryFilter = false;
      snapshot = await pageQuery().get();
    }
    if (snapshot.docs.length < _pageSize) _objectsExhausted = true;
    if (snapshot.docs.isNotEmpty) _objectCursor = snapshot.docs.last;

    final objects = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final obj = doc.data();
      final uid = obj['identity']?['UID']?.toString() ?? '';
      if (uid.isEmpty || _loadedUids.contains(uid)) continue;
      final ralType = obj['template']?['RALType'] ?? 'unknown';
      if (ralType == 'farm' || ralType == 'human' || ralType == 'field') {
        _loadedUids.add(uid);
        objects.add(obj);
      }
    }

    return _buildEntries(objects);
  }

  /// Holt Objekt-Dokumente in Zehnerbündeln (Grenze von `whereIn`).
  Future<Map<String, Map<String, dynamic>>> _fetchObjects(
      List<String> uids) async {
    final result = <String, Map<String, dynamic>>{};
    if (uids.isEmpty) return result;

    final chunks = <List<String>>[];
    for (int i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, math.min(i + 10, uids.length)));
    }

    final snapshots = await Future.wait(chunks.map((chunk) =>
        FirebaseFirestore.instance
            .collection('TFC_objects')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()));

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  /// Ordnet neu geladene offene Objekte ihrer Farm zu und baut für jede noch
  /// unbekannte Farm das Bündel aus Farm, Farmer und allen offenen Feldern.
  ///
  /// Ausgangspunkt sind bewusst alle offenen Objekte, nicht nur offene Farmen:
  /// Felder lassen sich nachträglich an eine bereits freigegebene Farm hängen
  /// und würden in einer reinen Farm-Warteschlange nie auftauchen.
  Future<List<_QcBundle>> _groupIntoBundles(List<_QcEntry> entries) async {
    final created = <String, _QcBundle>{};
    _QcBundle? bundleFor(String key) => created[key] ??
        _bundles.cast<_QcBundle?>().firstWhere((b) => b!.key == key,
            orElse: () => null);

    // 1. Farm-UID je Eintrag.
    final farmUidsByEntry = <String, List<String>>{};
    final unresolvedOwners = <String>[];
    for (final entry in entries) {
      if (entry.uid.isEmpty) continue;
      switch (entry.ralType) {
        case 'farm':
          farmUidsByEntry[entry.uid] = [entry.uid];
          break;
        case 'field':
          final farmUid = _farmUidOfField(entry.object);
          if (farmUid != null) farmUidsByEntry[entry.uid] = [farmUid];
          break;
        case 'human':
          unresolvedOwners.add(entry.uid);
          break;
      }
    }

    // Der Farmer kennt seine Farm nicht - nur die Farm verweist auf ihn.
    final farmObjects = <String, Map<String, dynamic>>{
      for (final e in entries)
        if (e.ralType == 'farm') e.uid: e.object,
    };
    if (unresolvedOwners.isNotEmpty) {
      final farms = await _fetchFarmsByOwner(unresolvedOwners);
      for (final farm in farms) {
        final farmUid = _QcBundle.uidOf(farm);
        final ownerUid = _ownerUidOfFarm(farm);
        if (farmUid.isEmpty || ownerUid == null) continue;
        farmObjects.putIfAbsent(farmUid, () => farm);
        (farmUidsByEntry[ownerUid] ??= []).add(farmUid);
      }
    }

    // 2. Farmen, für die es noch kein Bündel gibt.
    final newFarmUids = <String>{
      for (final uids in farmUidsByEntry.values)
        for (final uid in uids)
          if (bundleFor(uid) == null) uid,
    };
    final missingFarms =
        newFarmUids.where((uid) => !farmObjects.containsKey(uid)).toList();
    farmObjects.addAll(await _fetchObjects(missingFarms));

    final foundFarmUids =
        newFarmUids.where((uid) => farmObjects.containsKey(uid)).toList();
    final entryObjects = {for (final e in entries) e.uid: e.object};

    // 3. Farmer und offene Felder der neuen Farmen - je ein Sammelabruf.
    final ownerUids = <String>{
      for (final uid in foundFarmUids)
        if (_ownerUidOfFarm(farmObjects[uid]!) case final owner?) owner,
    };
    final farmers = await _fetchObjects(
        ownerUids.where((uid) => !entryObjects.containsKey(uid)).toList());
    farmers.addAll({
      for (final uid in ownerUids)
        if (entryObjects[uid] != null) uid: entryObjects[uid]!,
    });
    final fieldsByFarm = await _fetchPendingFieldsOfFarms(foundFarmUids);

    for (final farmUid in foundFarmUids) {
      final farm = farmObjects[farmUid]!;
      final bundle = _QcBundle(
        key: farmUid,
        farm: farm,
        farmer: farmers[_ownerUidOfFarm(farm)],
      );
      bundle.fields.addAll(fieldsByFarm[farmUid] ?? const []);
      created[farmUid] = bundle;
    }

    // 4. Einträge in ihre Bündel einhängen; ohne auffindbare Farm bekommt das
    // Objekt ein eigenes Bündel, damit es nicht aus der Warteschlange fällt.
    for (final entry in entries) {
      if (entry.uid.isEmpty) continue;
      final farmUids = farmUidsByEntry[entry.uid] ?? const <String>[];
      final targets =
          farmUids.map(bundleFor).whereType<_QcBundle>().toList();

      if (targets.isEmpty) {
        final orphan = bundleFor(entry.uid) ??
            (created[entry.uid] = _QcBundle(key: entry.uid));
        if (entry.ralType == 'field') {
          if (!orphan.contains(entry.uid)) orphan.fields.add(entry.object);
        } else if (entry.ralType == 'human') {
          orphan.farmer = entry.object;
        } else {
          orphan.farm = entry.object;
        }
        orphan.absorbEntry(entry);
        continue;
      }

      for (final bundle in targets) {
        if (entry.ralType == 'field' && !bundle.contains(entry.uid)) {
          bundle.fields.add(entry.object);
        }
        if (entry.ralType == 'human' && bundle.farmer == null) {
          bundle.farmer = entry.object;
        }
        bundle.absorbEntry(entry);
      }
    }

    return created.values.toList();
  }

  String? _farmUidOfField(Map<String, dynamic> field) {
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

  String? _ownerUidOfFarm(Map<String, dynamic> farm) {
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

  /// Farmen, die einen der Farmer als Eigentümer verknüpfen - in Zehnerbündeln
  /// (Grenze von `arrayContainsAny`).
  Future<List<Map<String, dynamic>>> _fetchFarmsByOwner(
      List<String> ownerUids) async {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < ownerUids.length; i += 10) {
      final chunk = ownerUids.sublist(i, math.min(i + 10, ownerUids.length));
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('TFC_objects')
            .where('linkedObjectRef',
                arrayContainsAny: [
                  for (final uid in chunk)
                    {'RALType': 'human', 'UID': uid, 'role': 'owner'},
                ])
            .get();
        for (final doc in snapshot.docs) {
          if (doc.data()['template']?['RALType'] == 'farm') {
            result.add(doc.data());
          }
        }
      } catch (e) {
        debugPrint('QC: could not resolve farms of farmers: $e');
      }
    }
    return result;
  }

  /// Alle offenen Felder der Farmen, nach Farm-UID gruppiert.
  Future<Map<String, List<Map<String, dynamic>>>> _fetchPendingFieldsOfFarms(
      List<String> farmUids) async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (int i = 0; i < farmUids.length; i += 10) {
      final chunk = farmUids.sublist(i, math.min(i + 10, farmUids.length));
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('TFC_objects')
            .where('currentGeolocation.container.UID', whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final obj = doc.data();
          if (obj['template']?['RALType'] != 'field') continue;
          if (!_QcBundle.isPending(obj)) continue;
          final farmUid = _farmUidOfField(obj);
          if (farmUid != null) (result[farmUid] ??= []).add(obj);
        }
      } catch (e) {
        // Ohne diese Abfrage fehlen nur die Felder, die noch nicht über die
        // Seitenabfrage hereingekommen sind - die übrigen hängt Schritt 4 an.
        debugPrint('QC: could not load fields of farms: $e');
      }
    }
    return result;
  }

  /// Lädt alle verbleibenden Seiten - für die Übersichtskarte, die nur zeigen
  /// kann, was geladen ist.
  Future<void> _loadAllRemaining() async {
    // Obergrenze als Notbremse: eine Schleife über Netzwerkabfragen, die aus
    // irgendeinem Grund nicht vorankommt, darf die App nicht festhalten.
    for (int page = 0; page < 200 && _hasMore && mounted; page++) {
      await _loadNextPage();
    }
  }

  /// Ob die Cloud den Suchindex vollständig aufgebaut hat.
  Future<bool> _indexReady() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('TFC_qc_index_meta')
          .doc('state')
          .get();
      return doc.data()?['ready'] == true;
    } catch (e) {
      debugPrint('QC: index state unavailable ($e) - using the full scan');
      return false;
    }
  }

  /// Abfrage über den QC-Index mit Gebiet, Filtern und Suchbegriff.
  ///
  /// Für jede Kombination aus Filtern und Sortierung braucht Firestore einen
  /// zusammengesetzten Index (firestore.indexes.json).
  Query<Map<String, dynamic>> _indexQuery({bool ordered = true}) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('TFC_qc_index');

    final scope = _scope;
    final scopeCountries =
        scope == null || scope.isEmpty ? null : scope.countries;
    final country = _countryFilter ??
        (scopeCountries?.length == 1 ? scopeCountries!.first : null);
    if (country != null) {
      query = query.where('countryCode', isEqualTo: country);
    } else if (scopeCountries != null && scopeCountries.length <= 30) {
      query = query.where('countryCode', whereIn: scopeCountries);
    }

    if (_stateFilter != null) {
      query = query.where('stateKey', isEqualTo: foldForSearch(_stateFilter!));
    } else if (country != null) {
      // Gebiet auf Regionen beschränkt: gleich in der Abfrage, sonst stünde
      // ein Koordinator für ein Departamento vor lauter leeren Seiten.
      final regions = scope?.entryFor(country)?.regions ?? const <String>[];
      if (regions.isNotEmpty && regions.length <= 30) {
        query = query.where('stateKey',
            whereIn: regions.map(foldForSearch).toSet().toList());
      }
    }

    if (_registrarFilter != 'all') {
      query = query.where('registrarUid', isEqualTo: _registrarFilter);
    }

    final token = qcServerToken(qcQueryTokens(_serverQuery));
    if (token != null) query = query.where('tokens', arrayContains: token);

    if (!ordered) return query;
    // Mit Suchbegriff nur nach Datum: jede weitere Sortierung bräuchte einen
    // eigenen Firestore-Index je Filterkombination.
    final sort = token != null ? _QcSort.dateDesc : _sortMode;
    query = switch (sort) {
      _QcSort.dateDesc => query.orderBy('registeredAt', descending: true),
      _QcSort.dateAsc => query.orderBy('registeredAt'),
      _QcSort.registrar => query.orderBy('registrarKey'),
      _QcSort.name => query.orderBy('nameKey'),
    };
    return query.limit(_indexPageSize);
  }

  /// Nächste Seite aus dem QC-Index.
  Future<void> _loadIndexPage({bool initial = false}) async {
    final generation = _queryGeneration;
    _loadingMore = true;
    if (!initial && mounted) setState(() {});

    final queryTokens = qcQueryTokens(_serverQuery);
    final collected = <_QcBundle>[];
    try {
      // Teamfilter und Gebiete mit Regionen in mehreren Ländern prüft der
      // Client - dann weiterblättern, bis etwas zu zeigen ist.
      int rounds = 0;
      while (!_indexExhausted &&
          rounds < 5 &&
          collected.where(_isVisible).length < 10) {
        rounds++;
        var query = _indexQuery();
        if (_indexCursor != null) {
          query = query.startAfterDocument(_indexCursor!);
        }
        final snapshot = await query.get();
        if (generation != _queryGeneration) return;
        if (snapshot.docs.length < _indexPageSize) _indexExhausted = true;
        if (snapshot.docs.isNotEmpty) _indexCursor = snapshot.docs.last;

        // Die Abfrage kann nur einen Suchbegriff - die übrigen hier.
        final docs = snapshot.docs
            .where((d) => qcTokensMatch(
                List<String>.from(d.data()['tokens'] ?? const []),
                queryTokens))
            .toList();
        collected.addAll(await _bundlesFromIndex(docs));
        if (generation != _queryGeneration) return;
      }

      if (!mounted) return;
      setState(() {
        _bundles = [..._bundles, ...collected];
        _loadingMore = false;
      });
    } catch (e) {
      if (generation != _queryGeneration) return;
      // Meist fehlt ein zusammengesetzter Index - die Meldung enthält den
      // Link, über den er sich anlegen lässt.
      debugPrint('QC: index query failed ($e) - falling back to the full scan');
      cloudLogService.warn('QC: index query failed',
          data: {'error': e.toString()});
      _useIndex = false;
      _indexUnavailable = true;
      _loadingMore = false;
      if (mounted) {
        setState(() {});
        await _loadPage(initial: initial);
      }
    }
  }

  /// Baut die Bündel einer Indexseite: Farm, Farmer und offene Felder in
  /// einem Sammelabruf, Datum und Registrar direkt aus dem Index.
  Future<List<_QcBundle>> _bundlesFromIndex(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final known = _bundles.map((b) => b.key).toSet();
    final fresh = docs.where((d) => !known.contains(d.id)).toList();

    String? uidField(Map<String, dynamic> data, String key) {
      final value = data[key]?.toString() ?? '';
      return value.isEmpty ? null : value;
    }

    List<String> fieldUids(Map<String, dynamic> data) =>
        List<String>.from(data['fieldUids'] ?? const []);

    final uids = <String>{
      for (final doc in fresh) ...[
        if (uidField(doc.data(), 'farmUid') case final uid?) uid,
        if (uidField(doc.data(), 'farmerUid') case final uid?) uid,
        ...fieldUids(doc.data()),
      ],
    };
    final objects = await _fetchObjects(uids.toList());

    final bundles = <_QcBundle>[];
    for (final doc in fresh) {
      final data = doc.data();
      final bundle = _QcBundle(
        key: doc.id,
        farm: objects[uidField(data, 'farmUid')],
        farmer: objects[uidField(data, 'farmerUid')],
      );
      for (final uid in fieldUids(data)) {
        final field = objects[uid];
        if (field != null && _QcBundle.isPending(field)) {
          bundle.fields.add(field);
        }
      }
      // Der Index folgt den Objekten mit kurzem Abstand - was inzwischen
      // entschieden ist, gehört nicht mehr in die Warteschlange.
      if (bundle.pendingMembers.isEmpty) continue;

      final registeredAt = data['registeredAt'];
      if (registeredAt is Timestamp &&
          registeredAt.millisecondsSinceEpoch > 0) {
        bundle.registeredAt = registeredAt.toDate().toUtc();
      }
      final registrarName = data['registrarName']?.toString() ?? '';
      bundle.registrarName = registrarName.isEmpty ? '-' : registrarName;
      bundle.registrarUid = data['registrarUid']?.toString() ?? '';
      bundle.registrarEmail = data['registrarEmail']?.toString() ?? '';
      bundle.indexTokens = Set<String>.from(data['tokens'] ?? const []);
      if (bundle.registrarUid.isNotEmpty) {
        _knownRegistrars[bundle.registrarUid] = (
          name: bundle.registrarName,
          email: bundle.registrarEmail,
          label: bundle.registrarLabel,
        );
      }

      for (final member in bundle.pendingMembers) {
        final uid = _QcBundle.uidOf(member);
        _loadedUids.add(uid);
        _pendingRegistrations.add(_QcEntry(
          object: member,
          ralType: member['template']?['RALType']?.toString() ?? '',
          name: member['identity']?['name']?.toString() ?? 'Unnamed',
          registeredAt: bundle.registeredAt,
          registrarName: bundle.registrarName,
          registrarUid: bundle.registrarUid,
          registrarEmail: bundle.registrarEmail,
        ));
      }
      bundles.add(bundle);
    }
    return bundles;
  }

  /// Lädt die Liste nach einer Änderung von Filter, Sortierung oder Suche
  /// neu - nur mit Index, sonst filtert der Client das Geladene.
  void _reloadIfIndexed() {
    if (_useIndex) {
      unawaited(_loadPendingRegistrations(keepReviewState: true));
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    if (!_useIndex) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final changed =
          qcQueryTokens(_serverQuery).join(' ') != qcQueryTokens(value).join(' ');
      _serverQuery = value;
      if (changed) _reloadIfIndexed();
    });
  }

  /// Gezählt wird, was die Gesamtzahl auch zählt: mit Index Prüfeinheiten,
  /// sonst offene Objekte.
  int get _loadedCount =>
      _useIndex ? _bundles.length : _pendingRegistrations.length;

  /// Löst Datum und Registrar für eine ganze Seite auf.
  ///
  /// Beides steht an der Erzeugungsmethode, nicht am Objekt. Ein Einzelabruf je
  /// Eintrag wären hunderte Rundreisen pro Seite; gefragt wird deshalb in
  /// Bündeln von zehn Methoden-IDs.
  Future<List<_QcEntry>> _buildEntries(
      List<Map<String, dynamic>> objects) async {
    final methodUidByObject = <String, String>{};
    final methodUids = <String>{};

    for (final obj in objects) {
      final objectUid = obj['identity']?['UID']?.toString() ?? '';
      final methodHistoryRef = obj['methodHistoryRef'];
      if (objectUid.isEmpty || methodHistoryRef is! List) continue;
      if (methodHistoryRef.isEmpty) continue;

      final first = methodHistoryRef.first;
      if (first is! Map) continue;
      final methodUid = first['UID']?.toString();
      if (methodUid == null || methodUid.isEmpty) continue;

      methodUidByObject[objectUid] = methodUid;
      methodUids.add(methodUid);
    }

    final methods = await _fetchMethods(methodUids.toList());

    return [
      for (final obj in objects)
        _entryFromObject(
          obj,
          methods[methodUidByObject[obj['identity']?['UID']?.toString() ?? '']],
        ),
    ];
  }

  /// Holt Methoden-Dokumente in Zehnerbündeln (Grenze von `whereIn`).
  Future<Map<String, Map<String, dynamic>>> _fetchMethods(
      List<String> uids) async {
    final result = <String, Map<String, dynamic>>{};
    if (uids.isEmpty) return result;

    final chunks = <List<String>>[];
    for (int i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, math.min(i + 10, uids.length)));
    }

    final snapshots = await Future.wait(chunks.map((chunk) =>
        FirebaseFirestore.instance
            .collection('TFC_methods')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()));

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  /// Baut den Listeneintrag aus Objekt und - falls vorhanden - der zugehörigen
  /// Erzeugungsmethode, aus der Registrierungsdatum und Registrar stammen.
  _QcEntry _entryFromObject(
      Map<String, dynamic> obj, Map<String, dynamic>? methodData) {
    final ralType = obj['template']?['RALType']?.toString() ?? 'unknown';
    final name = obj['identity']?['name']?.toString() ?? 'Unnamed';
    final objectUid = obj['identity']?['UID']?.toString() ?? '';

    final alternateIds = <String>[];
    final rawAltIds = obj['identity']?['alternateIDs'];
    if (rawAltIds is List) {
      for (final a in rawAltIds) {
        final id = a is Map ? a['UID']?.toString() : a?.toString();
        if (id != null && id.isNotEmpty) alternateIds.add(id);
      }
    }

    DateTime? registeredAt;
    String registrarName = '-';
    String registrarUid = '';
    String registrarEmail = '';

    if (methodData != null) {
      try {
        registeredAt =
            DateTime.tryParse(methodData['existenceStarts']?.toString() ?? '');
        final executor = methodData['executor'];
        if (executor is Map) {
          final executorIdentity = executor['identity'];
          if (executorIdentity is Map) {
            registrarName =
                executorIdentity['name']?.toString().trim().isNotEmpty == true
                    ? executorIdentity['name'].toString()
                    : '-';
            registrarUid = executorIdentity['UID']?.toString() ?? '';
          }
          registrarEmail = _extractEmail(executor);
        }
      } catch (e) {
        debugPrint('QC: could not read metadata for $objectUid: $e');
      }
    }

    if (objectUid.isNotEmpty) {
      _registrarCache[objectUid] = {
        'name': registrarName,
        'uid': registrarUid,
      };
    }

    return _QcEntry(
      object: obj,
      ralType: ralType,
      name: name,
      registeredAt: registeredAt,
      registrarName: registrarName,
      registrarUid: registrarUid,
      registrarEmail: registrarEmail,
      alternateIds: alternateIds,
    );
  }

  /// Mail address of an app user object - stored top level for accounts created
  /// by the app, as a specific property for imported ones.
  String _extractEmail(Map userDoc) {
    final topLevel = userDoc['email']?.toString().trim() ?? '';
    if (topLevel.isNotEmpty) return topLevel;

    final specific =
        getSpecificPropertyfromJSON(Map<String, dynamic>.from(userDoc), 'email')
                ?.toString()
                .trim() ??
            '';
    if (specific.isEmpty || specific == '-no data found-') return '';
    return specific;
  }

  /// All registrars present in the current result set, for the dropdown.
  Map<String, ({String name, String email, String label})>
      get _availableRegistrars {
    final map = <String, ({String name, String email, String label})>{
      if (_useIndex) ..._knownRegistrars,
    };
    for (final bundle in _visibleBundles) {
      if (bundle.registrarUid.isEmpty) continue;
      map[bundle.registrarUid] = (
        name: bundle.registrarName,
        email: bundle.registrarEmail,
        label: bundle.registrarLabel,
      );
    }
    return map;
  }

  List<_QcBundle> get _filteredBundles {
    final query = _searchQuery.trim().toLowerCase();

    final result = _visibleBundles.where((bundle) {
      if (_registrarFilter != 'all' &&
          bundle.registrarUid != _registrarFilter) {
        return false;
      }
      if (query.isNotEmpty && !_matchesSearch(bundle, query)) {
        return false;
      }
      return true;
    }).toList();

    // Undated entries sort last in both directions - "unknown" is not "oldest".
    int byDate(_QcBundle a, _QcBundle b, {required bool descending}) {
      if (a.registeredAt == null && b.registeredAt == null) return 0;
      if (a.registeredAt == null) return 1;
      if (b.registeredAt == null) return -1;
      return descending
          ? b.registeredAt!.compareTo(a.registeredAt!)
          : a.registeredAt!.compareTo(b.registeredAt!);
    }

    switch (_sortMode) {
      case _QcSort.dateDesc:
        result.sort((a, b) => byDate(a, b, descending: true));
        break;
      case _QcSort.dateAsc:
        result.sort((a, b) => byDate(a, b, descending: false));
        break;
      case _QcSort.registrar:
        result.sort((a, b) {
          // By label, not by name: nameless registrars would all collapse into
          // one "-" block and mix different people together.
          final cmp = a.registrarLabel
              .toLowerCase()
              .compareTo(b.registrarLabel.toLowerCase());
          // Within one registrar the newest registration first.
          return cmp != 0 ? cmp : byDate(a, b, descending: true);
        });
        break;
      case _QcSort.name:
        result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return result;
  }

  /// Bündel aus dem Index werden über ihre Suchbegriffe geprüft - dieselben,
  /// die schon die Abfrage verwendet hat ("gomez" findet "Gómez").
  bool _matchesSearch(_QcBundle bundle, String query) {
    final tokens = bundle.indexTokens;
    if (tokens != null) {
      final queryTokens = qcQueryTokens(query);
      if (queryTokens.isNotEmpty) return qcTokensMatch(tokens, queryTokens);
    }
    return bundle.searchIndex.contains(query);
  }

  /// Die Prüfpunkte eines Bündels: je offenem Objekt ein Punkt pro Pflichtfoto
  /// und pro verknüpftem optionalen Foto, bei Feldern zusätzlich die Freigabe
  /// der Polygongeometrie.
  List<_QcCheck> _requiredChecks(_QcBundle bundle) {
    final checks = <_QcCheck>[];
    for (final obj in bundle.pendingMembers) {
      final ralType = obj['template']?['RALType']?.toString() ?? '';
      for (final role in _qcPhotoRoles[ralType] ?? const <String>[]) {
        if (requiredPhotoRoles.contains(role) || _hasLinkedPhoto(obj, role)) {
          checks.add(_QcCheck(object: obj, check: role));
        }
      }
      if (ralType == 'field') {
        checks.add(_QcCheck(object: obj, check: _qcPolygonCheck));
      }
    }
    return checks;
  }

  bool _hasLinkedPhoto(Map<String, dynamic> obj, String role) {
    final links = obj['linkedObjectRef'];
    if (links is! List) return false;
    return links.any((link) =>
        link is Map && link['RALType'] == 'image' && link['role'] == role);
  }

  bool _isChecked(_QcBundle bundle, _QcCheck check) =>
      _checks[bundle.key]?.containsKey(check.id) ?? false;

  void _setChecked(_QcBundle bundle, _QcCheck check, bool value) {
    setState(() {
      final checks = _checks.putIfAbsent(bundle.key, () => {});
      if (value) {
        checks[check.id] = DateTime.now().toUtc();
      } else {
        checks.remove(check.id);
      }
    });
  }

  /// Entscheidet ein Bündel als Ganzes und schreibt die Entscheidung samt
  /// Checkliste als einen signierten QC-Job.
  Future<void> _decideBundle(_QcBundle bundle, {required bool approve}) async {
    final l10n = AppLocalizations.of(context)!;
    final checks = _requiredChecks(bundle);
    if (approve && !checks.every((c) => _isChecked(bundle, c))) return;

    final notes = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovalDialog(
        isApproval: approve,
        objectType: bundle.pendingFields.isNotEmpty ? 'field' : 'farm',
      ),
    );
    if (notes == null) return; // Abgebrochen

    _setBusy(l10n.qcSavingDecision);

    try {
      final newState = approve ? 'active' : 'qcRejected';
      final noteKey = approve ? 'approvalNotes' : 'rejectionReason';
      final jobNotes = <String>[if (notes.isNotEmpty) notes];
      final outputs = <Map<String, dynamic>>[];

      for (final member in bundle.pendingMembers) {
        final uid = _QcBundle.uidOf(member);
        // Auf der aktuellen Fassung aufsetzen, nicht auf der Kopie der Karte:
        // eine Polygonkorrektur hat inzwischen etwa die Gesamtfläche der Farm
        // geändert, und die würde sonst wieder überschrieben.
        final current = await getCurrentObjectVersion(uid);
        Map<String, dynamic> updated =
            deepCopyMap(current.isNotEmpty ? current : member);
        String objectNotes = notes;

        if (approve && updated['template']?['RALType'] == 'field') {
          // Separate step: this call goes to an external registry and is the
          // slowest part of an approval.
          _setBusy(l10n.qcRegisteringInAssetRegistry);
          final geoIdResult = await _registerFieldInAssetRegistry(updated);
          if (geoIdResult['geoId'] != null) {
            final identity = updated['identity'] as Map;
            identity['alternateIDs'] = [
              ...(identity['alternateIDs'] as List? ?? const []),
              {'UID': geoIdResult['geoId'], 'issuedBy': 'Asset Registry'},
            ];
          } else if (geoIdResult['error'] != null) {
            final errorNote = l10n.assetRegistryRegistrationFailed(
                geoIdResult['error'] ?? 'Unknown error');
            objectNotes =
                objectNotes.isEmpty ? errorNote : '$objectNotes\n$errorNote';
            jobNotes.add('${updated['identity']?['name'] ?? uid}: $errorNote');
          }
          _setBusy(l10n.qcSavingDecision);
        }

        updated['objectState'] = newState;
        updated = setSpecificPropertyJSON(updated, noteKey, objectNotes, 'String');
        outputs.add(updated);
      }

      // Die verknüpften Fotos teilen das Schicksal ihres Objekts und gehen mit
      // in denselben Job.
      _setBusy(l10n.qcUpdatingPhotos);
      outputs.addAll(await _linkedImagesWithState(outputs, newState));

      final ticked = _checks[bundle.key] ?? const <String, DateTime>{};
      final checklist = [
        for (final check in checks)
          {
            'objectUID': check.objectUid,
            'objectType': check.objectType,
            'check': check.check,
            'checked': ticked.containsKey(check.id),
            'checkedAt': ticked[check.id]?.toIso8601String() ?? '',
          },
      ];

      _setBusy(l10n.qcSavingDecision);
      // Push only. The QC screen reads its data straight from Firestore and is
      // used online, so pulling the whole cloud state back down afterwards adds
      // nothing but wait time before the UI is usable again.
      await performQualityControl(
        newObjectVersions: outputs,
        decision: approve ? 'approved' : 'rejected',
        notes: jobNotes.join('\n'),
        checklist: checklist,
        subjectUID: bundle.key,
        syncFromCloud: false,
      );

      repaintContainerList.value = true;
      _removeBundleLocally(bundle, outputs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? l10n.registrationApproved
                : l10n.registrationRejected),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deciding QC bundle ${bundle.key}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setBusy(null);
    }
  }

  /// Registriert ein Field-Objekt bei der Asset Registry und gibt die GeoID zurück
  /// Rückgabe: {'geoId': String?, 'error': String?}
  Future<Map<String, String?>> _registerFieldInAssetRegistry(
      Map<String, dynamic> fieldObject) async {
    UserRegistryService? userRegistryService;
    AssetRegistryService? assetRegistryService;

    try {
      // Extrahiere Feldgrenzen aus dem Field-Objekt
      final boundariesJson =
          getSpecificPropertyfromJSON(fieldObject, 'boundaries');
      if (boundariesJson == null) {
        return {'geoId': null, 'error': 'No boundaries found in field object'};
      }

      // Parse boundaries (sollte WKT-Format sein)
      String wktCoordinates;
      try {
        final boundaries = jsonDecode(boundariesJson);
        if (boundaries['coordinates'] != null) {
          // Konvertiere GeoJSON zu WKT
          wktCoordinates = _convertGeoJSONToWKT(boundaries['coordinates']);
        } else {
          return {'geoId': null, 'error': 'Invalid boundaries format'};
        }
      } catch (e) {
        return {'geoId': null, 'error': 'Failed to parse boundaries: $e'};
      }

      // Initialisiere User Registry Service
      userRegistryService = UserRegistryService();
      await userRegistryService.initialize();

      // Hole Credentials aus .env
      final userEmail = dotenv.env['USER_REGISTRY_EMAIL'] ?? '';
      final userPassword = dotenv.env['USER_REGISTRY_PASSWORD'] ?? '';

      if (userEmail.isEmpty || userPassword.isEmpty) {
        return {
          'geoId': null,
          'error': 'User Registry credentials not configured'
        };
      }

      // Login
      final loginSuccess = await userRegistryService.login(
        email: userEmail,
        password: userPassword,
      );

      if (!loginSuccess) {
        return {'geoId': null, 'error': 'User Registry login failed'};
      }

      // Erstelle Asset Registry Service
      assetRegistryService = await AssetRegistryService.withUserRegistry(
        userRegistryService: userRegistryService,
      );

      // Registriere Field Boundary
      final registerResponse = await assetRegistryService.registerFieldBoundary(
        s2Index: '8, 13',
        wkt: wktCoordinates,
      );

      String? geoId;
      if (registerResponse.statusCode == 200) {
        // Neu registriert
        final responseData =
            jsonDecode(registerResponse.body) as Map<String, dynamic>;
        geoId = responseData['geoid'] as String?;
        if (geoId != null) {
          return {'geoId': geoId, 'error': null};
        } else {
          return {'geoId': null, 'error': 'No geoID in response'};
        }
      } else if (registerResponse.statusCode == 400) {
        // Bereits registriert
        final responseData =
            jsonDecode(registerResponse.body) as Map<String, dynamic>;
        final matchedGeoIds = responseData['matched geo ids'] as List<dynamic>?;
        if (matchedGeoIds != null && matchedGeoIds.isNotEmpty) {
          geoId = matchedGeoIds.first as String;
          return {'geoId': geoId, 'error': null};
        } else {
          return {'geoId': null, 'error': 'No matched geo ids in response'};
        }
      } else {
        return {
          'geoId': null,
          'error': 'Asset Registry API error: ${registerResponse.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('Error registering field in Asset Registry: $e');
      return {'geoId': null, 'error': e.toString()};
    } finally {
      // Logout
      if (userRegistryService != null) {
        try {
          await userRegistryService.logout();
        } catch (e) {
          debugPrint('Error logging out from User Registry: $e');
        }
      }
    }
  }

  /// Konvertiert GeoJSON-Koordinaten (List<List<double>>) zu WKT-Format
  String _convertGeoJSONToWKT(dynamic coordinates) {
    if (coordinates is! List) {
      throw Exception('Invalid coordinates format');
    }

    List<String> wktCoordinates = [];
    for (var point in coordinates) {
      if (point is List && point.length == 2) {
        // GeoJSON hat [lon, lat], WKT braucht "lon lat"
        final lon = point[0];
        final lat = point[1];
        wktCoordinates.add('$lon $lat');
      }
    }

    if (wktCoordinates.isEmpty) {
      throw Exception('No valid coordinates found');
    }

    // Stelle sicher, dass das Polygon geschlossen ist
    if (wktCoordinates.first != wktCoordinates.last) {
      wktCoordinates.add(wktCoordinates.first);
    }

    return 'POLYGON ((${wktCoordinates.join(', ')}))';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewPendingRegistrations),
        actions: [
          // IHCafe-Verzeichnis: liegt bewusst nur hier beim Registrar
          // Coordinator, nicht im Registrar-Workflow - der komplette Export
          // soll nicht auf die Registrar-Phones geladen werden.
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? l10n.qcShowListView : l10n.qcShowMapView,
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: l10n.ihcafeDirectoryTitle,
            onPressed: _showIhcafeDirectory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRegistrations,
          ),
          if (RoleManagementService().getCurrentUserRole() == 'SUPERADMIN')
            IconButton(
              icon: const Icon(Icons.manage_search),
              tooltip: l10n.qcRebuildIndex,
              onPressed: _rebuildIndex,
            ),
          const HandbookButton(),
        ],
      ),
      body: Column(
        children: [
          if (_dateOrderUnavailable)
            _buildWarningBanner(l10n.qcDateOrderUnavailable),
          if (_indexUnavailable) _buildWarningBanner(l10n.qcIndexUnavailable),
          _buildScopeRow(l10n),
          _buildLocationRow(l10n),
          _buildSearchField(l10n),
          _buildSortAndRegistrarRow(l10n),
          const SizedBox(height: 8),
          _buildResultCount(l10n),

          // Liste bzw. Übersichtskarte
          Expanded(
            child: _isLoading
                ? Center(
                    // Falls back to the generic text while l10n is not yet
                    // readable (the first load starts from initState).
                    child: DataLoadingIndicator(
                      text: _loadingMessage ?? l10n.qcLoadingRegistrations,
                    ),
                  )
                : (_showMap
                    ? Column(
                        children: [
                          // Die Karte zeigt nur, was geladen ist - beim
                          // regionsweiten Absuchen muss das sichtbar sein.
                          if (_hasMore) _buildMapLoadHint(l10n),
                          Expanded(
                            child: QcOverviewMap(
                              polygons: _mapPolygons,
                              onPolygonTap: _showPolygonSheet,
                            ),
                          ),
                        ],
                      )
                    : _buildList(l10n)),
          ),
        ],
      ),
    );
  }

  /// Baut den QC-Suchindex aus allen offenen Objekten auf (SUPERADMIN).
  /// Einmal nach dem Deploy nötig, danach pflegt ihn die Cloud selbst.
  Future<void> _rebuildIndex() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qcRebuildIndex,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.qcRebuildIndexInfo,
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.qcRebuildIndexStart),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _setBusy(l10n.qcRebuildIndexProgress(0));
    try {
      final processed = await QcIndexService.rebuild(
          onProgress: (n) => _setBusy(l10n.qcRebuildIndexProgress(n)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.qcRebuildIndexDone(processed)),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('QC: index rebuild failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.qcRebuildIndexFailed}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      _setBusy(null);
    }
    await _loadPendingRegistrations();
  }

  /// Import/Status des IHCafe-Produzentenverzeichnisses.
  ///
  /// Der Import gehört zum QC-Arbeitsplatz des Registrar Coordinators: der
  /// Export ist mehrere MB gross und soll nicht auf jedes Registrar-Phone
  /// geladen werden.
  Future<void> _showIhcafeDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: const SizedBox(
          width: 460,
          child: SingleChildScrollView(child: IhcafeCatalogCard(dense: true)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    // Ohne Gebiet gibt es nichts zu prüfen - das soll nicht wie eine leere
    // Warteschlange aussehen.
    if (_scope?.isEmpty ?? false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                l10n.qcNoTerritory,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final entries = _filteredBundles;

    if (entries.isEmpty && _hasMore) {
      // Der Filter greift nur auf das bereits Geladene. Solange noch Seiten
      // fehlen, ist "nichts gefunden" schlicht nicht wahr - also weitersuchen.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_loadNextPage()));
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _totalPending != null
                  ? l10n.qcLoadedOfTotal(
                      _loadedCount, _totalPending!)
                  : l10n.qcLoadingRegistrations,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty) {
      // Distinguish "nothing to review" from "your filter hides everything" -
      // otherwise an active filter looks like an empty queue.
      final hasActiveFilter = _registrarFilter != 'all' ||
          _teamOnly ||
          _searchQuery.trim().isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasActiveFilter ? Icons.filter_alt_off : Icons.check_circle_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              hasActiveFilter ? l10n.qcNoMatches : l10n.noPendingRegistrations,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (hasActiveFilter) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear),
                label: Text(l10n.all),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) => index == entries.length
          ? _buildLoadMoreFooter(l10n)
          : _buildBundleCard(entries[index]),
    );
  }

  /// Warnung über der Liste, z.B. wenn die Warteschlange nicht global nach
  /// Datum geordnet werden konnte.
  Widget _buildWarningBanner(String text) {
    return Container(
      width: double.infinity,
      color: Colors.orange[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.orange[900]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }

  /// Hinweis über der Übersichtskarte, solange noch Seiten fehlen.
  Widget _buildMapLoadHint(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.amber[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber[900]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _totalPending != null
                  ? l10n.qcLoadedOfTotal(
                      _loadedCount, _totalPending!)
                  : l10n.qcLoadingRegistrations,
              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
            ),
          ),
          TextButton(
            onPressed:
                _loadingMore ? null : () => unawaited(_loadAllRemaining()),
            child: Text(l10n.qcLoadMoreAll),
          ),
        ],
      ),
    );
  }

  /// Fusszeile der Liste. Dass sie gebaut wird, heisst: der Nutzer ist unten
  /// angekommen - das ist der Auslöser für die nächste Portion.
  Widget _buildLoadMoreFooter(AppLocalizations l10n) {
    if (!_loadingMore) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_loadNextPage()));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          if (_totalPending != null)
            Text(
              l10n.qcLoadedOfTotal(_loadedCount, _totalPending!),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          // Die Übersichtskarte kann nur zeigen, was geladen ist - vor dem
          // Umschalten lohnt der Rest am Stück.
          TextButton(
            onPressed: _loadingMore ? null : () => unawaited(_loadAllRemaining()),
            child: Text(l10n.qcLoadMoreAll),
          ),
        ],
      ),
    );
  }

  /// Polygone für die Übersichtskarte - aus denselben Bündeln, die die Liste
  /// zeigt, damit Suche und Filter auf beide Ansichten wirken. Felder ohne
  /// verwertbare Boundaries (abgebrochene Aufnahmen) fallen hier heraus.
  List<QcMapPolygon> get _mapPolygons {
    final result = <QcMapPolygon>[];
    final seen = <String>{}; // PolygonId muss eindeutig sein
    for (final bundle in _filteredBundles) {
      for (final field in bundle.pendingFields) {
        final uid = _QcBundle.uidOf(field);
        if (uid.isEmpty || !seen.add(uid)) continue;
        final points = _getBoundariesFromObject(field);
        if (points == null || points.length < 3) continue;

        final area = getSpecificPropertyfromJSON(field, 'area');
        result.add(QcMapPolygon(
          uid: uid,
          name: field['identity']?['name']?.toString() ?? bundle.name,
          points: points,
          accuracies: _getBoundaryAccuracies(field),
          registrarName: bundle.registrarName,
          areaHa: (area is num) ? area.toDouble() : null,
        ));
      }
    }
    return result;
  }

  /// Springt aus der Übersichtskarte zur Prüfung des Bündels in der Liste.
  void _openBundleReview(_QcBundle bundle) {
    setState(() {
      _showMap = false;
      _focusBundleKey = bundle.key;
      _searchQuery = bundle.key;
      _searchController.text = bundle.key;
    });
  }

  /// Auswahl auf der Übersichtskarte: Eckdaten des Feldes. Entschieden wird
  /// nicht hier, sondern in der Karte der Farm - nur dort ist die Checkliste.
  void _showPolygonSheet(QcMapPolygon polygon) {
    final l10n = AppLocalizations.of(context)!;
    final bundles = _bundles.where((b) => b.contains(polygon.uid));
    if (bundles.isEmpty) return;

    final bundle = bundles.first;
    final obj =
        bundle.fields.firstWhere((f) => _QcBundle.uidOf(f) == polygon.uid);
    final worst = polygon.worstAccuracyValue;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      // Ohne PointerInterceptor erreicht ein Klick auf die Schaltflächen im Web
      // zusätzlich die Karte darunter.
      builder: (sheetContext) => PointerInterceptor(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              polygon.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 12),
            _buildCardMeta(Icons.agriculture, bundle.name),
            const SizedBox(height: 4),
            _buildCardMeta(Icons.person_outline, bundle.registrarName),
            const SizedBox(height: 4),
            _buildCardMeta(
              Icons.event,
              bundle.registeredAt != null
                  ? _formatRegistrationDate(bundle.registeredAt!)
                  : '-',
            ),
            if (polygon.areaHa != null) ...[
              const SizedBox(height: 4),
              _buildCardMeta(
                Icons.crop_square,
                '${l10n.fieldArea}: ${polygon.areaHa!.toStringAsFixed(2)} ha',
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: worst == null
                        ? Colors.blueGrey
                        : gpsAccuracyColor(worst),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.qcMapWorstAccuracy}: '
                  '${worst == null ? l10n.gpsQualityUnknown : '${worst.toStringAsFixed(1)} m'}',
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showDialog(
                      context: context,
                      builder: (_) => _ObjectDetailsDialog(obj: obj),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: Text(l10n.fieldDetails),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showFullScreenMap(obj);
                  },
                  icon: const Icon(Icons.fullscreen),
                  label: Text(l10n.mapView),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openBundleReview(bundle);
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.qcOpenReview),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _focusBundleKey = null;
      _teamOnly = false;
      _registrarFilter = 'all';
      _countryFilter = null;
      _stateFilter = null;
      _searchQuery = '';
      _serverQuery = '';
      _searchController.clear();
    });
    _reloadIfIndexed();
  }

  /// Länder, nach denen gefiltert werden kann: die des Gebiets, ohne Gebiet
  /// alle aktiven.
  List<CountryConfig> get _filterCountries {
    final scope = _scope;
    if (scope != null && !scope.isEmpty) {
      return [
        for (final code in scope.countries)
          if (countryConfigService.byCode(code) case final config?) config,
      ];
    }
    return countryConfigService.active;
  }

  /// Regionen eines Landes, nach denen gefiltert werden kann - bei einem auf
  /// Regionen beschränkten Gebiet nur diese.
  List<String> _filterRegions(CountryConfig country) {
    final entry = _scope?.entryFor(country.code);
    if (entry != null && !entry.wholeCountry) return entry.regions;
    return country.regions;
  }

  /// Filter nach Land und oberster Verwaltungsebene (z.B. Departamento).
  /// Gemeinde und Ort stehen nicht in einer gepflegten Liste - die findet die
  /// Suche.
  Widget _buildLocationRow(AppLocalizations l10n) {
    final countries = _filterCountries;
    final countryCode = _countryFilter ??
        (countries.length == 1 ? countries.first.code : null);
    final country =
        countryCode == null ? null : countryConfigService.byCode(countryCode);
    final regions = country == null ? const <String>[] : _filterRegions(country);
    final showCountry = countries.length > 1;
    final showRegion = regions.length > 1;
    if (!showCountry && !showRegion) return const SizedBox.shrink();

    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          if (showCountry)
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('qc-country-$_countryFilter'),
                initialValue: _countryFilter,
                isDense: true,
                isExpanded: true,
                decoration: decoration(l10n.qcFilterCountry),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(l10n.qcFilterAllCountries)),
                  for (final c in countries)
                    DropdownMenuItem(value: c.code, child: Text(c.name)),
                ],
                onChanged: (value) {
                  if (value == _countryFilter) return;
                  setState(() {
                    _countryFilter = value;
                    _stateFilter = null;
                  });
                  _reloadIfIndexed();
                },
              ),
            ),
          if (showCountry && showRegion) const SizedBox(width: 8),
          if (showRegion)
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('qc-region-$countryCode-$_stateFilter'),
                initialValue: _stateFilter,
                isDense: true,
                isExpanded: true,
                decoration: decoration(country!.regionLabels.isNotEmpty
                    ? country.regionLabels.first
                    : l10n.qcFilterRegion),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(l10n.qcFilterAllRegions)),
                  for (final r in regions)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (value) {
                  if (value == _stateFilter) return;
                  setState(() => _stateFilter = value);
                  _reloadIfIndexed();
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Gebiet des Prüfers und - für Registrar Coordinators - der Teamfilter.
  Widget _buildScopeRow(AppLocalizations l10n) {
    final scope = _scope;
    final showScope = scope != null && !scope.isEmpty;
    final showTeam = _teamUids.length > 1;
    if (!showScope && !showTeam) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      child: Row(
        children: [
          if (showScope) ...[
            Icon(Icons.public, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.qcTerritoryInfo(_scopeLabel(scope)),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ] else
            const Spacer(),
          if (showTeam)
            FilterChip(
              label: Text(l10n.qcMyTeamOnly),
              selected: _teamOnly,
              onSelected: (value) => setState(() {
                _teamOnly = value;
                if (_registrarFilter != 'all' &&
                    !_visibleBundles
                        .any((b) => b.registrarUid == _registrarFilter)) {
                  _registrarFilter = 'all';
                }
              }),
            ),
        ],
      ),
    );
  }

  /// Ort eines Bündels für die Karte, z.B. "La Paz, Honduras".
  String? _locationLabel(_QcBundle bundle) {
    final stored = bundle.storedCountry;
    final country = countryConfigService.resolve(stored)?.name ?? stored;
    final parts = [bundle.stateName, country].where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Gebiet mit Ländernamen statt Codes, z.B. "Kenya: Nyeri · Honduras".
  String _scopeLabel(UserScope scope) => scope.entries.map((e) {
        final name = countryConfigService.byCode(e.country)?.name ?? e.country;
        return e.wholeCountry ? name : '$name: ${e.regions.join(', ')}';
      }).join(' · ');

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: l10n.qcSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildSortAndRegistrarRow(AppLocalizations l10n) {
    final registrars = _availableRegistrars;
    // A registrar dropdown is pointless when everything comes from one person.
    // Auch bei nur einem sichtbaren Registrar, solange danach gefiltert wird -
    // sonst liesse sich der Filter nicht mehr aufheben.
    final showRegistrarFilter =
        registrars.length > 1 || _registrarFilter != 'all';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<_QcSort>(
              initialValue: _sortMode,
              isDense: true,
              decoration: InputDecoration(
                labelText: l10n.sortBy,
                prefixIcon: const Icon(Icons.sort, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: _QcSort.dateDesc,
                  child: Text(l10n.sortByDateDesc),
                ),
                DropdownMenuItem(
                  value: _QcSort.dateAsc,
                  child: Text(l10n.sortByDateAsc),
                ),
                DropdownMenuItem(
                  value: _QcSort.registrar,
                  child: Text(l10n.sortByRegistrar),
                ),
                DropdownMenuItem(
                  value: _QcSort.name,
                  child: Text(l10n.sortByNameAsc),
                ),
              ],
              onChanged: (value) {
                if (value == null || value == _sortMode) return;
                setState(() => _sortMode = value);
                _reloadIfIndexed();
              },
            ),
          ),
          if (showRegistrarFilter) ...[
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: registrars.containsKey(_registrarFilter)
                    ? _registrarFilter
                    : 'all',
                isDense: true,
                isExpanded: true,
                // Two lines per entry (name + mail address) need more room than
                // the default item height.
                itemHeight: 58,
                decoration: InputDecoration(
                  labelText: l10n.registeredBy,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // The closed field is narrow - show the one line that
                // identifies the registrar rather than a truncated pair.
                selectedItemBuilder: (context) => [
                  _registrarFieldLabel(l10n.qcAllRegistrars),
                  ...registrars.values.map((r) => _registrarFieldLabel(
                        r.name.isNotEmpty && r.name != '-' ? r.name : r.email,
                      )),
                ],
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(l10n.qcAllRegistrars),
                  ),
                  ...registrars.entries.map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: _registrarMenuLabel(e.value.name, e.value.email),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == _registrarFilter) return;
                  setState(() => _registrarFilter = value);
                  _reloadIfIndexed();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Single line shown inside the closed registrar filter field.
  Widget _registrarFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.isEmpty ? '-' : text,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Menu entry for one registrar: name on top, mail address below - many
  /// registrars never entered a name, the mail address is what identifies them.
  Widget _registrarMenuLabel(String name, String email) {
    final hasName = name.isNotEmpty && name != '-';
    if (!hasName) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          email.isNotEmpty ? email : '-',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(name, overflow: TextOverflow.ellipsis),
        if (email.isNotEmpty)
          Text(
            email,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            ),
          ),
      ],
    );
  }

  Widget _buildResultCount(AppLocalizations l10n) {
    if (_isLoading || _pendingRegistrations.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = _filteredBundles.length;
    final loaded = _loadedCount;
    final total = _totalPending;

    final visible = _visibleBundles.length;
    final parts = <String>[
      if (shown != visible) l10n.qcResultCount(shown, visible),
      // Wie viel der Warteschlange überhaupt schon im Zugriff ist.
      if (total != null && loaded < total) l10n.qcLoadedOfTotal(loaded, total),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          parts.join('  ·  '),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }

  /// Small icon + text pair used for the metadata line on a card.
  Widget _buildCardMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  String _formatRegistrationDate(DateTime utc) {
    final local = utc.toLocal();
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).add_Hm().format(local);
  }

  /// Eine Farm mit Farmer und offenen Feldern als eine Prüfeinheit: Details,
  /// Fotos und Karten wie bisher, dazu je Objekt die Prüfpunkte. Freigeben
  /// lässt sich erst, wenn alle Punkte abgehakt sind.
  Widget _buildBundleCard(_QcBundle bundle) {
    final l10n = AppLocalizations.of(context)!;
    final checks = _requiredChecks(bundle);
    final done = checks.where((c) => _isChecked(bundle, c)).length;
    final complete = done == checks.length;
    final pendingFields = bundle.pendingFields;

    return Card(
      key: ValueKey('qc-bundle-${bundle.key}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: bundle.key == _focusBundleKey,
        // Aufgeklappte Abschnitte behalten ihre geladenen Fotos und Karten,
        // auch wenn die Karte zwischendurch zuklappt.
        maintainState: true,
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.agriculture, color: Colors.white),
        ),
        title: Text(bundle.name, style: const TextStyle(color: Colors.black)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.farmer}: ${bundle.farmerName}  ·  '
              '${l10n.qcFieldCount(pendingFields.length)}',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 2),
            // Date and registrar directly on the card: they are the two things
            // a reviewer scans the queue by.
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                _buildCardMeta(
                  Icons.event,
                  bundle.registeredAt != null
                      ? _formatRegistrationDate(bundle.registeredAt!)
                      : '-',
                ),
                _buildCardMeta(Icons.person_outline, bundle.registrarName),
                if (_locationLabel(bundle) case final location?)
                  _buildCardMeta(Icons.place_outlined, location),
                _buildCardMeta(
                  complete ? Icons.check_circle_outline : Icons.checklist,
                  l10n.qcChecklistProgress(done, checks.length),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bundle.farm == null)
                  _buildHintLine(Icons.link_off, l10n.qcNoLinkedFarm),
                if (bundle.farmer != null)
                  _buildMemberSection(
                    bundle,
                    bundle.farmer!,
                    checks,
                    icon: Icons.person,
                    color: Colors.blue,
                    title: '${l10n.farmer}: ${bundle.farmerName}',
                  ),
                if (bundle.farm != null)
                  _buildMemberSection(
                    bundle,
                    bundle.farm!,
                    checks,
                    icon: Icons.agriculture,
                    color: Colors.green,
                    title:
                        '${l10n.farm}: ${bundle.farm!['identity']?['name'] ?? '-'}',
                  ),
                for (final field in pendingFields)
                  _buildMemberSection(
                    bundle,
                    field,
                    checks,
                    icon: Icons.map,
                    color: Colors.orange,
                    title:
                        '${l10n.field}: ${field['identity']?['name'] ?? '-'}',
                  ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: complete
                          ? const SizedBox.shrink()
                          : Text(
                              l10n.qcChecklistIncomplete,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                    ),
                    TextButton.icon(
                      onPressed: () => _decideBundle(bundle, approve: false),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.rejectRegistration),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: complete
                          ? () => _decideBundle(bundle, approve: true)
                          : null,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.approveRegistration),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abschnitt für ein Objekt des Bündels: Details (mit Karte, falls Geodaten
  /// vorhanden) und darunter seine Prüfpunkte.
  Widget _buildMemberSection(
    _QcBundle bundle,
    Map<String, dynamic> obj,
    List<_QcCheck> checks, {
    required IconData icon,
    required Color color,
    required String title,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final uid = _QcBundle.uidOf(obj);
    final ralType = obj['template']?['RALType']?.toString() ?? '';
    final pending = _QcBundle.isPending(obj);
    final ownChecks = checks.where((c) => c.objectUid == uid).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              if (pending && _canCorrect)
                IconButton(
                  onPressed: () => _correctObject(obj),
                  icon: const Icon(Icons.edit_note),
                  color: Colors.blueGrey,
                  tooltip: l10n.qcCorrectData,
                  visualDensity: VisualDensity.compact,
                ),
              _buildStateChip(obj, l10n),
            ],
          ),
          const SizedBox(height: 12),
          if (!pending) _buildHintLine(Icons.info_outline, l10n.qcNotPartOfReview),
          _hasGeoData(obj)
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildObjectDetails(obj)),
                    const SizedBox(width: 16),
                    _buildMiniMapWidget(obj),
                  ],
                )
              : _buildObjectDetails(obj),
          if (ralType == 'field')
            _buildFieldDownloadButtons(obj,
                canReplace: pending && _canCorrect),
          if (ownChecks.isNotEmpty) ...[
            const Divider(height: 16),
            for (final check in ownChecks) _buildCheckTile(bundle, check),
          ],
        ],
      ),
    );
  }

  Widget _buildStateChip(Map<String, dynamic> obj, AppLocalizations l10n) {
    final (String label, Color color) = switch (obj['objectState']) {
      'qcPending' => (l10n.qcPending, Colors.orange),
      'active' => (l10n.qcApproved, Colors.green),
      'qcRejected' => (l10n.qcRejected, Colors.red),
      final other => (other?.toString() ?? '-', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildHintLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.orange[900], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _checkLabel(_QcCheck check, AppLocalizations l10n) {
    switch (check.check) {
      case 'nationalIDPhoto':
        return l10n.qcCheckNationalId;
      case 'consentFormPhoto':
        return l10n.qcCheckConsentForm;
      case 'consentFormPhoto2':
        return l10n.qcCheckConsentForm2;
      case 'fieldRegistrationPhoto':
        return l10n.qcCheckFieldPhoto;
      case _qcPolygonCheck:
        return l10n.qcCheckPolygon;
    }
    return check.check;
  }

  /// Ein Prüfpunkt. Foto-Punkte lassen sich nur abhaken, wenn das Foto in der
  /// Cloud liegt - "Foto ist da" lässt sich sonst nicht bestätigen. Fehlt das
  /// Foto ganz, führt der Punkt direkt zur Korrektur, wo es hochgeladen wird.
  Widget _buildCheckTile(_QcBundle bundle, _QcCheck check) {
    final l10n = AppLocalizations.of(context)!;

    Widget tile({required bool enabled, String? hint, Widget? action}) =>
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _isChecked(bundle, check),
          onChanged:
              enabled ? (v) => _setChecked(bundle, check, v ?? false) : null,
          title: Text(
            _checkLabel(check, l10n),
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
          subtitle: hint == null
              ? null
              : Text(hint,
                  style: TextStyle(color: Colors.orange[900], fontSize: 12)),
          secondary: action,
        );

    if (!check.isPhoto) return tile(enabled: true);

    if (!_hasLinkedPhoto(check.object, check.check)) {
      return tile(
        enabled: false,
        hint: l10n.qcPhotoMissing,
        action: _canCorrect
            ? TextButton.icon(
                onPressed: () => _correctObject(check.object),
                icon: const Icon(Icons.upload, size: 18),
                label: Text(l10n.qcPhotoUpload),
              )
            : null,
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _photoFuture(check.object, check.check),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return tile(enabled: false);
        }
        final data = snapshot.data;
        final available = data != null &&
            data['notUploaded'] != true &&
            (data['url']?.toString() ?? '').isNotEmpty;
        return tile(
          enabled: available,
          hint: available ? null : l10n.qcCheckPhotoUnavailable,
        );
      },
    );
  }

  /// Foto-Abfrage je Objekt und Rolle, einmal je Bildschirm-Sitzung.
  Future<Map<String, dynamic>?> _photoFuture(
          Map<String, dynamic> obj, String role) =>
      _photoFutures.putIfAbsent('${_QcBundle.uidOf(obj)}|$role',
          () => _getImageURLFromLinkedObject(obj, role));

  /// GeoID aus der Asset Registry, falls das Feld schon eine hat.
  String? _assetRegistryGeoId(Map<String, dynamic> obj) {
    final altIds = obj['identity']?['alternateIDs'];
    if (altIds is! List) return null;
    for (final a in altIds) {
      if (a is Map && a['issuedBy'] == 'Asset Registry') {
        return a['UID'] as String?;
      }
    }
    return null;
  }

  Widget _buildFieldDownloadButtons(Map<String, dynamic> obj,
      {bool canReplace = false}) {
    final l10n = AppLocalizations.of(context)!;
    final boundariesRaw = getSpecificPropertyfromJSON(obj, 'boundaries');
    final area = getSpecificPropertyfromJSON(obj, 'area')?.toString() ?? '';
    final name = obj['identity']?['name'] as String?;

    ButtonStyle style(Color? color) => TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 4,
        children: [
          TextButton.icon(
            onPressed: () => FieldDownloadHelper.downloadGeoJSON(
              context,
              name: name ?? 'field',
              boundariesJson: boundariesRaw?.toString(),
              l10n: l10n,
              area: area,
              geoId: _assetRegistryGeoId(obj),
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('GeoJSON', style: TextStyle(fontSize: 12)),
            style: style(Colors.green[700]),
          ),
          TextButton.icon(
            onPressed: () => FieldDownloadHelper.downloadKML(
              context,
              name: name ?? 'Field',
              boundariesJson: boundariesRaw?.toString(),
              l10n: l10n,
              area: area,
              geoId: _assetRegistryGeoId(obj),
            ),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('KML', style: TextStyle(fontSize: 12)),
            style: style(Colors.orange[700]),
          ),
          if (canReplace && (_getBoundariesFromObject(obj)?.length ?? 0) >= 3)
            TextButton.icon(
              onPressed: () => _replacePolygonFromFile(obj),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(l10n.qcReplacePolygonButton,
                  style: const TextStyle(fontSize: 12)),
              style: style(Colors.blueGrey[700]),
            ),
        ],
      ),
    );
  }

  Widget _buildObjectDetails(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final ralType = obj['template']?['RALType'] ?? 'unknown';

    List<Widget> details = [];

    // Common details
    if (kDebugMode) {
      details.add(_buildDetailRow('UID', obj['identity']?['UID'] ?? '-'));
    }

    // Type-specific details
    if (ralType == 'human') {
      final firstName = getSpecificPropertyfromJSON(obj, 'firstName') ?? '-';
      final lastName = getSpecificPropertyfromJSON(obj, 'lastName') ?? '-';

      // National ID aus identity.alternateIDs lesen
      String nationalID = '-';
      final alternateIDs = obj['identity']?['alternateIDs'] as List?;
      if (alternateIDs != null) {
        for (var altId in alternateIDs) {
          if (altId['issuedBy'] == 'National ID') {
            nationalID = altId['UID']?.toString() ?? '-';
            break;
          }
        }
      }

      final phone = getSpecificPropertyfromJSON(obj, 'phoneNumber') ?? '-';

      details.addAll([
        _buildDetailRow(l10n.firstName, firstName),
        _buildDetailRow(l10n.lastName, lastName),
        _buildDetailRow(l10n.nationalID, nationalID),
      ]);

      // National ID Photo anzeigen - lade aus image-Objekt via linkedObjectRef
      details.add(
          _buildLinkedPhoto(obj, 'nationalIDPhoto', l10n.nationalIDPhoto));

      details.add(_buildDetailRow(l10n.phoneNumber, phone));
    } else if (ralType == 'farm') {
      final totalArea = getSpecificPropertyfromJSON(obj, 'totalAreaHa');
      final totalAreaValue = (totalArea is num) ? totalArea.toDouble() : 0.0;
      final city =
          obj['currentGeolocation']?['postalAddress']?['cityName'] ?? '-';

      details.addAll([
        _buildDetailRow(
            l10n.totalArea, '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow(l10n.cityName, city),
      ]);

      // Consent Form Photo anzeigen - lade aus image-Objekt via linkedObjectRef
      details.add(
          _buildLinkedPhoto(obj, 'consentFormPhoto', l10n.consentFormPhoto));
      // Zweite Aufnahme (z.B. Rückseite des Formulars) - in der App optional,
      // deshalb fällt der Block still weg, wenn es sie nicht gibt.
      details.add(
          _buildLinkedPhoto(obj, 'consentFormPhoto2', l10n.consentFormPhoto2));

    } else if (ralType == 'field') {
      final area = getSpecificPropertyfromJSON(obj, 'area');
      final areaValue = (area is num) ? area.toDouble() : 0.0;
      final boundaryPoints = _getBoundariesFromObject(obj);
      // Letzter Punkt ist Wiederholung des ersten Punktes bei geschlossenen Polygonen
      final pointCount = (boundaryPoints != null && boundaryPoints.isNotEmpty)
          ? boundaryPoints.length - 1
          : 0;

      details.addAll([
        _buildDetailRow(l10n.fieldArea, '${areaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow(l10n.polygonPoints, '$pointCount'),
      ]);

      // GPS-Qualität anzeigen
      final accuracies = getSpecificPropertyfromJSON(obj, 'boundaryAccuracies');
      if (accuracies is List && accuracies.isNotEmpty) {
        // Von Hand korrigierte Ecken tragen keine Messunsicherheit und würden
        // den Durchschnitt sonst nach unten ziehen.
        final accuracyValues = accuracies
            .map((e) => (e is num) ? e.toDouble() : 0.0)
            .where((a) => !isManuallyEditedAccuracy(a))
            .toList();
        final avgAcc =
            accuracyValues.reduce((a, b) => a + b) / accuracyValues.length;
        final maxAcc = accuracyValues.reduce((a, b) => a > b ? a : b);
        final minAcc = accuracyValues.reduce((a, b) => a < b ? a : b);

        details.add(_buildDetailRow(
            l10n.gpsQualityAverage, '${avgAcc.toStringAsFixed(1)}m'));
        details.add(_buildDetailRow(l10n.gpsQualityRange,
            '${minAcc.toStringAsFixed(1)}m - ${maxAcc.toStringAsFixed(1)}m'));

        // Warnhinweis bei schlechter Qualität
        if (maxAcc > 10.0) {
          details.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.gpsQualityWarning,
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ));
        }
      }

      // Field Photo anzeigen - lade aus image-Objekt via linkedObjectRef
      details.add(
          _buildLinkedPhoto(obj, 'fieldRegistrationPhoto', l10n.fieldPhoto));
    }

    // Registered by - wird asynchron geladen
    details.add(_buildRegisteredByRow(obj, l10n));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  /// Lädt den Namen und UID des Registrars aus der Methoden-Historie
  Future<Map<String, String>> _getRegistrarInfo(
      Map<String, dynamic> obj) async {
    // Already resolved while loading the list - do not fetch the same method
    // document a second time for the expanded card.
    final objectUid = obj['identity']?['UID']?.toString();
    if (objectUid != null && _registrarCache.containsKey(objectUid)) {
      return _registrarCache[objectUid]!;
    }
    try {
      // Hole ersten Eintrag aus methodHistoryRef
      final methodHistoryRef = obj['methodHistoryRef'];
      if (methodHistoryRef == null ||
          methodHistoryRef is! List ||
          methodHistoryRef.isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      final firstMethod = methodHistoryRef[0];
      if (firstMethod is! Map || !firstMethod.containsKey('UID')) {
        return {'name': '-', 'uid': ''};
      }

      final methodUID = firstMethod['UID'];
      if (methodUID == null || methodUID.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Lade Methode aus TFC_methods
      final methodDoc = await FirebaseFirestore.instance
          .collection('TFC_methods')
          .doc(methodUID.toString())
          .get();

      if (!methodDoc.exists) {
        return {'name': '-', 'uid': ''};
      }

      final methodData = methodDoc.data();
      if (methodData == null) {
        return {'name': '-', 'uid': ''};
      }

      // Extrahiere executor -> identity -> name und UID
      final executor = methodData['executor'];
      if (executor == null || executor is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final identity = executor['identity'];
      if (identity == null || identity is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final name = identity['name'];
      final uid = identity['UID'];
      if (name == null || name.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      return {'name': name.toString(), 'uid': uid?.toString() ?? ''};
    } catch (e) {
      debugPrint('Error getting registrar info: $e');
      return {'name': '-', 'uid': ''};
    }
  }

  /// Zeigt einen Dialog mit Details zu einem openRAL Objekt
  Future<void> _showObjectDetailsDialog(String uid) async {
    final l10n = AppLocalizations.of(context)!;

    // Lade Objekt aus Firestore
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final objDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(uid)
          .get();

      // Schließe Loading-Dialog
      if (mounted) Navigator.of(context).pop();

      if (!objDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.objectNotFound),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final objData = objDoc.data();
      if (objData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidObjectData),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Zeige Details-Dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _ObjectDetailsDialog(obj: objData),
        );
      }
    } catch (e) {
      debugPrint('Error loading object details: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingDetails}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Widget für "Registriert von" Zeile mit FutureBuilder
  Widget _buildRegisteredByRow(
      Map<String, dynamic> obj, AppLocalizations l10n) {
    return FutureBuilder<Map<String, String>>(
      future: _getRegistrarInfo(obj),
      builder: (context, snapshot) {
        final info = snapshot.data ?? {'name': '...', 'uid': ''};
        final registrarName = info['name'] ?? '...';
        final registrarUID = info['uid'] ?? '';

        return _buildDetailRow(
          l10n.registeredBy,
          registrarName,
          onTap: registrarUID.isNotEmpty &&
                  registrarName != '-' &&
                  registrarName != '...'
              ? () => _showObjectDetailsDialog(registrarUID)
              : null,
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {VoidCallback? onTap}) {
    final l10n = AppLocalizations.of(context)!;
    final isUID = label == 'UID';
    final isClickable = isUID || onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          Expanded(
            child: isClickable
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: isUID
                          ? () async {
                              await Clipboard.setData(
                                  ClipboardData(text: value));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.uidCopiedToClipboard),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              }
                            }
                          : onTap,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )
                : Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  /// Widget für GPS-Qualitäts-Legenden-Item
  Widget _buildLegendItem(Color color, String range, String quality) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$range - $quality',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// Lädt ein verknüpftes Foto anhand seiner Rolle nach und zeigt es an.
  /// Fehlt das Bild - etwa die optionale zweite Aufnahme der
  /// Einverständniserklärung -, bleibt die Stelle leer.
  Widget _buildLinkedPhoto(
      Map<String, dynamic> obj, String role, String label) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _photoFuture(obj, role),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final imageData = snapshot.data;
        if (imageData == null) return const SizedBox.shrink();

        return _buildPhotoWidget(
          photoPath: imageData['url'] as String,
          isLocalFile: imageData['isLocal'] as bool,
          notUploaded: imageData['notUploaded'] == true,
          label: label,
        );
      },
    );
  }

  /// Generisches Widget für Foto-Anzeige mit Tap-to-Zoom
  /// Unterstützt sowohl Cloud-URLs als auch lokale Dateipfade
  Widget _buildPhotoWidget({
    required String photoPath,
    required bool isLocalFile,
    required String label,
    bool notUploaded = false,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          // A photo that never reached the cloud is not a loading error - say
          // so, otherwise the reviewer cannot tell a broken link from a
          // registration that is simply still on the registrar's phone.
          if (notUploaded)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.orange[50],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 32, color: Colors.orange[700]),
                  const SizedBox(height: 8),
                  Text(
                    l10n.photoNotUploadedYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange[900], fontSize: 12),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
            onTap: () => _showFullScreenImage(photoPath, isLocalFile),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isLocalFile && !kIsWeb
                      ? Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 32, color: Colors.grey[400]),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.errorLoadingImage,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: photoPath,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 32, color: Colors.grey[400]),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.errorLoadingImage,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (!notUploaded)
            Text(
              l10n.tapToEnlarge,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ),
    );
  }

  /// Zeigt Bild in bildschirmfüllender Ansicht
  /// Unterstützt sowohl Cloud-URLs als auch lokale Dateipfade
  void _showFullScreenImage(String imagePath, bool isLocalFile) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Bildschirmfüllendes Bild
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: isLocalFile && !kIsWeb
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                l10n.errorLoadingImage,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imagePath,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                l10n.errorLoadingImage,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            // Schließen-Button oben rechts
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prüft ob Objekt gültige Geodaten hat (Geolocation oder Boundaries)
  bool _hasGeoData(Map<String, dynamic> obj) {
    // Prüfe currentGeolocation
    final geolocation = obj['currentGeolocation'];
    if (geolocation != null && geolocation is Map) {
      final lat = geolocation["geoCoordinates"]['latitude'];
      final lng = geolocation["geoCoordinates"]['longitude'];
      if (lat != null && lng != null) {
        final latNum =
            (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
        final lngNum =
            (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
        if (latNum != null &&
            lngNum != null &&
            latNum != 0.0 &&
            lngNum != 0.0) {
          return true;
        }
      }
    }

    // Prüfe boundaries nur bei Field-Objekten
    final ralType = obj['template']?['RALType'] ?? '';
    if (ralType == 'field') {
      final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries');
      if (boundaries != null && boundaries is List && boundaries.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  /// Extrahiert LatLng aus currentGeolocation
  LatLng? _getLocationFromObject(Map<String, dynamic> obj) {
    final geolocation = obj['currentGeolocation'];
    if (geolocation == null || geolocation is! Map) return null;

    final lat = geolocation["geoCoordinates"]['latitude'];
    final lng = geolocation["geoCoordinates"]['longitude'];
    if (lat == null || lng == null) return null;

    final latNum =
        (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
    final lngNum =
        (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());

    if (latNum == null || lngNum == null || latNum == 0.0 || lngNum == 0.0) {
      return null;
    }

    return LatLng(latNum, lngNum);
  }

  /// Extrahiert GPS-Genauigkeitsdaten aus boundaryAccuracies (nur für Field-Objekte)
  List<double>? _getBoundaryAccuracies(Map<String, dynamic> obj) {
    // Nur für Field-Objekte verfügbar
    final ralType = obj['template']?['RALType'] ?? '';
    if (ralType != 'field') return null;

    final accuraciesRaw =
        getSpecificPropertyfromJSON(obj, 'boundaryAccuracies');
    if (accuraciesRaw == null || accuraciesRaw == '-no data found-') {
      return null;
    }

    debugPrint('boundaryAccuracies raw type: ${accuraciesRaw.runtimeType}');
    debugPrint('boundaryAccuracies raw value: $accuraciesRaw');

    List<double> accuracies = [];

    // Falls boundaryAccuracies ein String ist (JSON), parse ihn
    if (accuraciesRaw is String) {
      // Entferne mögliche Anführungszeichen am Anfang/Ende
      String cleanedString = accuraciesRaw.trim();
      if (cleanedString.startsWith('"') && cleanedString.endsWith('"')) {
        cleanedString = cleanedString.substring(1, cleanedString.length - 1);
      }

      try {
        final parsed = jsonDecode(cleanedString);
        if (parsed is List) {
          accuracies =
              parsed.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
          debugPrint('Parsed ${accuracies.length} accuracy values from string');
        }
      } catch (e) {
        debugPrint('Error parsing boundaryAccuracies JSON: $e');
        debugPrint('Failed string: $cleanedString');
        return null;
      }
    }
    // Falls boundaryAccuracies bereits eine Liste ist (altes Format)
    else if (accuraciesRaw is List && accuraciesRaw.isNotEmpty) {
      accuracies =
          accuraciesRaw.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
      debugPrint('Got ${accuracies.length} accuracy values from list');
    } else {
      debugPrint('boundaryAccuracies in unsupported format');
      return null;
    }

    if (accuracies.isNotEmpty) {
      debugPrint('Accuracy values: ${accuracies.join(", ")}');
    }

    return accuracies.isEmpty ? null : accuracies;
  }

  /// Berechnet Farbe basierend auf GPS-Genauigkeit (Grün=gut, Gelb=mittel, Rot=schlecht)
  Color _getAccuracyColor(double accuracy) => gpsAccuracyColor(accuracy);

  /// Erstellt Kreise für GPS-Qualitätsvisualisierung (farbcodierte Kreise an Eckpunkten)
  Set<Circle> _createAccuracyCircles(
      List<LatLng> boundaries, List<double> accuracies) {
    debugPrint(
        'Creating accuracy circles: ${boundaries.length} boundaries, ${accuracies.length} accuracies');
    Set<Circle> circles = {};

    // Erstelle einen Kreis für jeden Punkt (außer dem letzten, falls Duplikat)
    final pointsToMark = (boundaries.isNotEmpty &&
            boundaries.first.latitude == boundaries.last.latitude &&
            boundaries.first.longitude == boundaries.last.longitude)
        ? boundaries.length - 1 // Überspringe dupliziertes Ende
        : boundaries.length;

    for (int i = 0; i < pointsToMark; i++) {
      final accuracy = (i < accuracies.length) ? accuracies[i] : 0.0;
      final color = _getAccuracyColor(accuracy);

      debugPrint(
          'Point $i: accuracy=${accuracy.toStringAsFixed(2)}m, color=$color');

      circles.add(Circle(
        circleId: CircleId('accuracy_point_$i'),
        center: boundaries[i],
        radius: 3, // 3 Meter Radius
        fillColor: color.withOpacity(0.8),
        strokeColor: color,
        strokeWidth: 2,
      ));
    }

    debugPrint('Created ${circles.length} accuracy circles');
    return circles;
  }

  /// Extrahiert Polygon-Koordinaten aus boundaries (nur für Field-Objekte)
  List<LatLng>? _getBoundariesFromObject(Map<String, dynamic> obj) {
    // Nur für Field-Objekte verfügbar
    final ralType = obj['template']?['RALType'] ?? '';
    if (ralType != 'field') return null;

    final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries');
    if (boundaries == null) return null;

    List<LatLng> points = [];

    // Falls boundaries ein String ist (GeoJSON), parse ihn
    if (boundaries is String) {
      try {
        final parsed = jsonDecode(boundaries);
        if (parsed is Map && parsed.containsKey('coordinates')) {
          final coords = parsed['coordinates'];
          if (coords is List) {
            for (var point in coords) {
              if (point is List && point.length >= 2) {
                final lat = point[0];
                final lng = point[1];

                final latNum = (lat is num)
                    ? lat.toDouble()
                    : double.tryParse(lat.toString());
                final lngNum = (lng is num)
                    ? lng.toDouble()
                    : double.tryParse(lng.toString());

                if (latNum != null && lngNum != null) {
                  points.add(LatLng(latNum, lngNum));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing boundaries GeoJSON: $e');
        return null;
      }
    }
    // Falls boundaries bereits ein Array ist (altes Format)
    else if (boundaries is List && boundaries.isNotEmpty) {
      for (var point in boundaries) {
        if (point is! Map) continue;

        final lat = point['latitude'] ?? point['lat'];
        final lng = point['longitude'] ?? point['lon'] ?? point['lng'];

        if (lat == null || lng == null) continue;

        final latNum =
            (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
        final lngNum =
            (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());

        if (latNum != null && lngNum != null) {
          points.add(LatLng(latNum, lngNum));
        }
      }
    }

    return points.isNotEmpty ? points : null;
  }

  /// Erstellt eine kleine Map-Vorschau für die Card
  Widget _buildMiniMapWidget(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final location = _getLocationFromObject(obj);
    final boundaries = _getBoundariesFromObject(obj);
    final accuracies = _getBoundaryAccuracies(obj);

    // Berechne Kamera-Position (Center)
    LatLng center;
    if (location != null) {
      center = location;
    } else if (boundaries != null && boundaries.isNotEmpty) {
      // Berechne Center des Polygons
      double sumLat = 0;
      double sumLng = 0;
      for (var point in boundaries) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      center = LatLng(sumLat / boundaries.length, sumLng / boundaries.length);
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showFullScreenMap(obj),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 200,
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // AbsorbPointer verhindert Interaktion mit der Map (verhindert Links zu Google Maps)
                AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: boundaries != null ? 16 : 14,
                    ),
                    markers: location != null && boundaries == null
                        ? {
                            Marker(
                              markerId: const MarkerId('location'),
                              position: location,
                            ),
                          }
                        : {},
                    circles: (boundaries != null &&
                            accuracies != null &&
                            (accuracies.length == boundaries.length ||
                                accuracies.length == boundaries.length - 1))
                        ? _createAccuracyCircles(boundaries, accuracies)
                        : {},
                    polygons: boundaries != null
                        ? {
                            Polygon(
                              polygonId: const PolygonId('boundary'),
                              points: boundaries,
                              strokeColor: Colors.blue,
                              strokeWidth: 2,
                              fillColor: Colors.blue.withOpacity(0.2),
                            ),
                          }
                        : {},
                    mapType: MapType.satellite,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    liteModeEnabled:
                        true, // Lite Mode für bessere Performance und weniger Interaktivität
                  ),
                ),
                // Overlay mit Hinweis
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.tapToEnlargeMap,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ob der angemeldete Nutzer Daten im QC korrigieren darf - Registrar
  /// Coordinator und aufwärts.
  bool get _canCorrect =>
      PermissionService().hasPermission('qc_correct_data');

  /// Korrigiert Daten und Fotos eines offenen Objekts.
  ///
  /// Geschrieben wird ein signierter changeObjectData-Job mit Grund und Liste
  /// der geänderten Felder (siehe [saveObjectCorrection]). Neue Fotos werden
  /// sofort hochgeladen, damit der Prüfer sie gleich bestätigen kann.
  Future<void> _correctObject(Map<String, dynamic> obj) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = _QcBundle.uidOf(obj);
    final ralType = obj['template']?['RALType']?.toString() ?? '';

    final result = await showDialog<QcCorrectionResult>(
      context: context,
      builder: (_) => QcCorrectionDialog(
        object: obj,
        linkedPhotoRoles: {
          for (final role in _qcPhotoRoles[ralType] ?? const <String>[])
            if (_hasLinkedPhoto(obj, role)) role,
        },
      ),
    );
    if (result == null) return;

    _setBusy(l10n.qcCorrectionSaving);
    try {
      // Auf der aktuellen Fassung aufsetzen - eine Polygonkorrektur kann sie
      // inzwischen verändert haben.
      final current = await getCurrentObjectVersion(uid);
      final updated = await saveObjectCorrection(
        current: current.isNotEmpty ? current : obj,
        values: result.values,
        photos: result.photos,
        reason: result.reason,
      );

      if (result.photos.isNotEmpty) {
        // Die Prüfansicht liest Fotos aus der Cloud - ohne Upload liesse sich
        // das neue Foto nicht abhaken.
        _setBusy(l10n.qcCorrectionUploadingPhotos);
        await cloudSyncService.uploadPendingPhotos(ignorePause: true);
        await cloudSyncService.syncMethods('tracefoodchain.org',
            syncFromCloud: false, ignorePause: true);
      }

      if (mounted) {
        setState(() {
          _pendingRegistrations = [
            for (final entry in _pendingRegistrations)
              entry.uid == uid ? entry.withObject(updated) : entry,
          ];
          for (final bundle in _bundles) {
            if (!bundle.contains(uid)) continue;
            bundle.replaceObject(updated);
            // Ein ersetztes Foto muss der Prüfer erneut bestätigen.
            for (final role in result.photos.keys) {
              _checks[bundle.key]?.remove('$uid|$role');
            }
          }
          for (final role in result.photos.keys) {
            _photoFutures.remove('$uid|$role');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.qcCorrectionSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
      repaintContainerList.value = true;
    } catch (e) {
      debugPrint('Error saving QC correction for $uid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.qcCorrectionSaveFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setBusy(null);
    }
  }

  /// Schreibt eine im Karteneditor korrigierte Feldgrenze über den signierten
  /// openRAL-Pfad und übernimmt die neue Fassung in die Liste.
  ///
  /// Die geschriebene Version kommt direkt aus dem Service zurück; ein erneutes
  /// Laden aus Firestore wäre ein Rennen gegen den asynchronen Cloud-Sync und
  /// würde oft noch den alten Stand zeigen.
  /// Ersetzt die Feldgrenze durch ein extern (z.B. in QGIS) korrigiertes
  /// Polygon aus einer GeoJSON-Datei.
  ///
  /// Gespeichert wird wie bei der Korrektur im Editor - die alte Geometrie
  /// bleibt als Input im signierten Job, dazu kommen die Angaben zur externen
  /// Korrektur (`externalCorrection`).
  Future<void> _replacePolygonFromFile(Map<String, dynamic> obj) async {
    final boundaries = _getBoundariesFromObject(obj);
    if (boundaries == null) return;

    final replacement = await Navigator.of(context).push<PolygonReplacement>(
      MaterialPageRoute(
        builder: (_) => QcPolygonReplacePage(
          fieldName: obj['identity']?['name']?.toString() ?? '',
          currentRing: boundaries,
          geoId: _assetRegistryGeoId(obj),
        ),
      ),
    );
    if (replacement == null || !mounted) return;

    final ring = replacement.polygon.ring;
    await _saveGeometryEdit(
      obj,
      FieldGeometryEdit(
        points: ring,
        // Nicht im Feld gemessen - wie von Hand gesetzte Ecken.
        accuracies: List.filled(ring.length, manuallyEditedAccuracy),
        reason: replacement.reason,
        description: 'replaced by external geometry from '
            '${replacement.fileName} (feature ${replacement.polygon.featureId})',
      ),
      changeContext: changeContextExternalGeometryReplacement,
      jobProperties: {'externalCorrection': replacement.toJobProperty()},
    );
  }

  Future<void> _saveGeometryEdit(
    Map<String, dynamic> obj,
    FieldGeometryEdit edit, {
    String changeContext = changeContextQcCorrection,
    Map<String, dynamic> jobProperties = const {},
  }) async {
    final l10n = AppLocalizations.of(context)!;
    _setBusy(l10n.qcPolygonSaving);

    try {
      final updated = await saveFieldGeometry(
        field: obj,
        edit: edit,
        changeContext: changeContext,
        jobProperties: jobProperties,
      );
      final uid = updated['identity']?['UID']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _pendingRegistrations = [
            for (final entry in _pendingRegistrations)
              entry.uid == uid ? entry.withObject(updated) : entry,
          ];
          for (final bundle in _bundles) {
            if (!bundle.contains(uid)) continue;
            bundle.replaceObject(updated);
            // Die Freigabe galt der alten Geometrie - die neue muss der Prüfer
            // erneut bestätigen.
            _checks[bundle.key]?.remove('$uid|$_qcPolygonCheck');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.qcPolygonSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
      repaintContainerList.value = true;
    } catch (e) {
      debugPrint('Error saving polygon change: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.qcPolygonSaveFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setBusy(null);
    }
  }

  /// Zeigt Map in bildschirmfüllender Ansicht
  Future<void> _showFullScreenMap(Map<String, dynamic> obj) async {
    final l10n = AppLocalizations.of(context)!;
    final location = _getLocationFromObject(obj);
    final boundaries = _getBoundariesFromObject(obj);
    final accuracies = _getBoundaryAccuracies(obj);

    // Felder mit Polygon bekommen die Editor-Seite - dort lassen sich Ecken
    // verschieben, löschen und ergänzen. Punkt-Objekte (Farm, Farmer) behalten
    // die einfache Kartenansicht darunter.
    if (boundaries != null && boundaries.length >= 3) {
      final edit = await Navigator.of(context).push<FieldGeometryEdit>(
        MaterialPageRoute(
          builder: (_) => FieldPolygonMapPage(
            title: obj['identity']?['name']?.toString() ?? l10n.mapView,
            points: boundaries,
            accuracies: accuracies,
            canEdit: obj['template']?['RALType'] == 'field',
          ),
        ),
      );
      if (edit != null && edit.hasChanges) {
        await _saveGeometryEdit(obj, edit);
      }
      return;
    }

    // Berechne Kamera-Position
    LatLng center;
    if (location != null) {
      center = location;
    } else if (boundaries != null && boundaries.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (var point in boundaries) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      center = LatLng(sumLat / boundaries.length, sumLng / boundaries.length);
    } else {
      return;
    }

    // Satellit ist die Standardansicht; im Vollbild kann umgeschaltet werden.
    MapType selectedMapType = MapType.satellite;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setMapState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Bildschirmfüllende Map
              GoogleMap(
                mapType: selectedMapType,
                initialCameraPosition: CameraPosition(
                  target: center,
                  zoom: boundaries != null ? 17 : 15,
                ),
                markers: location != null && boundaries == null
                    ? {
                        Marker(
                          markerId: const MarkerId('location'),
                          position: location,
                          infoWindow: InfoWindow(
                            title: obj['identity']?['name'] ?? l10n.mapView,
                          ),
                        ),
                      }
                    : {},
                circles: (boundaries != null &&
                        accuracies != null &&
                        (accuracies.length == boundaries.length ||
                            accuracies.length == boundaries.length - 1))
                    ? _createAccuracyCircles(boundaries, accuracies)
                    : {},
                polygons: boundaries != null
                    ? {
                        Polygon(
                          polygonId: const PolygonId('boundary'),
                          points: boundaries,
                          strokeColor: Colors.blue,
                          strokeWidth: 3,
                          fillColor: Colors.blue.withOpacity(0.2),
                        ),
                      }
                    : {},
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
              // GPS-Qualitäts-Legende (nur wenn Accuracies vorhanden)
              if (accuracies != null && accuracies.isNotEmpty)
                Positioned(
                  bottom: 100,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.gpsQualityLegend,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                            Colors.green, '≤ 5m', l10n.gpsQualityExcellent),
                        _buildLegendItem(
                            Colors.lightGreen, '≤ 10m', l10n.gpsQualityGood),
                        _buildLegendItem(
                            Colors.orange, '≤ 15m', l10n.gpsQualityMedium),
                        _buildLegendItem(
                            Colors.red, '> 15m', l10n.gpsQualityPoor),
                      ],
                    ),
                  ),
                ),
              // Schließen-Button
              Positioned(
                top: 40,
                right: 16,
                child: PointerInterceptor(
                    child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.black),
                )),
              ),
              // Umschalter für die Kartenansicht
              Positioned(
                top: 112,
                right: 16,
                child: MapTypeSelector(
                  selected: selectedMapType,
                  onSelected: (type) =>
                      setMapState(() => selectedMapType = type),
                ),
              ),
              // Titel
              Positioned(
                top: 40,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    obj['identity']?['name'] ?? l10n.mapView,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Neue Fassungen aller image-Objekte, die an [parents] hängen, mit dem
  /// Zustand [newState] - für den QC-Job, der sie zusammen mit ihren
  /// Eltern-Objekten schreibt.
  ///
  /// Ein fehlendes Foto bricht die Entscheidung nicht ab: ob die Fotos da sind,
  /// hat der Prüfer über die Checkliste bestätigt.
  Future<List<Map<String, dynamic>>> _linkedImagesWithState(
    List<Map<String, dynamic>> parents,
    String newState,
  ) async {
    final imageUids = <String>{};
    for (final parent in parents) {
      final links = parent['linkedObjectRef'];
      if (links is! List) continue;
      for (final link in links) {
        if (link is! Map || link['RALType'] != 'image') continue;
        final uid = link['UID']?.toString();
        if (uid != null && uid.isNotEmpty) imageUids.add(uid);
      }
    }

    final images = <Map<String, dynamic>>[];
    for (final uid in imageUids) {
      try {
        final current = await getCurrentObjectVersion(uid);
        if (current.isEmpty) {
          debugPrint('Image object not found: $uid');
          continue;
        }
        if (current['objectState'] == newState) continue;
        final updated = deepCopyMap(current)..['objectState'] = newState;
        images.add(jsonFullDoubleToInt(sortJsonAlphabetically(updated)));
      } catch (e) {
        debugPrint('Error loading image $uid for QC job: $e');
      }
    }
    return images;
  }

  /// Lädt downloadURL aus image-Objekt über linkedObjectRef
  /// [obj] - Das Objekt (Farmer, Farm, Field)
  /// [role] - Die Rolle des image-Objekts ('nationalIDPhoto', 'consentFormPhoto', 'fieldRegistrationPhoto')
  /// Returns: Map mit 'url' (downloadURL) und 'isLocal' (bool ob lokaler Pfad)
  Future<Map<String, dynamic>?> _getImageURLFromLinkedObject(
      Map<String, dynamic> obj, String role) async {
    try {
      final linkedObjectRef = obj['linkedObjectRef'];
      if (linkedObjectRef == null || linkedObjectRef is! List) {
        return null;
      }

      // Finde image-Objekt mit passender role
      final imageRef = linkedObjectRef.firstWhere(
        (ref) => ref['RALType'] == 'image' && ref['role'] == role,
        orElse: () => null,
      );

      if (imageRef == null || imageRef['UID'] == null) {
        debugPrint('No image found with role: $role');
        return null;
      }

      final imageUID = imageRef['UID'].toString();
      debugPrint('Loading image object with UID: $imageUID for role: $role');

      // Lade image-Objekt aus Firestore
      final imageDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(imageUID)
          .get();

      if (!imageDoc.exists) {
        debugPrint('Image object not found: $imageUID');
        return null;
      }

      final imageObj = imageDoc.data();
      if (imageObj == null) {
        return null;
      }

      // Extrahiere downloadURL aus specificProperties (Cloud URL)
      var downloadURL = getSpecificPropertyfromJSON(imageObj, 'downloadURL');
      final localPath = getSpecificPropertyfromJSON(imageObj, 'localDownloadURL');
      final storagePath = getSpecificPropertyfromJSON(imageObj, 'storagePath');

      // Full picture of what the cloud actually stores for this image - the QC
      // view is where a failed upload becomes visible, so name the cause.
      debugPrint('[QC IMAGE] uid=$imageUID\n'
          '  objectState : ${imageObj['objectState']}\n'
          '  name        : ${imageObj['identity']?['name']}\n'
          '  downloadURL : ${downloadURL.runtimeType} "$downloadURL"\n'
          '  storagePath : "$storagePath"\n'
          '  localPath   : "$localPath"');

      bool hasValue(dynamic v) =>
          v != null && v.toString().isNotEmpty && v != '-no data found-';

      if (!hasValue(downloadURL)) {
        // No cloud URL means the photo never completed upload+verification.
        // Falling back to localDownloadURL is pointless here: that path or blob
        // URL belongs to the registrar's device, not to the reviewer's.
        debugPrint('[QC IMAGE] uid=$imageUID has NO cloud downloadURL - the'
            ' photo has not been uploaded (or not verified) yet.'
            ' localDownloadURL is not usable on this device.');
        cloudLogService.warn('QC: image without cloud URL', data: {
          'uid': imageUID,
          'hasLocalPath': '${hasValue(localPath)}',
          'storagePath': '$storagePath',
        });
        return {'url': '', 'isLocal': false, 'notUploaded': true};
      }

      // Konvertiere zu String und entferne mögliche Anführungszeichen
      String url = downloadURL.toString().trim();
      if (url.startsWith('"') && url.endsWith('"')) {
        url = url.substring(1, url.length - 1);
        debugPrint('Removed surrounding quotes from URL');
      }

      // Prüfe ob es sich um lokalen Pfad oder Cloud URL handelt
      final isLocal = !url.startsWith('http');

      debugPrint('Final image URL: $url (isLocal: $isLocal)');
      return {'url': url, 'isLocal': isLocal};
    } catch (e) {
      debugPrint('Error loading image from linkedObjectRef: $e');
      return null;
    }
  }
}

/// Dialog für Genehmigung oder Ablehnung mit Notizen/Grund
class _ApprovalDialog extends StatefulWidget {
  final bool isApproval;
  final String? objectType;

  const _ApprovalDialog({
    required this.isApproval,
    this.objectType,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Kann über der Übersichtskarte liegen - siehe PointerInterceptor oben.
    return PointerInterceptor(
        child: AlertDialog(
      title: Text(
        widget.isApproval ? l10n.approveRegistration : l10n.rejectRegistration,
        style: const TextStyle(color: Colors.black),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info-Box für Field-Objekte bei Approval
          if (widget.isApproval && widget.objectType == 'field')
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.assetRegistryWillBeAttempted,
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText:
                  widget.isApproval ? l10n.approvalNotes : l10n.rejectionReason,
              labelStyle: const TextStyle(color: Colors.black87),
              hintText: widget.isApproval
                  ? l10n.optionalNotes
                  : l10n.pleaseProvideReason,
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.isApproval
              ? l10n.approveRegistration
              : l10n.rejectRegistration),
        ),
      ],
    ));
  }
}

/// Dialog zur Anzeige von openRAL Objekt-Details
class _ObjectDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> obj;

  const _ObjectDetailsDialog({required this.obj});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ralType = obj['template']?['RALType'] ?? 'unknown';
    final name = obj['identity']?['name'] ?? l10n.unnamed;

    IconData icon;
    Color color;

    switch (ralType) {
      case 'farm':
        icon = Icons.agriculture;
        color = Colors.green;
        break;
      case 'human':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'field':
        icon = Icons.terrain;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: color,
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildObjectInfo(obj, l10n, ralType),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectInfo(
      Map<String, dynamic> obj, AppLocalizations l10n, String ralType) {
    List<Widget> details = [];

    // Common details
    details.add(_buildInfoRow('UID', obj['identity']?['UID'] ?? '-'));
    details.add(_buildInfoRow(l10n.type, ralType));

    final objectState = obj['objectState'] ?? '-';
    details.add(_buildInfoRow(l10n.status, objectState));

    // Type-specific details
    if (ralType == 'human') {
      final firstName = getSpecificPropertyfromJSON(obj, 'firstName') ?? '-';
      final lastName = getSpecificPropertyfromJSON(obj, 'lastName') ?? '-';

      // National ID aus identity.alternateIDs lesen
      String nationalID = '-';
      final alternateIDs = obj['identity']?['alternateIDs'] as List?;
      if (alternateIDs != null) {
        for (var altId in alternateIDs) {
          if (altId['issuedBy'] == 'National ID') {
            nationalID = altId['UID']?.toString() ?? '-';
            break;
          }
        }
      }

      final phone = getSpecificPropertyfromJSON(obj, 'phoneNumber') ?? '-';
      final email = getSpecificPropertyfromJSON(obj, 'email') ?? '-';

      details.addAll([
        _buildInfoRow(l10n.firstName, firstName),
        _buildInfoRow(l10n.lastName, lastName),
        _buildInfoRow(l10n.nationalID, nationalID),
        _buildInfoRow(l10n.phoneNumber, phone),
        _buildInfoRow(l10n.email, email),
      ]);
    } else if (ralType == 'farm') {
      final totalArea = getSpecificPropertyfromJSON(obj, 'totalAreaHa');
      final totalAreaValue = (totalArea is num) ? totalArea.toDouble() : 0.0;
      final address = obj['currentGeolocation']?['postalAddress'];
      String part(String key) {
        final v = address is Map ? address[key]?.toString().trim() ?? '' : '';
        return v.isEmpty ? '-' : v;
      }

      // Gespeichert ist der ISO-Code (ältere Registrierungen: der Name).
      final storedCountry = part('country');
      final countryConfig = countryConfigService.resolve(storedCountry);
      final country = countryConfig?.name ?? storedCountry;

      details.addAll([
        _buildInfoRow(
            l10n.totalArea, '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildInfoRow(
            countryConfig?.regionLabel(0) ?? l10n.stateName, part('stateName')),
        _buildInfoRow(countryConfig?.regionLabel(1) ?? l10n.municipalityName,
            part('municipalityName')),
        _buildInfoRow(
            countryConfig?.regionLabel(2) ?? l10n.cityName, part('cityName')),
        _buildInfoRow(l10n.country, country),
      ]);
    } else if (ralType == 'field') {
      final area = getSpecificPropertyfromJSON(obj, 'area');
      final areaValue = (area is num) ? area.toDouble() : 0.0;

      // Parse boundaries (kann String oder List sein)
      int pointCount = 0;
      final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries');
      if (boundaries is String) {
        try {
          final parsed = jsonDecode(boundaries);
          if (parsed is Map && parsed.containsKey('coordinates')) {
            final coords = parsed['coordinates'];
            if (coords is List) {
              // Letzter Punkt ist Wiederholung des ersten Punktes bei geschlossenen Polygonen
              pointCount = coords.length > 0 ? coords.length - 1 : 0;
            }
          }
        } catch (e) {
          pointCount = 0;
        }
      } else if (boundaries is List) {
        // Letzter Punkt ist Wiederholung des ersten Punktes bei geschlossenen Polygonen
        pointCount = boundaries.length > 0 ? boundaries.length - 1 : 0;
      }

      details.addAll([
        _buildInfoRow(l10n.fieldArea, '${areaValue.toStringAsFixed(2)} ha'),
        _buildInfoRow(l10n.polygonPoints, '$pointCount'),
      ]);
    }

    // Creation date
    final methodHistoryRef = obj['methodHistoryRef'];
    if (methodHistoryRef is List && methodHistoryRef.isNotEmpty) {
      final firstMethod = methodHistoryRef[0];
      if (firstMethod is Map && firstMethod.containsKey('timestamp')) {
        final timestamp = firstMethod['timestamp'];
        if (timestamp != null) {
          details.add(_buildInfoRow(l10n.created, timestamp.toString()));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

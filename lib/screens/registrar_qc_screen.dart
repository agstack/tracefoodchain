import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../services/asset_registry_api_service.dart';
import '../services/user_registry_api_service.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import '../helpers/field_download_helper.dart';
import '../widgets/data_loading_indicator.dart';
import '../widgets/ihcafe_producer_widgets.dart';
import '../services/field_geometry_service.dart';
import '../widgets/field_polygon_editor.dart';
import '../widgets/map_type_selector.dart';
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
enum _QcSort { dateDesc, dateAsc, registrar, name, type }

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

  /// Everything the search box may match against, lowercased once.
  late final String searchIndex = [
    name,
    uid,
    registrarName,
    registrarEmail,
    ...alternateIds,
  ].join(' ').toLowerCase();
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

  bool get _hasMore => !_methodsExhausted || !_objectsExhausted;

  /// Gesetzt, wenn die nach Zeitpunkt sortierte Methodenabfrage nicht bedient
  /// werden konnte (in aller Regel: der zusammengesetzte Index fehlt noch).
  /// Dann stimmt "neueste zuerst" nur noch innerhalb des Geladenen - das darf
  /// nicht stillschweigend passieren.
  bool _dateOrderUnavailable = false;

  /// Gesamtzahl offener Vorgänge in der Cloud, über eine count()-Abfrage - die
  /// zählt serverseitig und lädt keine Dokumente.
  int? _totalPending;

  String _filterType = 'all'; // all, farm, human, field
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Drops a decided registration from the in-memory queue.
  ///
  /// The object has just left `qcPending`, so a full reload would return this
  /// exact list minus that one entry - at the price of one collection query
  /// plus one method fetch per remaining registration. On a queue of any size
  /// that is seconds of waiting for a result we already know.
  void _removeEntryLocally(Map<String, dynamic> object) {
    final String uid = object['identity']?['UID']?.toString() ?? '';
    if (uid.isEmpty || !mounted) return;

    setState(() {
      _pendingRegistrations =
          _pendingRegistrations.where((e) => e.uid != uid).toList();
      _registrarCache.remove(uid);

      // Deciding the last entry of the registrar currently filtered on would
      // otherwise leave an empty list behind with no visible reason.
      if (_registrarFilter != 'all' &&
          !_pendingRegistrations
              .any((e) => e.registrarUid == _registrarFilter)) {
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
  Query<Map<String, dynamic>> _pendingQuery() => FirebaseFirestore.instance
      .collection('TFC_objects')
      .where('objectState', isEqualTo: 'qcPending')
      .orderBy(FieldPath.documentId)
      .limit(_pageSize);

  /// [fromInitState] suppresses the initial setState: at that point this
  /// element is being built, and marking it dirty from inside its own build
  /// forces a rebuild within the running build/layout pass. With a
  /// LayoutBuilder above the route - device_preview wraps the whole app in one
  /// while `!kReleaseMode` - that surfaces as
  /// "_RenderLayoutBuilder was mutated in performLayout" when the screen opens.
  /// The fields are simply assigned instead; the first build reads them anyway.
  Future<void> _loadPendingRegistrations({bool fromInitState = false}) async {
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
    _registrarCache.clear();
    _loadedUids.clear();
    _methodCursor = null;
    _methodsExhausted = false;
    _dateOrderUnavailable = false;
    _objectCursor = null;
    _objectsExhausted = false;
    _totalPending = null;

    // Nur fürs Anzeigen ("150 von 2500 geladen"), deshalb ohne await im
    // kritischen Pfad.
    unawaited(_loadTotalCount());

    try {
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
    try {
      // Je Typ einzeln: offene Bild-Objekte tragen denselben Zustand, gehören
      // aber nicht in die Warteschlange - eine Gesamtzahl über alle wäre eine
      // andere Zahl als die Liste zeigt.
      final counts = await Future.wait(
        ['farm', 'human', 'field'].map(
          (ralType) => FirebaseFirestore.instance
              .collection('TFC_objects')
              .where('objectState', isEqualTo: 'qcPending')
              .where('template.RALType', isEqualTo: ralType)
              .count()
              .get(),
        ),
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
        collected.addAll(await _loadFromCreationMethods());
      }

      if (collected.length < _targetPerLoad && _methodsExhausted) {
        collected.addAll(await _loadFromObjects());
      }

      if (!mounted) return;
      setState(() {
        _pendingRegistrations = [..._pendingRegistrations, ...collected];
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

    var query = _pendingQuery();
    if (_objectCursor != null) {
      query = query.startAfterDocument(_objectCursor!);
    }

    final snapshot = await query.get();
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

  /// Lädt alle verbleibenden Seiten - für die Übersichtskarte, die nur zeigen
  /// kann, was geladen ist.
  Future<void> _loadAllRemaining() async {
    // Obergrenze als Notbremse: eine Schleife über Netzwerkabfragen, die aus
    // irgendeinem Grund nicht vorankommt, darf die App nicht festhalten.
    for (int page = 0; page < 200 && _hasMore && mounted; page++) {
      await _loadNextPage();
    }
  }

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
    final map = <String, ({String name, String email, String label})>{};
    for (final entry in _pendingRegistrations) {
      if (entry.registrarUid.isEmpty) continue;
      map[entry.registrarUid] = (
        name: entry.registrarName,
        email: entry.registrarEmail,
        label: entry.registrarLabel,
      );
    }
    return map;
  }

  List<_QcEntry> get _filteredRegistrations {
    final query = _searchQuery.trim().toLowerCase();

    final result = _pendingRegistrations.where((entry) {
      if (_filterType != 'all' && entry.ralType != _filterType) return false;
      if (_registrarFilter != 'all' &&
          entry.registrarUid != _registrarFilter) {
        return false;
      }
      if (query.isNotEmpty && !entry.searchIndex.contains(query)) return false;
      return true;
    }).toList();

    // Undated entries sort last in both directions - "unknown" is not "oldest".
    int byDate(_QcEntry a, _QcEntry b, {required bool descending}) {
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
      case _QcSort.type:
        result.sort((a, b) {
          final cmp = a.ralType.compareTo(b.ralType);
          return cmp != 0 ? cmp : byDate(a, b, descending: true);
        });
        break;
    }
    return result;
  }

  Future<void> _approveRegistration(Map<String, dynamic> object) async {
    final l10n = AppLocalizations.of(context)!;

    // Zeige Bestätigungs-Dialog
    final ralType = object['template']?['RALType'];
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovalDialog(
        isApproval: true,
        objectType: ralType,
      ),
    );

    if (notes == null) return; // Abgebrochen

    _setBusy(l10n.qcSavingDecision);

    try {
      String approvalNotes = notes;

      // Für Field-Objekte: Asset Registry Registrierung durchführen
      final ralType = object['template']?['RALType'];
      if (ralType == 'field') {
        // Separate step: this call goes to an external registry and is the
        // slowest part of an approval.
        _setBusy(l10n.qcRegisteringInAssetRegistry);
        final geoIdResult = await _registerFieldInAssetRegistry(object);
        if (geoIdResult['geoId'] != null) {
          // Füge GeoID zu alternateIDs hinzu
          object['identity']['alternateIDs'] =
              object['identity']['alternateIDs'] ?? [];
          object['identity']['alternateIDs'].add({
            'UID': geoIdResult['geoId'],
            'issuedBy': 'Asset Registry',
          });
        } else if (geoIdResult['error'] != null) {
          // API-Fehler: Füge Fehlermeldung zu approvalNotes hinzu
          final errorNote = l10n.assetRegistryRegistrationFailed(
              geoIdResult['error'] ?? 'Unknown error');
          approvalNotes =
              approvalNotes.isEmpty ? errorNote : '$notes\n$errorNote';
        }
      }

      // Erstelle changeObjectData Methode

      // Output: Neues Objekt mit geändertem Status
      Map<String, dynamic> updatedObject = Map<String, dynamic>.from(object);
      updatedObject['objectState'] = 'active';
      setSpecificPropertyJSON(
          updatedObject, "approvalNotes", approvalNotes, "String");
      // Push only. The QC screen reads its data straight from Firestore and is
      // used online, so pulling the whole cloud state back down afterwards adds
      // nothing but wait time before the UI is usable again.
      _setBusy(l10n.qcSavingDecision);
      await changeObjectData(updatedObject, syncFromCloud: false);

      // Aktualisiere Status der verknüpften image-Objekte
      _setBusy(l10n.qcUpdatingPhotos);
      await _updateLinkedImageStatus(
        object,
        'active',
        'qc_approval',
        approvalNotes.isNotEmpty ? approvalNotes : null,
      );

      // UI aktualisieren
      repaintContainerList.value = true;
      _removeEntryLocally(object);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationApproved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving registration: $e');
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

  Future<void> _rejectRegistration(Map<String, dynamic> object) async {
    final l10n = AppLocalizations.of(context)!;

    // Zeige Ablehnungs-Dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovalDialog(isApproval: false),
    );

    if (reason == null) return; // Abgebrochen

    _setBusy(l10n.qcSavingDecision);

    try {
      // Erstelle changeObjectData Methode

      Map<String, dynamic> updatedObject = Map<String, dynamic>.from(object);
      updatedObject['objectState'] = 'qcRejected';
      setSpecificPropertyJSON(
          updatedObject, 'rejectionReason', reason, 'String');

      // Speichern in Firestore
      updatedObject =
          jsonFullDoubleToInt(sortJsonAlphabetically(updatedObject));

      // Push only - see the note in _approveRegistration.
      await changeObjectData(updatedObject, syncFromCloud: false);

      // Aktualisiere Status der verknüpften image-Objekte
      _setBusy(l10n.qcUpdatingPhotos);
      await _updateLinkedImageStatus(
        object,
        'qcRejected',
        'qc_rejection',
        reason.isNotEmpty ? reason : null,
      );

      repaintContainerList.value = true;
      _removeEntryLocally(object);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationRejected),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting registration: $e');
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
        ],
      ),
      body: Column(
        children: [
          if (_dateOrderUnavailable) _buildDateOrderWarning(l10n),
          _buildSearchField(l10n),
          _buildSortAndRegistrarRow(l10n),
          _buildTypeChips(l10n),
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
    final entries = _filteredRegistrations;

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
                      _pendingRegistrations.length, _totalPending!)
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
      final hasActiveFilter = _filterType != 'all' ||
          _registrarFilter != 'all' ||
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
          : _buildRegistrationCard(entries[index]),
    );
  }

  /// Warnung, wenn die Warteschlange nicht global nach Datum geordnet werden
  /// konnte.
  Widget _buildDateOrderWarning(AppLocalizations l10n) {
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
              l10n.qcDateOrderUnavailable,
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
                      _pendingRegistrations.length, _totalPending!)
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
              l10n.qcLoadedOfTotal(_pendingRegistrations.length, _totalPending!),
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

  /// Polygone für die Übersichtskarte - aus denselben Einträgen, die die Liste
  /// zeigt, damit Suche und Filter auf beide Ansichten wirken. Objekte ohne
  /// verwertbare Boundaries (Farmen, Farmer, abgebrochene Aufnahmen) fallen
  /// hier heraus.
  List<QcMapPolygon> get _mapPolygons {
    final result = <QcMapPolygon>[];
    for (final entry in _filteredRegistrations) {
      if (entry.uid.isEmpty) continue; // PolygonId muss eindeutig sein
      final points = _getBoundariesFromObject(entry.object);
      if (points == null || points.length < 3) continue;

      final area = getSpecificPropertyfromJSON(entry.object, 'area');
      result.add(QcMapPolygon(
        uid: entry.uid,
        name: entry.name,
        points: points,
        accuracies: _getBoundaryAccuracies(entry.object),
        registrarName: entry.registrarName,
        areaHa: (area is num) ? area.toDouble() : null,
      ));
    }
    return result;
  }

  /// Auswahl auf der Übersichtskarte: Eckdaten des Feldes plus derselbe
  /// Freigabe-Flow wie in der Liste.
  void _showPolygonSheet(QcMapPolygon polygon) {
    final l10n = AppLocalizations.of(context)!;
    final matches = _pendingRegistrations.where((e) => e.uid == polygon.uid);
    if (matches.isEmpty) return;

    final entry = matches.first;
    final obj = entry.object;
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
              entry.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 12),
            _buildCardMeta(Icons.person_outline, entry.registrarName),
            const SizedBox(height: 4),
            _buildCardMeta(
              Icons.event,
              entry.registeredAt != null
                  ? _formatRegistrationDate(entry.registeredAt!)
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
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _rejectRegistration(obj);
                  },
                  icon: const Icon(Icons.close),
                  label: Text(l10n.rejectRegistration),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _approveRegistration(obj);
                  },
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
      )),
    );
  }

  void _resetFilters() {
    setState(() {
      _filterType = 'all';
      _registrarFilter = 'all';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: l10n.qcSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
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
    final showRegistrarFilter = registrars.length > 1;

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
                DropdownMenuItem(
                  value: _QcSort.type,
                  child: Text(l10n.sortByType),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sortMode = value);
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
                  if (value != null) setState(() => _registrarFilter = value);
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

  Widget _buildTypeChips(AppLocalizations l10n) {
    int countOf(String type) =>
        _pendingRegistrations.where((e) => e.ralType == type).length;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text('${l10n.all} (${_pendingRegistrations.length})'),
              selected: _filterType == 'all',
              onSelected: (selected) => setState(() => _filterType = 'all'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('${l10n.farms} (${countOf('farm')})'),
              selected: _filterType == 'farm',
              onSelected: (selected) => setState(() => _filterType = 'farm'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('${l10n.farmers} (${countOf('human')})'),
              selected: _filterType == 'human',
              onSelected: (selected) => setState(() => _filterType = 'human'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('${l10n.fields} (${countOf('field')})'),
              selected: _filterType == 'field',
              onSelected: (selected) => setState(() => _filterType = 'field'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCount(AppLocalizations l10n) {
    if (_isLoading || _pendingRegistrations.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = _filteredRegistrations.length;
    final loaded = _pendingRegistrations.length;
    final total = _totalPending;

    final parts = <String>[
      if (shown != loaded) l10n.qcResultCount(shown, loaded),
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

  Widget _buildRegistrationCard(_QcEntry entry) {
    final obj = entry.object;
    final l10n = AppLocalizations.of(context)!;
    final ralType = entry.ralType;
    final name = entry.name;

    IconData icon;
    Color color;
    String subtitle = '';

    switch (ralType) {
      case 'farm':
        icon = Icons.agriculture;
        color = Colors.green;
        subtitle = l10n.farmDetails;
        break;
      case 'human':
        icon = Icons.person;
        color = Colors.blue;
        subtitle = l10n.farmerDetails;
        break;
      case 'field':
        icon = Icons.map;
        color = Colors.orange;
        final area = getSpecificPropertyfromJSON(obj, 'area');
        final areaValue = (area is num) ? area.toDouble() : 0.0;
        subtitle = '${l10n.fieldArea}: ${areaValue.toStringAsFixed(2)} ha';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(color: Colors.black)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 2),
            // Date and registrar directly on the card: they are the two things
            // a reviewer scans the queue by.
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                _buildCardMeta(
                  Icons.event,
                  entry.registeredAt != null
                      ? _formatRegistrationDate(entry.registeredAt!)
                      : '-',
                ),
                _buildCardMeta(Icons.person_outline, entry.registrarName),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Layout: Details links, Map rechts (wenn Geodaten vorhanden)
                _hasGeoData(obj)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildObjectDetails(obj),
                          ),
                          const SizedBox(width: 16),
                          _buildMiniMapWidget(obj),
                        ],
                      )
                    : _buildObjectDetails(obj),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (ralType == 'field') ...[
                      TextButton.icon(
                        onPressed: () {
                          final l10n = AppLocalizations.of(context)!;
                          final boundariesRaw =
                              getSpecificPropertyfromJSON(obj, 'boundaries');
                          final area = getSpecificPropertyfromJSON(obj, 'area')
                                  ?.toString() ??
                              '';
                          String? geoId;
                          final altIds =
                              obj['identity']?['alternateIDs'] as List?;
                          if (altIds != null) {
                            for (final a in altIds) {
                              if (a['issuedBy'] == 'Asset Registry') {
                                geoId = a['UID'] as String?;
                                break;
                              }
                            }
                          }
                          FieldDownloadHelper.downloadGeoJSON(
                            context,
                            name:
                                obj['identity']?['name'] as String? ?? 'field',
                            boundariesJson: boundariesRaw?.toString(),
                            l10n: l10n,
                            area: area,
                            geoId: geoId,
                          );
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('GeoJSON',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          final l10n = AppLocalizations.of(context)!;
                          final boundariesRaw =
                              getSpecificPropertyfromJSON(obj, 'boundaries');
                          final area = getSpecificPropertyfromJSON(obj, 'area')
                                  ?.toString() ??
                              '';
                          String? geoId;
                          final altIds =
                              obj['identity']?['alternateIDs'] as List?;
                          if (altIds != null) {
                            for (final a in altIds) {
                              if (a['issuedBy'] == 'Asset Registry') {
                                geoId = a['UID'] as String?;
                                break;
                              }
                            }
                          }
                          FieldDownloadHelper.downloadKML(
                            context,
                            name:
                                obj['identity']?['name'] as String? ?? 'Field',
                            boundariesJson: boundariesRaw?.toString(),
                            l10n: l10n,
                            area: area,
                            geoId: geoId,
                          );
                        },
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label:
                            const Text('KML', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      onPressed: () => _rejectRegistration(obj),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.rejectRegistration),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _approveRegistration(obj),
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

      // Eigentümer der Farm - wird asynchron geladen
      details.add(_buildOwnerRow(obj, l10n));
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

  /// Lädt den Namen und UID des Farm-Eigentümers aus linkedObjectRef
  Future<Map<String, String>> _getOwnerInfo(
      Map<String, dynamic> farmObj) async {
    try {
      // Hole linkedObjectRef
      final linkedObjectRef = farmObj['linkedObjectRef'];
      if (linkedObjectRef == null ||
          linkedObjectRef is! List ||
          linkedObjectRef.isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Finde Eintrag mit rolle = "owner"
      Map<String, dynamic>? ownerRef;
      for (var link in linkedObjectRef) {
        if (link is Map && link['role'] == 'owner') {
          ownerRef = Map<String, dynamic>.from(link);
          break;
        }
      }

      if (ownerRef == null || !ownerRef.containsKey('UID')) {
        return {'name': '-', 'uid': ''};
      }

      final ownerUID = ownerRef['UID'];
      if (ownerUID == null || ownerUID.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Lade Eigentümer-Objekt aus TFC_objects
      final ownerDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(ownerUID.toString())
          .get();

      if (!ownerDoc.exists) {
        return {'name': '-', 'uid': ''};
      }

      final ownerData = ownerDoc.data();
      if (ownerData == null) {
        return {'name': '-', 'uid': ''};
      }

      // Extrahiere identity -> name
      final identity = ownerData['identity'];
      if (identity == null || identity is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final name = identity['name'];
      if (name == null || name.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      return {'name': name.toString(), 'uid': ownerUID.toString()};
    } catch (e) {
      debugPrint('Error getting owner info: $e');
      return {'name': '-', 'uid': ''};
    }
  }

  /// Widget für "Eigentümer" Zeile mit FutureBuilder
  Widget _buildOwnerRow(Map<String, dynamic> obj, AppLocalizations l10n) {
    return FutureBuilder<Map<String, String>>(
      future: _getOwnerInfo(obj),
      builder: (context, snapshot) {
        final info = snapshot.data ?? {'name': '...', 'uid': ''};
        final ownerName = info['name'] ?? '...';
        final ownerUID = info['uid'] ?? '';

        return _buildDetailRow(
          l10n.owner,
          ownerName,
          onTap: ownerUID.isNotEmpty && ownerName != '-' && ownerName != '...'
              ? () => _showObjectDetailsDialog(ownerUID)
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
      future: _getImageURLFromLinkedObject(obj, role),
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

  /// Schreibt eine im Karteneditor korrigierte Feldgrenze über den signierten
  /// openRAL-Pfad und übernimmt die neue Fassung in die Liste.
  ///
  /// Die geschriebene Version kommt direkt aus dem Service zurück; ein erneutes
  /// Laden aus Firestore wäre ein Rennen gegen den asynchronen Cloud-Sync und
  /// würde oft noch den alten Stand zeigen.
  Future<void> _saveGeometryEdit(
      Map<String, dynamic> obj, FieldGeometryEdit edit) async {
    final l10n = AppLocalizations.of(context)!;
    _setBusy(l10n.qcPolygonSaving);

    try {
      final updated = await saveFieldGeometry(field: obj, edit: edit);
      final uid = updated['identity']?['UID']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _pendingRegistrations = [
            for (final entry in _pendingRegistrations)
              entry.uid == uid ? entry.withObject(updated) : entry,
          ];
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

  /// Ändert den objectState aller verknüpften image-Objekte
  /// [parentObject] - Das Eltern-Objekt (Farmer, Farm, Field)
  /// [newState] - Der neue Status (z.B. 'active', 'qcRejected')
  /// [changeType] - Art der Änderung (z.B. 'qc_approval', 'qc_rejection')
  /// [notes] - Optionale Notizen
  Future<void> _updateLinkedImageStatus(
    Map<String, dynamic> parentObject,
    String newState,
    String changeType,
    String? notes,
  ) async {
    try {
      final linkedObjectRef = parentObject['linkedObjectRef'];
      if (linkedObjectRef == null || linkedObjectRef is! List) {
        return;
      }

      // Finde alle image-Objekte
      final imageRefs =
          linkedObjectRef.where((ref) => ref['RALType'] == 'image').toList();

      if (imageRefs.isEmpty) {
        debugPrint('No linked image objects found');
        return;
      }

      debugPrint('Updating ${imageRefs.length} linked image object(s)');

      // Aktualisiere jedes image-Objekt
      for (final imageRef in imageRefs) {
        final imageUID = imageRef['UID']?.toString();
        if (imageUID == null || imageUID.isEmpty) continue;

        try {
          // Lade image-Objekt aus Firestore
          final imageDoc = await FirebaseFirestore.instance
              .collection('TFC_objects')
              .doc(imageUID)
              .get();

          if (!imageDoc.exists) {
            debugPrint('Image object not found: $imageUID');
            continue;
          }

          final imageObj = Map<String, dynamic>.from(imageDoc.data()!);
          final currentState = imageObj['objectState'] ?? 'unknown';

          debugPrint(
              'Updating image $imageUID from $currentState to $newState');

          // Output: Neues image-Objekt mit geändertem Status
          Map<String, dynamic> updatedImage =
              Map<String, dynamic>.from(imageObj);
          updatedImage['objectState'] = newState;
          updatedImage =
              jsonFullDoubleToInt(sortJsonAlphabetically(updatedImage));

          // Push only - this runs once per linked photo, so a full pull each
          // time would multiply the wait after every QC decision.
          await changeObjectData(updatedImage, syncFromCloud: false);

          debugPrint('Image $imageUID updated successfully');
        } catch (e) {
          debugPrint('Error updating image $imageUID: $e');
          // Fahre mit nächstem Bild fort
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error in _updateLinkedImageStatus: $e');
      // Werfe Fehler nicht weiter, da Haupt-Objekt bereits gespeichert wurde
    }
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
      final city =
          obj['currentGeolocation']?['postalAddress']?['cityName'] ?? '-';
      final country =
          obj['currentGeolocation']?['postalAddress']?['countryName'] ?? '-';

      details.addAll([
        _buildInfoRow(
            l10n.totalArea, '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildInfoRow(l10n.cityName, city),
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

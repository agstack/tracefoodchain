import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import '../services/field_geometry_service.dart';
import '../utils/gps_quality.dart';
import '../utils/polygon_geometry.dart';
import 'map_type_selector.dart';

/// Bildschirmfüllende Feldkarte - ansehen und, wenn erlaubt, korrigieren.
///
/// Im Bearbeitungsmodus hängt an jeder Ecke ein ziehbarer Marker: ziehen
/// verschiebt sie, antippen löscht sie, ein Tipp auf die Karte setzt eine neue
/// Ecke auf die nächstgelegene Kante. Gespeichert wird nicht hier - die Seite
/// gibt das Ergebnis als [FieldGeometryEdit] zurück, damit der aufrufende
/// Screen es über den signierten openRAL-Pfad schreiben kann.
class FieldPolygonMapPage extends StatefulWidget {
  const FieldPolygonMapPage({
    super.key,
    required this.title,
    required this.points,
    this.accuracies,
    this.canEdit = false,
  });

  final String title;

  /// Stützpunkte wie gespeichert - geschlossener oder offener Ring.
  final List<LatLng> points;

  /// Punktgleiche GPS-Genauigkeiten, falls erfasst.
  final List<double>? accuracies;

  final bool canEdit;

  @override
  State<FieldPolygonMapPage> createState() => _FieldPolygonMapPageState();
}

/// Zustand einer Bearbeitung, für Undo und Verwerfen.
class _Snapshot {
  const _Snapshot(this.points, this.ids, this.accuracies, this.moved,
      this.added, this.deleted);

  final List<LatLng> points;
  final List<int> ids;
  final List<double>? accuracies;
  final int moved;
  final int added;
  final int deleted;
}

class _FieldPolygonMapPageState extends State<FieldPolygonMapPage> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.satellite;

  /// Gearbeitet wird immer auf dem offenen Ring; geschlossen wird erst beim
  /// Speichern.
  late List<LatLng> _points;
  late List<double>? _accuracies;

  /// Dauerhafte Kennung je Stützpunkt. Die Marker-ID darf nicht der Listenindex
  /// sein: nach dem Löschen oder Einfügen einer Ecke würde dieselbe ID einen
  /// anderen Punkt bezeichnen, und Google Maps schiebt die Position dann auf den
  /// falschen Marker.
  late List<int> _ids;
  int _nextId = 0;

  bool _editing = false;

  /// Letzte bekannte Zeigerposition über der Karte, in logischen Pixeln.
  ///
  /// `Polygon.onTap` meldet nur, *dass* die Fläche getroffen wurde, nie *wo* -
  /// und weil ein anklickbares Polygon den Tipp verbraucht, meldet die Karte
  /// ihn nicht mehr. Die Koordinate kommt deshalb aus der Zeigerposition,
  /// umgerechnet über den Kartencontroller. Genau so löst es SoilDiagnostix.
  Offset? _lastPointerPosition;

  /// Bis wann Kartenereignisse ignoriert werden.
  ///
  /// Der durchgereichte Klick trifft die Karte mitunter erst, nachdem der
  /// Dialog bereits geschlossen ist. Ein "ist gerade ein Dialog offen"-Flag
  /// greift dafür zu spät, ein kurzes Zeitfenster dagegen zuverlässig.
  DateTime? _ignoreMapEventsUntil;

  int _moved = 0;
  int _added = 0;
  int _deleted = 0;

  final List<_Snapshot> _undo = [];
  late _Snapshot _original;

  @override
  void initState() {
    super.initState();
    _points = openRing(widget.points);
    _accuracies = _alignAccuracies(widget.accuracies, _points.length);
    _ids = [for (final _ in _points) _nextId++];
    _original = _snapshot();
  }

  // Kein dispose() für den Kartencontroller: den entsorgt das GoogleMap-Widget
  // selbst. Ein zweiter Aufruf lässt die Web-Implementierung mit
  // "Maps cannot be retrieved before calling buildView!" auflaufen.

  /// Bringt die Genauigkeiten auf die Länge des offenen Rings.
  ///
  /// Gespeichert wird mal mit, mal ohne Schlusspunkt; fehlende Werte werden als
  /// "von Hand gesetzt" markiert, statt eine Messung zu erfinden.
  List<double>? _alignAccuracies(List<double>? source, int length) {
    if (source == null || source.isEmpty) return null;
    final result = List<double>.from(source.take(length));
    while (result.length < length) {
      result.add(manuallyEditedAccuracy);
    }
    return result;
  }

  _Snapshot _snapshot() => _Snapshot(
        List<LatLng>.from(_points),
        List<int>.from(_ids),
        _accuracies == null ? null : List<double>.from(_accuracies!),
        _moved,
        _added,
        _deleted,
      );

  void _pushUndo() {
    _undo.add(_snapshot());
    // Mehr als ein paar Schritte zurück braucht niemand, und jeder Schritt
    // hält eine Kopie des Rings.
    if (_undo.length > 30) _undo.removeAt(0);
  }

  void _restore(_Snapshot snapshot) {
    setState(() {
      _points = List<LatLng>.from(snapshot.points);
      _ids = List<int>.from(snapshot.ids);
      _accuracies = snapshot.accuracies == null
          ? null
          : List<double>.from(snapshot.accuracies!);
      _moved = snapshot.moved;
      _added = snapshot.added;
      _deleted = snapshot.deleted;
    });
  }

  bool get _hasChanges => _moved > 0 || _added > 0 || _deleted > 0;

  bool get _mapEventsBlocked {
    final until = _ignoreMapEventsUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Nach jedem Dialog: kurzes Fenster, in dem die Karte nichts annimmt.
  void _blockMapEventsBriefly() {
    _ignoreMapEventsUntil =
        DateTime.now().add(const Duration(milliseconds: 700));
  }

  // ---------------------------------------------------------------- Bearbeiten

  void _moveCorner(int index, LatLng position) {
    _pushUndo();
    setState(() {
      _points[index] = position;
      _accuracies?[index] = manuallyEditedAccuracy;
      _moved++;
    });
  }

  Future<void> _deleteCorner(int index) async {
    final l10n = AppLocalizations.of(context)!;

    // Auch ein Marker kann von einem durchgereichten Klick getroffen werden.
    if (_mapEventsBlocked) return;

    if (_points.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.qcMinThreeCorners),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => PointerInterceptor(
          child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.qcDeleteCornerTitle,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.qcDeleteCornerMessage(index + 1),
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      )),
    );

    _blockMapEventsBriefly();
    if (confirmed != true) return;

    _pushUndo();
    setState(() {
      _points.removeAt(index);
      _ids.removeAt(index);
      _accuracies?.removeAt(index);
      _deleted++;
    });
  }

  /// Wie weit ein Tipp höchstens von der Feldgrenze entfernt sein darf, damit er
  /// als "hier fehlt eine Ecke" gilt. Ohne diese Grenze macht jeder
  /// versehentliche Tipp neben dem Feld aus dem Polygon eine lange Spitze - und
  /// weil sich die Kanten dabei überschlagen, sieht die Flächenzahl danach
  /// sogar unauffällig aus.
  static const double _maxAddDistanceMeters = 60.0;

  void _rememberPointer(Offset localPosition) =>
      _lastPointerPosition = localPosition;

  /// Treffer auf der Fläche oder einer Kante des Polygons: hier soll eine Ecke
  /// hin. Die Stelle ergibt sich aus der zuletzt gemeldeten Zeigerposition.
  Future<void> _handlePolygonTap() async {
    if (!_editing) return;
    if (_mapEventsBlocked || ModalRoute.of(context)?.isCurrent == false) return;

    final controller = _controller;
    final pointer = _lastPointerPosition;
    if (controller == null || pointer == null) return;

    // Auf den mobilen Karten sind Bildschirmkoordinaten physische Pixel, im
    // Web logische.
    final ratio = kIsWeb ? 1.0 : MediaQuery.of(context).devicePixelRatio;

    try {
      final position = await controller.getLatLng(ScreenCoordinate(
        x: (pointer.dx * ratio).round(),
        y: (pointer.dy * ratio).round(),
      ));
      if (!mounted) return;
      _addCorner(position);
    } catch (e) {
      debugPrint('Field editor: could not resolve tap position: $e');
    }
  }

  void _addCorner(LatLng position) {
    final l10n = AppLocalizations.of(context)!;

    // Innerhalb der Fläche ist der Tipp eindeutig gemeint, egal wie weit die
    // nächste Kante entfernt ist; ausserhalb zählt der Abstand.
    final plausible = isPointInsideRing(position, _points) ||
        distanceToRingInMeters(position, _points) <= _maxAddDistanceMeters;
    if (!plausible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.qcEditPolygonTapTooFar),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final index = insertIndexForPoint(position, _points);
    _pushUndo();
    setState(() {
      _points.insert(index, position);
      _ids.insert(index, _nextId++);
      _accuracies?.insert(index, manuallyEditedAccuracy);
      _added++;
    });
  }

  // ------------------------------------------------------------------ Abschluss

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.qcEditPolygonNoChanges)),
      );
      return;
    }

    final area = polygonAreaInHectares(closeRing(_points));
    final previousArea = polygonAreaInHectares(closeRing(_original.points));
    final crosses = ringSelfIntersects(_points);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => PointerInterceptor(
          child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.qcEditPolygonSaveTitle,
            style: const TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.qcEditPolygonSaveMessage(area.toStringAsFixed(2)),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.qcEditPolygonAreaBefore(previousArea.toStringAsFixed(2)),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            // Überschlagene Kanten sind der Grund, warum eine versehentliche
            // Ecke lange unbemerkt bleibt: die Fläche wird dadurch kleiner,
            // nicht größer.
            if (crosses) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.qcEditPolygonSelfIntersect,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save),
          ),
        ],
      )),
    );

    _blockMapEventsBriefly();
    if (confirmed != true || !mounted) return;

    Navigator.pop(
      context,
      FieldGeometryEdit(
        points: List<LatLng>.from(_points),
        accuracies: _accuracies ?? const [],
        movedCorners: _moved,
        addedCorners: _added,
        deletedCorners: _deleted,
      ),
    );
  }

  Future<void> _close() async {
    final l10n = AppLocalizations.of(context)!;

    if (_hasChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => PointerInterceptor(
            child: AlertDialog(
          backgroundColor: Colors.white,
          title: Text(l10n.qcEditPolygonDiscardTitle,
              style: const TextStyle(color: Colors.black)),
          content: Text(l10n.qcEditPolygonDiscardMessage,
              style: const TextStyle(color: Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.qcEditPolygonReset),
            ),
          ],
        )),
      );
      _blockMapEventsBriefly();
      if (discard != true || !mounted) return;
    }

    Navigator.pop(context);
  }

  // ---------------------------------------------------------------- Kartenteile

  double _markerHue(int index) {
    final accuracy = _accuracies == null ? null : _accuracies![index];
    if (accuracy == null || isManuallyEditedAccuracy(accuracy)) {
      return BitmapDescriptor.hueAzure;
    }
    if (accuracy <= 5.0) return BitmapDescriptor.hueGreen;
    if (accuracy <= 10.0) return 90.0; // Hellgrün
    if (accuracy <= 15.0) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }

  Set<Marker> _cornerMarkers() {
    if (!_editing) return {};
    return {
      for (int i = 0; i < _points.length; i++)
        Marker(
          markerId: MarkerId('corner_${_ids[i]}'),
          position: _points[i],
          draggable: true,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(i)),
          // Bewusst kein onDrag: würde die Marker-Positionen mitten in der
          // laufenden Ziehbewegung neu an die Karte schreiben. Die Karte
          // korrigiert dann gegen die Geste, und der Punkt kann am Ende
          // irgendwo landen. Übernommen wird erst die Endposition.
          onDragEnd: (position) => _moveCorner(i, position),
          onTap: () => _deleteCorner(i),
        ),
    };
  }

  /// Genauigkeitskreise nur im Ansichtsmodus - beim Bearbeiten verdecken sie
  /// die Marker, die man treffen will.
  Set<Circle> _accuracyCircles() {
    final accuracies = _accuracies;
    if (_editing || accuracies == null) return {};
    return {
      for (int i = 0; i < _points.length && i < accuracies.length; i++)
        if (!isManuallyEditedAccuracy(accuracies[i]))
          Circle(
            circleId: CircleId('accuracy_$i'),
            center: _points[i],
            radius: accuracies[i],
            strokeWidth: 2,
            strokeColor: gpsAccuracyColor(accuracies[i]),
            fillColor: gpsAccuracyColor(accuracies[i]).withOpacity(0.2),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final closed = closeRing(_points);
    final area = polygonAreaInHectares(closed);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _close,
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: Icon(_editing ? Icons.edit_off : Icons.edit_location_alt),
              tooltip: l10n.qcEditPolygon,
              onPressed: () => setState(() => _editing = !_editing),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Die Zeigerposition wird laufend mitgeschrieben - Maus wie Finger.
          MouseRegion(
            onHover: (event) => _rememberPointer(event.localPosition),
            child: Listener(
              onPointerDown: (event) => _rememberPointer(event.localPosition),
              onPointerMove: (event) => _rememberPointer(event.localPosition),
              child: GoogleMap(
                mapType: _mapType,
                initialCameraPosition: CameraPosition(
                  target: polygonCentroid(_points),
                  zoom: 17,
                ),
                polygons: {
                  Polygon(
                    polygonId: const PolygonId('field'),
                    points: closed,
                    strokeColor: Colors.blue,
                    strokeWidth: 3,
                    fillColor: Colors.blue.withOpacity(0.2),
                    // Muss den Tipp verbrauchen: erst damit wird das Polygon
                    // im Web überhaupt anklickbar (`clickable` wird aus diesem
                    // Feld gesetzt). Der Nebeneffekt ist erwünscht - ein Tipp
                    // neben der Fläche kann so gar keine Ecke mehr erzeugen.
                    consumeTapEvents: true,
                    onTap: _handlePolygonTap,
                  ),
                },
                markers: _cornerMarkers(),
                circles: _accuracyCircles(),
                // Kein onTap: neue Ecken entstehen ausschliesslich über einen
                // Treffer auf dem Polygon.
                onMapCreated: (controller) {
                  _controller = controller;
                  _fitPolygon();
                },
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: true,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Listener(
              onPointerDown: (_) => _blockMapEventsBriefly(),
              child: MapTypeSelector(
                selected: _mapType,
                onSelected: (type) => setState(() => _mapType = type),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _Panel(
              child: Text(
                '${l10n.fieldArea}: ${area.toStringAsFixed(2)} ha  ·  '
                '${l10n.polygonPoints}: ${_points.length}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (!_editing) _buildLegend(l10n),
          if (_editing) _buildEditBar(l10n),
        ],
      ),
    );
  }

  Future<void> _fitPolygon() async {
    final controller = _controller;
    if (controller == null || _points.isEmpty) return;

    double minLat = _points.first.latitude, maxLat = minLat;
    double minLng = _points.first.longitude, maxLng = minLng;
    for (final p in _points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    try {
      await controller.moveCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ));
    } catch (e) {
      // Auf Web wirft der Aufruf, solange die Karte noch keine Größe hat.
      debugPrint('Field map: could not fit polygon: $e');
    }
  }

  Widget _buildLegend(AppLocalizations l10n) {
    return Positioned(
      bottom: 16,
      left: 12,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.gpsQualityLegend,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            _legendItem(Colors.green, '<= 5m', l10n.gpsQualityExcellent),
            _legendItem(Colors.lightGreen, '<= 10m', l10n.gpsQualityGood),
            _legendItem(Colors.orange, '<= 15m', l10n.gpsQualityMedium),
            _legendItem(Colors.red, '> 15m', l10n.gpsQualityPoor),
            _legendItem(Colors.blueGrey, '-', l10n.gpsQualityManual),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String range, String quality) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$range - $quality',
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBar(AppLocalizations l10n) {
    return Positioned(
      bottom: 16,
      left: 12,
      right: 12,
      // Jeder Druck auf ein Bedienelement erreicht auf Web auch die Karte.
      // Solange "Ecke hinzufügen" scharf ist, würde schon "Rückgängig" eine
      // Ecke setzen - deshalb sperrt jede Berührung hier die Karte kurz.
      child: Listener(
        onPointerDown: (_) => _blockMapEventsBriefly(),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.qcEditPolygonHint,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              if (ringSelfIntersects(_points))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.qcEditPolygonSelfIntersect,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_hasChanges)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.qcEditPolygonSummary(_moved, _added, _deleted),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _undo.isEmpty
                        ? null
                        : () {
                            final snapshot = _undo.removeLast();
                            _restore(snapshot);
                          },
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l10n.qcEditPolygonUndo),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _hasChanges
                        ? () {
                            _undo.clear();
                            _restore(_original);
                          }
                        : null,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(l10n.qcEditPolygonReset),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(l10n.save),
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
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      child: child,
    ));
  }
}

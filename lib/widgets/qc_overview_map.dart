import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import '../utils/gps_quality.dart';
import 'map_type_selector.dart';

/// Ein Feld-Polygon in der QC-Übersichtskarte.
///
/// Bewusst ein schlankes Modell statt des vollen openRAL-Objekts: die Karte
/// braucht nur Geometrie und die Kennzahlen, nach denen eingefärbt wird. Die
/// Bounding Box wird einmal beim Anlegen berechnet - sie ist der Filter, mit
/// dem pro Kamerabewegung entschieden wird, ob ein Polygon überhaupt gezeichnet
/// werden muss.
class QcMapPolygon {
  QcMapPolygon({
    required this.uid,
    required this.name,
    required this.points,
    this.accuracies,
    this.registrarName = '',
    this.areaHa,
  })  : assert(points.length >= 3),
        minLat = points.map((p) => p.latitude).reduce(math.min),
        maxLat = points.map((p) => p.latitude).reduce(math.max),
        minLng = points.map((p) => p.longitude).reduce(math.min),
        maxLng = points.map((p) => p.longitude).reduce(math.max);

  final String uid;
  final String name;
  final List<LatLng> points;
  final List<double>? accuracies;
  final String registrarName;
  final double? areaHa;

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  /// Schlechtester Stützpunkt - bestimmt die Farbe des Polygons.
  double? get worstAccuracyValue => worstAccuracy(accuracies);
}

/// Karte mit allen aktuell geladenen QC-Polygonen.
///
/// Gezeichnet wird nur, was im sichtbaren Kartenausschnitt liegt: bei jeder
/// Kamerabewegung wird die Bounding Box jedes Polygons gegen die Viewport-Box
/// getestet. Das hält die Zahl der an Google Maps übergebenen Polygone klein
/// genug, damit die Karte auch im Web flüssig bleibt.
class QcOverviewMap extends StatefulWidget {
  const QcOverviewMap({
    super.key,
    required this.polygons,
    required this.onPolygonTap,
    this.maxRendered = 400,
  });

  final List<QcMapPolygon> polygons;
  final ValueChanged<QcMapPolygon> onPolygonTap;

  /// Obergrenze für gleichzeitig gezeichnete Polygone. Greift nur, wenn sehr
  /// viele Flächen in einem Ausschnitt liegen; gezeichnet werden dann die mit
  /// der schlechtesten Genauigkeit, weil genau die geprüft werden sollen.
  final int maxRendered;

  @override
  State<QcOverviewMap> createState() => _QcOverviewMapState();
}

class _QcOverviewMapState extends State<QcOverviewMap> {
  GoogleMapController? _controller;
  LatLngBounds? _viewport;
  MapType _mapType = MapType.satellite;
  String? _selectedUid;

  // Kein dispose() für den Kartencontroller: den entsorgt das GoogleMap-Widget
  // selbst. Ein zweiter Aufruf lässt die Web-Implementierung mit
  // "Maps cannot be retrieved before calling buildView!" auflaufen.

  /// Umschließende Box aller Polygone, für den ersten Kameraschwenk.
  LatLngBounds? get _allBounds {
    if (widget.polygons.isEmpty) return null;
    double minLat = widget.polygons.first.minLat;
    double maxLat = widget.polygons.first.maxLat;
    double minLng = widget.polygons.first.minLng;
    double maxLng = widget.polygons.first.maxLng;
    for (final p in widget.polygons) {
      minLat = math.min(minLat, p.minLat);
      maxLat = math.max(maxLat, p.maxLat);
      minLng = math.min(minLng, p.minLng);
      maxLng = math.max(maxLng, p.maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Startzoom aus der Ausdehnung geschätzt. Der exakte Fit passiert danach
  /// über [_fitAll]; ein plausibler Startwert verhindert nur, dass die Karte
  /// für einen Frame irgendwo auf dem Globus steht.
  double _initialZoom(LatLngBounds bounds) {
    final span = math.max(
      bounds.northeast.latitude - bounds.southwest.latitude,
      bounds.northeast.longitude - bounds.southwest.longitude,
    );
    if (span <= 0) return 16;
    return (math.log(360 / span) / math.ln2).clamp(2.0, 16.0);
  }

  Future<void> _fitAll() async {
    final bounds = _allBounds;
    final controller = _controller;
    if (bounds == null || controller == null) return;
    try {
      await controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    } catch (e) {
      // Auf Web wirft newLatLngBounds, solange die Karte noch keine Größe hat.
      debugPrint('QC map: could not fit bounds: $e');
    }
    await _updateViewport();
  }

  Future<void> _updateViewport() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      setState(() => _viewport = bounds);
    } catch (e) {
      debugPrint('QC map: could not read visible region: $e');
    }
  }

  /// Bounding-Box-Test gegen den sichtbaren Ausschnitt.
  bool _isInViewport(QcMapPolygon p, LatLngBounds v) {
    if (p.minLat > v.northeast.latitude) return false;
    if (p.maxLat < v.southwest.latitude) return false;
    // Über der Datumsgrenze schlägt der Viewport um; dort wird nicht gefiltert.
    if (v.southwest.longitude > v.northeast.longitude) return true;
    if (p.minLng > v.northeast.longitude) return false;
    if (p.maxLng < v.southwest.longitude) return false;
    return true;
  }

  Color _colorFor(QcMapPolygon p) {
    final worst = p.worstAccuracyValue;
    if (worst == null) return Colors.blueGrey;
    return gpsAccuracyColor(worst);
  }

  /// Liefert die zu zeichnenden Polygone und - für den Zähler - wie viele
  /// insgesamt im Ausschnitt liegen.
  ({Set<Polygon> polygons, int inViewport}) _buildPolygons() {
    final viewport = _viewport;
    final candidates = viewport == null
        ? List<QcMapPolygon>.from(widget.polygons)
        : widget.polygons.where((p) => _isInViewport(p, viewport)).toList();

    final inViewport = candidates.length;

    if (candidates.length > widget.maxRendered) {
      // Schlechteste zuerst: wenn gekappt wird, bleiben die prüfrelevanten
      // Flächen sichtbar. Ohne Genauigkeitsdaten hinten anstellen.
      candidates.sort((a, b) =>
          (b.worstAccuracyValue ?? -1).compareTo(a.worstAccuracyValue ?? -1));
      candidates.removeRange(widget.maxRendered, candidates.length);
    }

    final polygons = candidates.map((p) {
      final color = _colorFor(p);
      final isSelected = p.uid == _selectedUid;
      return Polygon(
        polygonId: PolygonId(p.uid),
        points: p.points,
        strokeColor: isSelected ? Colors.white : color,
        strokeWidth: isSelected ? 5 : 2,
        fillColor: color.withOpacity(isSelected ? 0.5 : 0.25),
        consumeTapEvents: true,
        onTap: () {
          setState(() => _selectedUid = p.uid);
          widget.onPolygonTap(p);
        },
      );
    }).toSet();

    return (polygons: polygons, inViewport: inViewport);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.polygons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.qcMapNoPolygons,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final bounds = _allBounds!;
    final rendered = _buildPolygons();

    return Stack(
      children: [
        GoogleMap(
          mapType: _mapType,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
            ),
            zoom: _initialZoom(bounds),
          ),
          polygons: rendered.polygons,
          onMapCreated: (controller) {
            _controller = controller;
            _fitAll();
          },
          onCameraIdle: _updateViewport,
          onTap: (_) => setState(() => _selectedUid = null),
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: true,
        ),
        // Zähler: macht sichtbar, dass nur der Ausschnitt gezeichnet wird.
        Positioned(
          top: 12,
          left: 12,
          child: _Chip(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.qcMapVisibleCount(
                      rendered.polygons.length, widget.polygons.length),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (rendered.inViewport > rendered.polygons.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.qcMapCapped(widget.maxRendered),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: MapTypeSelector(
            selected: _mapType,
            onSelected: (type) => setState(() => _mapType = type),
          ),
        ),
        Positioned(
          top: 76,
          right: 12,
          child: PointerInterceptor(
              child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            elevation: 4,
            child: IconButton(
              tooltip: l10n.qcMapFitAll,
              icon: const Icon(Icons.zoom_out_map, color: Colors.black87),
              onPressed: _fitAll,
            ),
          )),
        ),
        Positioned(
          bottom: 16,
          left: 12,
          child: _Chip(
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
                _legendItem(Colors.blueGrey, '-', l10n.gpsQualityUnknown),
              ],
            ),
          ),
        ),
      ],
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
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.35),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(2),
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
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trace_foodchain_app/utils/polygon_geometry.dart';

void main() {
  // Ein Quadrat von 0.001 Grad Kantenlänge bei ~15 Grad Nord: rund 111 m mal
  // 107 m, also knapp 1,2 ha. Dient als Referenz für die Flächenrechnung.
  const base = 15.0;
  final square = <LatLng>[
    const LatLng(base, -87.0),
    const LatLng(base + 0.001, -87.0),
    const LatLng(base + 0.001, -87.0 + 0.001),
    const LatLng(base, -87.0 + 0.001),
  ];

  group('Ringe', () {
    test('closeRing hängt den ersten Punkt an', () {
      final closed = closeRing(square);
      expect(closed.length, square.length + 1);
      expect(closed.last, closed.first);
    });

    test('openRing entfernt den Wiederholungspunkt', () {
      expect(openRing(closeRing(square)), square);
    });

    test('openRing lässt einen bereits offenen Ring unverändert', () {
      expect(openRing(square), square);
    });
  });

  group('Fläche', () {
    test('Quadrat von 0.001 Grad ergibt gut einen Hektar', () {
      final area = polygonAreaInHectares(closeRing(square));
      expect(area, closeTo(1.196, 0.01));
    });

    test('entartetes Polygon hat keine Fläche', () {
      expect(polygonAreaInHectares(const [LatLng(0, 0), LatLng(1, 1)]), 0.0);
    });
  });

  group('Neue Ecke einfügen', () {
    test('landet auf der nächstgelegenen Kante', () {
      // Punkt knapp außerhalb der Kante zwischen Index 0 und 1 (Westseite).
      final index = insertIndexForPoint(
        const LatLng(base + 0.0005, -87.0001),
        square,
      );
      expect(index, 1);
    });

    test('trifft auch die Schlusskante zurück zum ersten Punkt', () {
      // Südseite: Kante von Index 3 zurück zu Index 0.
      final index = insertIndexForPoint(
        const LatLng(base - 0.0001, -87.0 + 0.0005),
        square,
      );
      expect(index, 4);
    });
  });

  group('Schwerpunkt', () {
    test('liegt in der Mitte des Quadrats', () {
      final centroid = polygonCentroid(closeRing(square));
      expect(centroid.latitude, closeTo(base + 0.0005, 1e-9));
      expect(centroid.longitude, closeTo(-87.0 + 0.0005, 1e-9));
    });
  });

  group('Ausreißer erkennen', () {
    test('ein sauberes Viereck überschneidet sich nicht', () {
      expect(ringSelfIntersects(square), isFalse);
    });

    test('eine Ecke in der falschen Reihenfolge überschlägt die Kanten', () {
      // Genau das Muster einer versehentlich weit draußen gesetzten Ecke:
      // sie hängt zwischen zwei Punkten, die weit auseinander liegen.
      final spike = <LatLng>[
        square[0],
        square[1],
        const LatLng(base + 0.0005, -87.0 + 0.004),
        square[2],
        square[3],
      ];
      expect(ringSelfIntersects(spike), isTrue);
    });

    test('überschlagene Kanten verkleinern die ausgewiesene Fläche', () {
      // Die Sanduhr-Form ist der Grund für die Warnung beim Speichern.
      final hourglass = <LatLng>[
        square[0],
        square[1],
        square[3],
        square[2],
      ];
      expect(ringSelfIntersects(hourglass), isTrue);
      expect(polygonAreaInHectares(closeRing(hourglass)),
          lessThan(polygonAreaInHectares(closeRing(square))));
    });

    test('Abstand zur Feldgrenze in Metern', () {
      // Rund 11 m westlich der linken Kante.
      final distance = distanceToRingInMeters(
        const LatLng(base + 0.0005, -87.0001),
        square,
      );
      expect(distance, closeTo(10.8, 1.0));
    });

    test('ein Punkt auf der Kante hat Abstand null', () {
      expect(
        distanceToRingInMeters(const LatLng(base + 0.0005, -87.0), square),
        closeTo(0.0, 0.01),
      );
    });
  });

  group('Punkt im Polygon', () {
    test('Mittelpunkt liegt innen', () {
      expect(
        isPointInsideRing(const LatLng(base + 0.0005, -87.0 + 0.0005), square),
        isTrue,
      );
    });

    test('Punkt ausserhalb liegt aussen', () {
      expect(
        isPointInsideRing(const LatLng(base + 0.0005, -87.002), square),
        isFalse,
      );
    });

    test('funktioniert auch auf dem geschlossenen Ring', () {
      expect(
        isPointInsideRing(
            const LatLng(base + 0.0005, -87.0 + 0.0005), closeRing(square)),
        isTrue,
      );
    });
  });
}

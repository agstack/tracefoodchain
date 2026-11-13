import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:trace_foodchain_app/widgets/qc_shape_preview.dart';

Future<void> _pump(WidgetTester tester, QcShapePreview preview) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(width: 300, height: 200, child: preview),
      ),
    ),
  );
}

void main() {
  testWidgets('draws a field polygon with accuracies', (tester) async {
    await _pump(
      tester,
      const QcShapePreview(shapes: [
        QcPreviewShape(
          points: [
            LatLng(14.0000, -87.0000),
            LatLng(14.0010, -87.0000),
            LatLng(14.0010, -86.9990),
            LatLng(14.0000, -86.9990),
          ],
          accuracies: [3, 8, 12, -1],
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(QcShapePreview), findsOneWidget);
  });

  testWidgets('draws a single point without extent', (tester) async {
    await _pump(
      tester,
      const QcShapePreview(points: [
        QcPreviewPoint(position: LatLng(14.0, -87.0), color: Colors.green),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('copes with no geometry and mismatched accuracies',
      (tester) async {
    await _pump(tester, const QcShapePreview());
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const QcShapePreview(shapes: [
        QcPreviewShape(
          points: [
            LatLng(14.0, -87.0),
            LatLng(14.0, -87.0),
            LatLng(14.0, -87.0),
          ],
          accuracies: [5],
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';

/// Sentinel in `boundaryAccuracies` für eine Ecke, die im QC von Hand gesetzt
/// oder verschoben wurde.
///
/// Für solche Punkte gibt es keine GPS-Messung mehr - eine 0 einzutragen würde
/// dagegen "auf den Zentimeter genau" behaupten. Negativ, damit alter Code, der
/// den Wert als Radius liest, ihn nicht versehentlich zeichnet.
const double manuallyEditedAccuracy = -1.0;

bool isManuallyEditedAccuracy(double accuracy) => accuracy < 0;

/// Farbcodierung der GPS-Genauigkeit, wie sie die QC-Legende erklärt.
///
/// Schwellen in Metern: <= 5 sehr gut, <= 10 gut, <= 15 mittel, darüber
/// schlecht. Liegt bewusst zentral, damit Detailkarte, Genauigkeitskreise und
/// Übersichtskarte nicht auseinanderlaufen.
Color gpsAccuracyColor(double accuracyInMeters) {
  if (isManuallyEditedAccuracy(accuracyInMeters)) return Colors.blueGrey;
  if (accuracyInMeters <= 5.0) return Colors.green;
  if (accuracyInMeters <= 10.0) return Colors.lightGreen;
  if (accuracyInMeters <= 15.0) return Colors.orange;
  return Colors.red;
}

/// Schlechtester Messwert einer Aufnahme - die Kennzahl, nach der ein Polygon
/// in der Übersichtskarte eingefärbt wird. Ein einzelner schlechter Stützpunkt
/// verzieht die Fläche genauso wie viele, deshalb Maximum statt Mittelwert.
///
/// Von Hand korrigierte Ecken zählen nicht mit: sie tragen keine Messunsicherheit
/// bei. Bleibt danach kein gemessener Punkt übrig, gibt es keine Kennzahl.
double? worstAccuracy(List<double>? accuracies) {
  if (accuracies == null || accuracies.isEmpty) return null;
  final measured = accuracies.where((a) => !isManuallyEditedAccuracy(a));
  if (measured.isEmpty) return null;
  return measured.reduce((a, b) => a > b ? a : b);
}

import 'package:flutter/material.dart';

/// Farbcodierung der GPS-Genauigkeit, wie sie die QC-Legende erklärt.
///
/// Schwellen in Metern: <= 5 sehr gut, <= 10 gut, <= 15 mittel, darüber
/// schlecht. Liegt bewusst zentral, damit Detailkarte, Genauigkeitskreise und
/// Übersichtskarte nicht auseinanderlaufen.
Color gpsAccuracyColor(double accuracyInMeters) {
  if (accuracyInMeters <= 5.0) return Colors.green;
  if (accuracyInMeters <= 10.0) return Colors.lightGreen;
  if (accuracyInMeters <= 15.0) return Colors.orange;
  return Colors.red;
}

/// Schlechtester Messwert einer Aufnahme - die Kennzahl, nach der ein Polygon
/// in der Übersichtskarte eingefärbt wird. Ein einzelner schlechter Stützpunkt
/// verzieht die Fläche genauso wie viele, deshalb Maximum statt Mittelwert.
double? worstAccuracy(List<double>? accuracies) {
  if (accuracies == null || accuracies.isEmpty) return null;
  return accuracies.reduce((a, b) => a > b ? a : b);
}

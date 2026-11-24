/// Regeln für Ausweisnummern - dieselben wie in der Cloud Function
/// qcPrecheck (functions/src/qc_precheck/national_id.ts).
library;

/// Nur Ziffern - so wird die Nummer gespeichert und verglichen (ohne
/// Bindestriche und Leerzeichen).
String normalizeNationalId(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');

enum NationalIdFormat { ok, missing, wrongLength, implausible }

/// Honduranischer DNI: 13 Ziffern `MMMM JJJJ NNNNN` - Gemeinde der Eintragung
/// (Departamento 01-18, Gemeinde 01-28), Jahr, laufende Nummer.
///
/// [NationalIdFormat.implausible] ist nur ein Hinweis: die Länge stimmt, die
/// Teile sehen aber nicht nach einem echten DNI aus.
NationalIdFormat checkHondurasId(String raw) {
  final id = normalizeNationalId(raw);
  if (id.isEmpty) return NationalIdFormat.missing;
  if (id.length != 13) return NationalIdFormat.wrongLength;
  final department = int.parse(id.substring(0, 2));
  final municipality = int.parse(id.substring(2, 4));
  final year = int.parse(id.substring(4, 8));
  if (department < 1 ||
      department > 18 ||
      municipality < 1 ||
      municipality > 28) {
    return NationalIdFormat.implausible;
  }
  if (year < 1900 || year > DateTime.now().toUtc().year) {
    return NationalIdFormat.implausible;
  }
  return NationalIdFormat.ok;
}

/// 13-stellige Ziffernfolgen in einem OCR-Text - auch mit Bindestrichen oder
/// Leerzeichen dazwischen, wie sie auf dem Ausweis gedruckt sind.
List<String> findIdCandidates(String ocrText) {
  final candidates = <String>{};
  final pattern = RegExp(r'\d[\d\s\-]{11,20}\d');
  for (final match in pattern.allMatches(ocrText)) {
    final digits = normalizeNationalId(match.group(0)!);
    if (digits.length == 13) candidates.add(digits);
  }
  return candidates.toList();
}

/// Großbuchstaben ohne Akzente und Satzzeichen.
List<String> nameTokens(String value) {
  const accents = {
    'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', //
    'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E', //
    'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I', //
    'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', //
    'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U', //
  };
  final upper = value.toUpperCase().split('').map((c) => accents[c] ?? c).join();
  return upper
      .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2)
      .toList();
}

/// Suchbegriffe für den QC-Suchindex (`TFC_qc_index`).
///
/// Spiegelt `functions/src/qc_index/qc_tokens.ts` der Cloud Functions: dort
/// werden die Namen, Kennungen und Orte einer Prüfeinheit genauso gefaltet und
/// mit allen Wortanfängen ab zwei Zeichen abgelegt. Beide Seiten müssen
/// übereinstimmen, sonst findet die Suche nichts.
library;

/// Längere Wörter stehen nur bis zu dieser Länge im Index.
const int qcTokenMaxLength = 20;

const Map<String, String> _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y',
};

final RegExp _accentPattern = RegExp('[${_accents.keys.join()}]');
final RegExp _separators = RegExp('[^a-z0-9]+');
final RegExp _uidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Kleingeschrieben, ohne Akzente und Randleerzeichen ("Gómez " -> "gomez").
String foldForSearch(String value) => value
    .toLowerCase()
    .replaceAllMapped(_accentPattern, (m) => _accents[m[0]]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Die Begriffe einer Sucheingabe, wie sie im Index stehen.
///
/// Einzelne Zeichen fallen weg - der Index führt Wortanfänge erst ab zwei
/// Zeichen. Eine vollständige UID wird als Ganzes gesucht.
List<String> qcQueryTokens(String input) {
  final trimmed = input.trim();
  if (_uidPattern.hasMatch(trimmed)) {
    final compact = trimmed.toLowerCase().replaceAll('-', '');
    return [compact.substring(0, qcTokenMaxLength)];
  }
  final tokens = <String>{};
  for (final word in foldForSearch(trimmed).split(_separators)) {
    if (word.length < 2) continue;
    tokens.add(word.length > qcTokenMaxLength
        ? word.substring(0, qcTokenMaxLength)
        : word);
  }
  return tokens.toList();
}

/// Der Begriff für die Abfrage (`array-contains` erlaubt nur einen): der
/// längste, er grenzt am stärksten ein. Die übrigen prüft der Client.
String? qcServerToken(List<String> tokens) => tokens.isEmpty
    ? null
    : tokens.reduce((a, b) => b.length > a.length ? b : a);

/// Ob alle Suchbegriffe in den Index-Begriffen einer Prüfeinheit stehen.
bool qcTokensMatch(Iterable<String> indexTokens, List<String> queryTokens) {
  final available = indexTokens is Set<String> ? indexTokens : indexTokens.toSet();
  return queryTokens.every(available.contains);
}

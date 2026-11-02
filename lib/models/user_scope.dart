/// Ein Land, optional eingeschränkt auf einzelne Regionen der obersten
/// Verwaltungsebene. Keine Regionen heißt: das ganze Land.
class ScopeEntry {
  const ScopeEntry({required this.country, this.regions = const []});

  /// ISO 3166-1 alpha-2, Großbuchstaben.
  final String country;
  final List<String> regions;

  bool get wholeCountry => regions.isEmpty;

  /// Ob dieser Eintrag [other] vollständig enthält.
  bool covers(ScopeEntry other) =>
      country == other.country &&
      (wholeCountry ||
          (!other.wholeCountry && other.regions.every(regions.contains)));

  /// Ob sich die beiden Einträge irgendwo überschneiden.
  bool overlaps(ScopeEntry other) =>
      country == other.country &&
      (wholeCountry ||
          other.wholeCountry ||
          regions.any(other.regions.contains));

  factory ScopeEntry.fromJson(Map<dynamic, dynamic> json) => ScopeEntry(
        country: (json['country'] ?? '').toString().trim().toUpperCase(),
        regions: json['regions'] is List
            ? (json['regions'] as List)
                .map((r) => r.toString().trim())
                .where((r) => r.isNotEmpty)
                .toSet()
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {'country': country, 'regions': regions};

  @override
  bool operator ==(Object other) =>
      other is ScopeEntry &&
      other.country == country &&
      other.regions.length == regions.length &&
      other.regions.toSet().containsAll(regions);

  @override
  int get hashCode => Object.hash(country, Object.hashAllUnordered(regions));
}

/// Das Gebiet, für das ein Nutzer zuständig ist.
///
/// Steht als specificProperty `assignedScope` am openRAL-Nutzerobjekt und
/// wird nur über eine signierte `changeUserAssignment`-Methode geändert.
class UserScope {
  const UserScope(this.entries);

  static const UserScope empty = UserScope([]);

  /// Key der specificProperty am Nutzerobjekt.
  static const String propertyKey = 'assignedScope';

  /// Key der specificProperty mit der UID des Registrar Coordinators, zu
  /// dessen Team ein Registrar gehört.
  static const String coordinatorKey = 'coordinatorUID';

  final List<ScopeEntry> entries;

  bool get isEmpty => entries.isEmpty;

  List<String> get countries => entries.map((e) => e.country).toList();

  ScopeEntry? entryFor(String country) {
    for (final e in entries) {
      if (e.country == country) return e;
    }
    return null;
  }

  /// Ob dieses Gebiet [other] vollständig enthält.
  bool covers(UserScope other) =>
      other.entries.every((o) => entries.any((e) => e.covers(o)));

  /// Ob sich die beiden Gebiete irgendwo überschneiden.
  bool overlaps(UserScope other) =>
      entries.any((e) => other.entries.any(e.overlaps));

  /// Liest das Gebiet aus dem gespeicherten Wert der specificProperty.
  /// Ein Land kommt dabei höchstens einmal vor.
  factory UserScope.fromJson(dynamic raw) {
    if (raw is! List) return empty;
    final byCountry = <String, ScopeEntry>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final entry = ScopeEntry.fromJson(item);
      if (entry.country.isEmpty) continue;
      byCountry[entry.country] = entry;
    }
    return UserScope(byCountry.values.toList());
  }

  List<Map<String, dynamic>> toJson() =>
      entries.map((e) => e.toJson()).toList();

  /// Gebiet eines Nutzerobjekts.
  ///
  /// Ohne Zuweisung zählt das Land aus der Adresse: so finden Koordinatoren
  /// neue Nutzer, die sich selbst mit ihrem Land registriert haben, sowie die
  /// registrierten Farmer. [resolveCountry] bildet den gespeicherten Wert
  /// (Code oder früherer Name) auf den ISO-Code ab.
  factory UserScope.ofUser(
    Map<String, dynamic> user, {
    required String? Function(String? stored) resolveCountry,
  }) {
    final assigned = UserScope.fromJson(rawProperty(user, propertyKey));
    if (!assigned.isEmpty) return assigned;

    final stored =
        user['currentGeolocation']?['postalAddress']?['country']?.toString();
    final code = resolveCountry(stored);
    return code == null ? empty : UserScope([ScopeEntry(country: code)]);
  }

  /// Ob am Nutzerobjekt ausdrücklich ein Gebiet zugewiesen ist (und nicht
  /// nur das Land aus der Adresse gilt).
  static bool isAssigned(Map<String, dynamic> user) =>
      !UserScope.fromJson(rawProperty(user, propertyKey)).isEmpty;

  static String coordinatorOf(Map<String, dynamic> user) {
    final v = rawProperty(user, coordinatorKey);
    return v is String ? v : '';
  }

  /// Wie getSpecificPropertyfromJSON, aber ohne die Platzhalter-Strings und
  /// ohne Abhängigkeit vom openRAL-Service.
  static dynamic rawProperty(Map<String, dynamic> obj, String key) {
    final props = obj['specificProperties'];
    if (props is! List) return null;
    for (final p in props) {
      if (p is Map && (p['key'] == key || p['name'] == key)) return p['value'];
    }
    return null;
  }

  /// Kurzform für Listen, z.B. "KE: Nyeri, Kirinyaga · HN".
  String get label => entries
      .map((e) =>
          e.wholeCountry ? e.country : '${e.country}: ${e.regions.join(', ')}')
      .join(' · ');

  @override
  bool operator ==(Object other) =>
      other is UserScope &&
      other.entries.length == entries.length &&
      other.entries.toSet().containsAll(entries);

  @override
  int get hashCode => Object.hashAllUnordered(entries);
}

import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/models/country_config.dart';
import 'package:trace_foodchain_app/models/user_scope.dart';
import 'package:trace_foodchain_app/services/country_config_service.dart';
import '../l10n/app_localizations.dart';

/// Auswahl eines Gebiets: Länder, je Land optional einzelne Regionen.
///
/// Angeboten wird nur, was in [allowed] liegt - dem Gebiet des Bearbeiters.
/// [allowed] null heißt: alle aktiven Länder. Ist ein Land für den
/// Bearbeiter selbst auf Regionen beschränkt, muss mindestens eine davon
/// gewählt werden; das ganze Land kann er nicht vergeben.
class UserScopeEditor extends StatefulWidget {
  const UserScopeEditor({
    super.key,
    required this.initial,
    required this.allowed,
    required this.onChanged,
  });

  final UserScope initial;
  final UserScope? allowed;
  final ValueChanged<UserScope> onChanged;

  @override
  State<UserScopeEditor> createState() => _UserScopeEditorState();
}

class _UserScopeEditorState extends State<UserScopeEditor> {
  late List<ScopeEntry> _entries;

  @override
  void initState() {
    super.initState();
    // Was außerhalb des Erlaubten liegt, fällt weg; ganze Länder werden auf
    // die erlaubten Regionen eingeschränkt.
    _entries = [
      for (final e in widget.initial.entries)
        if (_allowedCountries.contains(e.country)) _normalize(e),
    ];
    // Der Aufrufer soll vom ersten Moment an den bereinigten Stand kennen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  List<String> get _allowedCountries {
    final active = countryConfigService.active.map((c) => c.code).toList();
    final allowed = widget.allowed;
    if (allowed == null) return active;
    return active.where(allowed.countries.contains).toList();
  }

  /// Regionen, die der Bearbeiter in [country] vergeben darf.
  List<String> _allowedRegions(String country) {
    final all = countryConfigService.byCode(country)?.regions ?? const [];
    final own = widget.allowed?.entryFor(country);
    if (own == null || own.wholeCountry) return all;
    return all.where(own.regions.contains).toList();
  }

  bool _wholeCountryAllowed(String country) {
    final own = widget.allowed?.entryFor(country);
    return own == null || own.wholeCountry;
  }

  ScopeEntry _normalize(ScopeEntry e) {
    final allowedRegions = _allowedRegions(e.country);
    final regions = e.regions.where(allowedRegions.contains).toList();
    if (regions.isEmpty && !_wholeCountryAllowed(e.country)) {
      return ScopeEntry(country: e.country, regions: allowedRegions);
    }
    return ScopeEntry(country: e.country, regions: regions);
  }

  void _emit() => widget.onChanged(UserScope(List.of(_entries)));

  void _update(void Function() change) {
    setState(change);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addable = _allowedCountries
        .where((c) => !_entries.any((e) => e.country == c))
        .toList();

    if (_allowedCountries.isEmpty) {
      return Text(l10n.scopeNoCountries,
          style: TextStyle(color: Colors.orange.shade800));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _entries.length; i++) _buildEntry(l10n, i),
        if (addable.isNotEmpty)
          PopupMenuButton<String>(
            onSelected: (code) => _update(
                () => _entries.add(_normalize(ScopeEntry(country: code)))),
            itemBuilder: (_) => [
              for (final code in addable)
                PopupMenuItem(
                  value: code,
                  child: Text(
                      _countryLabel(countryConfigService.byCode(code), code)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.addCountry,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEntry(AppLocalizations l10n, int index) {
    final entry = _entries[index];
    final regions = _allowedRegions(entry.country);
    final wholeAllowed = _wholeCountryAllowed(entry.country);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _countryLabel(countryConfigService.byCode(entry.country),
                        entry.country),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _update(() => _entries.removeAt(index)),
                ),
              ],
            ),
            if (regions.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final region in regions)
                    FilterChip(
                      label: Text(region),
                      selected: entry.regions.contains(region),
                      onSelected: (selected) => _update(() {
                        final next = List.of(entry.regions);
                        selected ? next.add(region) : next.remove(region);
                        _entries[index] =
                            ScopeEntry(country: entry.country, regions: next);
                      }),
                    ),
                ],
              ),
            if (regions.isNotEmpty) const SizedBox(height: 4),
            if (wholeAllowed)
              Text(
                entry.wholeCountry
                    ? l10n.scopeWholeCountry
                    : l10n.scopeWholeCountryHint,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (entry.wholeCountry)
              Text(l10n.scopeSelectRegion,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }

  String _countryLabel(CountryConfig? config, String code) =>
      config == null ? code : '${config.name} ($code)';
}

import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/models/country_config.dart';
import 'package:trace_foodchain_app/services/country_config_service.dart';
import 'package:trace_foodchain_app/services/permission_service.dart';
import '../l10n/app_localizations.dart';

/// Flagge aus dem ISO-Code (zwei Regional-Indicator-Zeichen).
String _flagOf(String code) => code.length != 2
    ? ''
    : String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

/// SUPERADMIN-Screen: Länder für die Registrierung anlegen und pflegen.
///
/// Länder werden nie gelöscht, nur deaktiviert - bestehende Registrierungen
/// verweisen weiter auf ihren Code.
class CountryManagementScreen extends StatefulWidget {
  const CountryManagementScreen({super.key});

  @override
  State<CountryManagementScreen> createState() =>
      _CountryManagementScreenState();
}

class _CountryManagementScreenState extends State<CountryManagementScreen> {
  bool _refreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    countryConfigService.addListener(_onCountriesChanged);
    // Direkt aus initState kein setState - die Felder werden nur gesetzt.
    _refreshing = true;
    unawaited(_refresh(fromInitState: true));
  }

  @override
  void dispose() {
    countryConfigService.removeListener(_onCountriesChanged);
    super.dispose();
  }

  void _onCountriesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh({bool fromInitState = false}) async {
    if (!fromInitState) setState(() => _refreshing = true);
    final ok = await countryConfigService.refreshFromCloud();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshFailed = !ok;
    });
  }

  void _addCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      exclude: countryConfigService.all.map((c) => c.code).toList(),
      onSelect: (Country country) {
        // Der Picker schließt sich erst nach onSelect - sofort gepusht würde
        // er stattdessen den Editor wieder schließen.
        Future.microtask(() => _openEditor(
              CountryConfig(
                code: country.countryCode,
                name: country.name,
                areaUnits: const [
                  {'name': 'hectares', 'symbol': 'ha', 'toHectareFactor': 1.0},
                ],
              ),
              isNew: true,
            ));
      },
    );
  }

  Future<void> _openEditor(CountryConfig country, {bool isNew = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CountryEditScreen(initial: country, isNew: isNew),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.countrySaved),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!PermissionService().hasPermission('manage_countries')) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.countryManagement)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.countryNoPermission, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final countries = countryConfigService.all;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.countryManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.countryReload,
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCountry,
        icon: const Icon(Icons.add),
        label: Text(l10n.addCountry),
      ),
      body: Column(
        children: [
          if (_refreshing) const LinearProgressIndicator(),
          if (_refreshFailed)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: Text(l10n.countryLoadFailed),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: countries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final country = countries[index];
                return _CountryTile(
                  country: country,
                  builtInOnly: countryConfigService.isBuiltInOnly(country.code),
                  onTap: () => _openEditor(country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.builtInOnly,
    required this.onTap,
  });

  final CountryConfig country;
  final bool builtInOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final units = country.areaUnits.map((u) => u['symbol']).join(', ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Text(_flagOf(country.code), style: const TextStyle(fontSize: 28)),
      title: Text('${country.name} (${country.code})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$units · ${l10n.countryRegionCount(country.regions.length)}'),
          if (builtInOnly)
            Text(
              l10n.countryBuiltInNotSaved,
              style: TextStyle(color: Colors.orange.shade800),
            ),
        ],
      ),
      trailing: Chip(
        label: Text(country.active ? l10n.countryActive : l10n.countryInactive),
        backgroundColor:
            country.active ? Colors.green.shade100 : Colors.grey.shade300,
      ),
      onTap: onTap,
    );
  }
}

/// Eine Zeile im Editor der Flächeneinheiten.
class _UnitRow {
  _UnitRow(Map<String, dynamic> unit)
      : name = TextEditingController(text: unit['name']?.toString() ?? ''),
        symbol = TextEditingController(text: unit['symbol']?.toString() ?? ''),
        factor = TextEditingController(
            text: unit['toHectareFactor']?.toString() ?? '');

  final TextEditingController name;
  final TextEditingController symbol;
  final TextEditingController factor;

  double? get factorValue =>
      double.tryParse(factor.text.trim().replaceAll(',', '.'));

  Map<String, dynamic> toUnit() => {
        'name': name.text.trim(),
        'symbol': symbol.text.trim(),
        'toHectareFactor': factorValue ?? 1.0,
      };

  void dispose() {
    name.dispose();
    symbol.dispose();
    factor.dispose();
  }
}

class CountryEditScreen extends StatefulWidget {
  const CountryEditScreen({
    super.key,
    required this.initial,
    this.isNew = false,
  });

  final CountryConfig initial;
  final bool isNew;

  @override
  State<CountryEditScreen> createState() => _CountryEditScreenState();
}

class _CountryEditScreenState extends State<CountryEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _legacyNames;
  late final TextEditingController _regions;
  late final TextEditingController _whispCode;
  late final List<TextEditingController> _regionLabels;
  late final List<_UnitRow> _units;

  late bool _active;
  late String _defaultUnit;
  late String _producerRegistry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c.name);
    _legacyNames = TextEditingController(text: c.legacyNames.join(', '));
    _regions = TextEditingController(text: c.regions.join('\n'));
    _whispCode = TextEditingController(text: c.whispNationalCode);
    _regionLabels = List.generate(
      CountryConfig.maxRegionLevels,
      (i) => TextEditingController(
          text: i < c.regionLabels.length ? c.regionLabels[i] : ''),
    );
    _units = c.areaUnits.map(_UnitRow.new).toList();
    _active = c.active;
    _defaultUnit = c.defaultAreaUnit;
    _producerRegistry = c.producerRegistry;
  }

  @override
  void dispose() {
    _name.dispose();
    _legacyNames.dispose();
    _regions.dispose();
    _whispCode.dispose();
    for (final c in _regionLabels) {
      c.dispose();
    }
    for (final u in _units) {
      u.dispose();
    }
    super.dispose();
  }

  /// Eindeutige, nicht leere Symbole - in Reihenfolge der Zeilen.
  List<String> get _symbols => _units
      .map((u) => u.symbol.text.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  String? get _effectiveDefaultUnit {
    final symbols = _symbols;
    if (symbols.contains(_defaultUnit)) return _defaultUnit;
    return symbols.isNotEmpty ? symbols.first : null;
  }

  static List<String> _uniqueList(Iterable<String> values) {
    final seen = <String>{};
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && seen.add(v))
        .toList();
  }

  CountryConfig _buildConfig() {
    final labels = _regionLabels.map((c) => c.text.trim()).toList();
    while (labels.isNotEmpty && labels.last.isEmpty) {
      labels.removeLast();
    }

    return widget.initial.copyWith(
      name: _name.text.trim(),
      active: _active,
      legacyNames: _uniqueList(_legacyNames.text.split(',')),
      areaUnits: _units.map((u) => u.toUnit()).toList(),
      defaultAreaUnit: _effectiveDefaultUnit ?? 'ha',
      regionLabels: labels,
      regions: _uniqueList(_regions.text.split('\n')),
      whispNationalCode: _whispCode.text.trim(),
      producerRegistry: _producerRegistry,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (_units.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.countryAtLeastOneUnit)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await countryConfigService.save(_buildConfig());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = switch (e) {
        CountryConfigOfflineException() => l10n.countryOnlineOnly,
        CountryConfigPermissionException() => l10n.countryNoPermission,
        _ => l10n.countrySaveFailed(e.toString()),
      };
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.initial;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l10n.addCountry : l10n.editCountry),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: l10n.save,
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: [
            Row(
              children: [
                Text(_flagOf(c.code), style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Text('${l10n.countryCode}: ${c.code}',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.countryName),
              validator: _required(l10n),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_active ? l10n.countryActive : l10n.countryInactive),
              subtitle: Text(l10n.countryActiveHint),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            TextFormField(
              controller: _legacyNames,
              decoration: InputDecoration(
                labelText: l10n.countryLegacyNames,
                helperText: l10n.countryLegacyNamesHelp,
                helperMaxLines: 3,
              ),
            ),
            _SectionTitle(l10n.countryAreaUnits),
            for (final unit in _units) _buildUnitRow(l10n, unit),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.countryAddAreaUnit),
                onPressed: () => setState(() => _units.add(_UnitRow(const {}))),
              ),
            ),
            if (_symbols.isNotEmpty)
              DropdownButtonFormField<String>(
                // Neu aufbauen, sobald sich die Symbole ändern - sonst hält
                // das Feld einen Wert, den es nicht mehr gibt.
                key: ValueKey(_symbols.join('|')),
                initialValue: _effectiveDefaultUnit,
                decoration:
                    InputDecoration(labelText: l10n.countryDefaultAreaUnit),
                items: [
                  for (final s in _symbols)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _defaultUnit = v ?? 'ha'),
              ),
            _SectionTitle(l10n.countryRegionsSection),
            for (int i = 0; i < _regionLabels.length; i++)
              TextFormField(
                controller: _regionLabels[i],
                decoration: InputDecoration(
                  labelText: l10n.countryRegionLevelLabel(i + 1),
                  helperText: i == 0 ? l10n.countryRegionLevelHelp : null,
                ),
                // Keine Lücken: eine untere Ebene braucht alle darüber.
                validator: (value) {
                  final empty = value == null || value.trim().isEmpty;
                  final lowerFilled = _regionLabels
                      .skip(i + 1)
                      .any((c) => c.text.trim().isNotEmpty);
                  return empty && lowerFilled ? l10n.countryFieldRequired : null;
                },
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regions,
              minLines: 4,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: l10n.countryRegionList,
                helperText: l10n.countryRegionListHelp,
                helperMaxLines: 2,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            _SectionTitle(l10n.countryIntegrations),
            TextFormField(
              controller: _whispCode,
              decoration: InputDecoration(
                labelText: l10n.countryWhispCode,
                helperText: l10n.countryWhispCodeHelp,
                helperMaxLines: 2,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                return v.isEmpty || RegExp(r'^[a-z]{2}$').hasMatch(v)
                    ? null
                    : l10n.countryInvalidWhispCode;
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _producerRegistry,
              decoration:
                  InputDecoration(labelText: l10n.countryProducerRegistry),
              items: [
                DropdownMenuItem(
                  value: CountryConfig.producerRegistryNone,
                  child: Text(l10n.countryProducerRegistryNone),
                ),
                DropdownMenuItem(
                  value: CountryConfig.producerRegistryIhcafe,
                  child: Text(l10n.countryProducerRegistryIhcafe),
                ),
              ],
              onChanged: (v) => setState(() =>
                  _producerRegistry = v ?? CountryConfig.producerRegistryNone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow(AppLocalizations l10n, _UnitRow unit) {
    return Padding(
      key: ObjectKey(unit),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: unit.name,
              decoration: InputDecoration(
                  labelText: l10n.countryAreaUnitName, isDense: true),
              validator: _required(l10n),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: unit.symbol,
              decoration: InputDecoration(
                  labelText: l10n.countryAreaUnitSymbol, isDense: true),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return l10n.countryFieldRequired;
                final uses =
                    _units.where((u) => u.symbol.text.trim() == v).length;
                return uses > 1 ? l10n.countryDuplicateSymbol : null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: unit.factor,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: l10n.countryAreaUnitFactor, isDense: true),
              validator: (_) {
                final f = unit.factorValue;
                return f == null || f <= 0 ? l10n.countryInvalidFactor : null;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => _units.remove(unit));
              // Erst nach dem Frame freigeben - bis dahin hängen die Felder
              // der Zeile noch an den Controllern.
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => unit.dispose());
            },
          ),
        ],
      ),
    );
  }

  FormFieldValidator<String> _required(AppLocalizations l10n) =>
      (value) => (value == null || value.trim().isEmpty)
          ? l10n.countryFieldRequired
          : null;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

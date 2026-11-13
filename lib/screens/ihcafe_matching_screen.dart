import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/l10n/app_localizations.dart';
import 'package:trace_foodchain_app/services/ihcafe_export_reader.dart';
import 'package:trace_foodchain_app/services/ihcafe_farm_matching.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';
import 'package:trace_foodchain_app/services/ihcafe_qc_farm_loader.dart';
import 'package:trace_foodchain_app/utils/file_download.dart';
import 'package:trace_foodchain_app/widgets/ihcafe_producer_widgets.dart';

/// Experimentell: QC-geprüfte Farmen mit dem IHCafe-Export abgleichen und die
/// IHCafe-Kennungen als alternateIDs setzen.
///
/// Der Export wird hier nur in den Speicher geladen (nicht in Hive) und ist
/// beim Verlassen der Ansicht wieder weg. Standard ist der Probelauf: er
/// schreibt nichts und protokolliert jede Entscheidung im Log.

/// Liest und parst die Datei - als Top-Level-Funktion, damit sie per
/// [compute] in einem eigenen Isolate laufen kann (im Web läuft sie inline).
({List<IhcafeProducer> producers, IhcafeCatalogMeta meta, String source})
    _parseExportFile(({List<int> bytes, String name}) input) {
  final file = readIhcafeExportFile(input.bytes, input.name);
  final parsed = parseIhcafeExport(file.json);
  return (producers: parsed.producers, meta: parsed.meta, source: file.sourceName);
}

class _LogLine {
  final DateTime at;
  final String text;
  final Color? color;
  _LogLine(this.text, [this.color]) : at = DateTime.now();
}

Color levelColor(IhcafeLinkLevel level) => switch (level) {
      IhcafeLinkLevel.alreadyLinked => Colors.blueGrey,
      IhcafeLinkLevel.dni => Colors.green.shade800,
      IhcafeLinkLevel.nameMunicipio => Colors.green.shade600,
      IhcafeLinkLevel.nameFuzzy => Colors.lime.shade800,
      IhcafeLinkLevel.dniNameMismatch => Colors.orange.shade800,
      IhcafeLinkLevel.nameOnly => Colors.orange.shade600,
      IhcafeLinkLevel.conflict => Colors.red.shade700,
      IhcafeLinkLevel.duplicate => Colors.red.shade400,
      IhcafeLinkLevel.ambiguous => Colors.purple.shade400,
      IhcafeLinkLevel.outOfScope => Colors.grey.shade600,
      IhcafeLinkLevel.none => Colors.grey.shade800,
    };

String levelLabel(AppLocalizations l10n, IhcafeLinkLevel level) =>
    switch (level) {
      IhcafeLinkLevel.alreadyLinked => l10n.ihmLevelAlreadyLinked,
      IhcafeLinkLevel.dni => l10n.ihmLevelDni,
      IhcafeLinkLevel.dniNameMismatch => l10n.ihmLevelDniNameMismatch,
      IhcafeLinkLevel.nameMunicipio => l10n.ihmLevelNameMunicipio,
      IhcafeLinkLevel.nameFuzzy => l10n.ihmLevelNameFuzzy,
      IhcafeLinkLevel.nameOnly => l10n.ihmLevelNameOnly,
      IhcafeLinkLevel.conflict => l10n.ihmLevelConflict,
      IhcafeLinkLevel.ambiguous => l10n.ihmLevelAmbiguous,
      IhcafeLinkLevel.duplicate => l10n.ihmLevelDuplicate,
      IhcafeLinkLevel.outOfScope => l10n.ihmLevelOutOfScope,
      IhcafeLinkLevel.none => l10n.ihmLevelNone,
    };

class IhcafeMatchingScreen extends StatefulWidget {
  const IhcafeMatchingScreen({super.key});

  @override
  State<IhcafeMatchingScreen> createState() => _IhcafeMatchingScreenState();
}

class _IhcafeMatchingScreenState extends State<IhcafeMatchingScreen> {
  IhcafeCatalog? _catalog;
  String _sourceLabel = '';
  bool _sourceInMemory = false;
  IhcafeFarmMatcher? _matcher;

  List<QcFarmRecord> _records = const [];
  List<IhcafeFarmMatch> _results = const [];

  final List<_LogLine> _log = [];
  final ScrollController _logScroll = ScrollController();

  String? _busy;
  bool _cancelRequested = false;
  bool _dryRun = true;
  final Set<IhcafeLinkLevel> _applyLevels = {...defaultApplyLevels};
  IhcafeLinkLevel? _filter;

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  // ── Log ────────────────────────────────────────────────────────────────

  void _write(String text, [Color? color]) {
    debugPrint('IHCafe matching: $text');
    if (!mounted) return;
    final atBottom = !_logScroll.hasClients ||
        _logScroll.position.pixels >= _logScroll.position.maxScrollExtent - 40;
    setState(() => _log.add(_LogLine(text, color)));
    if (atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) {
          _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
        }
      });
    }
  }

  void _section(String title) => _write('── $title ──', Colors.blue.shade800);

  Future<void> _guard(String label, Future<void> Function() body) async {
    setState(() {
      _busy = label;
      _cancelRequested = false;
    });
    try {
      await body();
    } catch (e, st) {
      _write('ERROR: $e', Colors.red);
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ── 1. Export ──────────────────────────────────────────────────────────

  Future<void> _loadFile() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.pickFiles(
      withReadStream: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    if (picked == null) return;
    final file = picked.files.first;

    await _guard(l10n.ihmLoadFile, () async {
      _section('Export');
      _write('Reading ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(1)} MB) ...');
      final bytes = await readPickedFileBytes(file);
      _write('Parsing ...');
      final sw = Stopwatch()..start();
      final parsed =
          await compute(_parseExportFile, (bytes: bytes, name: file.name));
      _setCatalog(IhcafeCatalog(parsed.producers, parsed.meta), parsed.source,
          inMemory: true, ms: sw.elapsedMilliseconds);
    });
  }

  Future<void> _useStored() async {
    final l10n = AppLocalizations.of(context)!;
    await _guard(l10n.ihmUseStored, () async {
      _section('Export');
      final catalog = await IhcafeProducerService.instance.load();
      if (catalog == null) {
        _write('No IHCafé directory stored on this device.', Colors.orange);
        return;
      }
      _setCatalog(catalog, 'stored directory', inMemory: false);
    });
  }

  void _setCatalog(IhcafeCatalog catalog, String source,
      {required bool inMemory, int? ms}) {
    final m = catalog.meta;
    final sw = Stopwatch()..start();
    final matcher = IhcafeFarmMatcher(catalog);
    setState(() {
      _catalog = catalog;
      _sourceLabel = source;
      _sourceInMemory = inMemory;
      _matcher = matcher;
      _results = const [];
    });
    _write('Loaded $source${ms != null ? ' in $ms ms' : ''}: '
        '${catalog.producers.length} producers, '
        '${catalog.producers.where((p) => p.esVigente).length} vigente', Colors.green.shade800);
    _write('  contract ${m.contract.isEmpty ? '-' : m.contract}, project '
        '${m.proyectoUid.isEmpty ? '-' : m.proyectoUid}, departamento '
        '${m.scopeDepartamento.isEmpty ? '-' : m.scopeDepartamento}, exported '
        '${m.exportedAt.isEmpty ? '-' : m.exportedAt}');
    _write('  municipios: ${catalog.municipios.join(', ')}');
    _write('  index built in ${sw.elapsedMilliseconds} ms; '
        '${matcher.duplicateDnis.length} DNI value(s) occur more than once '
        'and are ignored for DNI matching');
  }

  // ── 2. Farmen ──────────────────────────────────────────────────────────

  Future<void> _loadFarms() async {
    final l10n = AppLocalizations.of(context)!;
    await _guard(l10n.ihmLoadFarms, () async {
      _section('QC-approved farms');
      final records = await loadQcApprovedFarms(
        log: _write,
        cancelled: () => _cancelRequested,
      );
      final withDni = records.where((r) => r.match.nationalId.isNotEmpty).length;
      final linked =
          records.where((r) => r.match.farmerIhcafeIds.isNotEmpty).length;
      _write('  with national ID: $withDni, farmer already with IHCafe id: '
          '$linked');
      setState(() {
        _records = records;
        _results = const [];
      });
    });
  }

  // ── 3. Matching ────────────────────────────────────────────────────────

  Future<void> _runMatching() async {
    final l10n = AppLocalizations.of(context)!;
    final matcher = _matcher;
    if (matcher == null || _records.isEmpty) return;

    await _guard(l10n.ihmRunMatching, () async {
      _section('Matching ${_records.length} farms (dry run - nothing is written)');
      final sw = Stopwatch()..start();
      final results = <IhcafeFarmMatch>[];
      for (var i = 0; i < _records.length; i++) {
        if (_cancelRequested) {
          _write('Cancelled after $i farms.', Colors.orange);
          break;
        }
        final r = matcher.matchOne(_records[i].match);
        results.add(r);
        _logMatch(i + 1, r);
        // Der UI Luft lassen, damit das Log mitläuft.
        if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
      }

      _section('Collisions');
      final before = {for (final r in results) r: r.level};
      resolveCollisions(results);
      var changed = 0;
      for (final r in results) {
        if (before[r] != r.level || r.reasons.last.startsWith('finca_id ')) {
          changed++;
          _write('${r.farm.farmerName}: ${r.reasons.last}', levelColor(r.level));
        }
      }
      if (changed == 0) _write('none');

      setState(() => _results = results);
      _logSummary(sw.elapsedMilliseconds);
    });
  }

  void _logMatch(int n, IhcafeFarmMatch r) {
    final p = r.producer;
    _write(
      '#$n [${r.level.name}] ${r.farm.farmerName}'
      '${p != null ? '  ->  ${p.nombreCompleto} (${p.clave})' : ''}'
      '${r.hasChanges ? '  +${r.farmerAdds.length + r.farmAdds.length} id(s)' : ''}',
      levelColor(r.level),
    );
    for (final reason in r.reasons) {
      _write('     $reason');
    }
  }

  void _logSummary(int ms) {
    _section('Summary');
    for (final level in IhcafeLinkLevel.values) {
      final n = _results.where((r) => r.level == level).length;
      if (n > 0) _write('${level.name.padRight(16)} $n', levelColor(level));
    }
    final apply = _results.where((r) => r.isApplicable(_applyLevels)).toList();
    final farmerIds = apply.fold<int>(0, (s, r) => s + r.farmerAdds.length);
    final farmIds = apply.fold<int>(0, (s, r) => s + r.farmAdds.length);
    _write('With the selected levels (${_applyLevels.map((l) => l.name).join(', ')}) '
        '${apply.length} match(es) would write $farmerIds farmer id(s) and '
        '$farmIds finca_id(s). Done in $ms ms.', Colors.blue.shade800);
  }

  // ── 4. Schreiben ───────────────────────────────────────────────────────

  List<IhcafeFarmMatch> get _toApply =>
      _results.where((r) => r.isApplicable(_applyLevels)).toList();

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    final catalog = _catalog;
    final matches = _toApply;
    if (catalog == null || matches.isEmpty || _dryRun) return;

    final objects = {
      for (final m in matches) ...[
        if (m.farmerAdds.isNotEmpty && m.farm.farmerUid != null)
          m.farm.farmerUid!,
        if (m.farmAdds.isNotEmpty) m.farm.farmUid,
      ]
    }.length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.ihmApplyConfirmTitle,
            style: const TextStyle(color: Colors.black87)),
        content: Text(l10n.ihmApplyConfirmBody(matches.length, objects),
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.ihmApply(matches.length))),
        ],
      ),
    );
    if (ok != true) return;

    await _guard(l10n.ihmApply(matches.length), () async {
      _section('WRITING ${matches.length} matches');
      final result = await applyIhcafeMatches(
        matches: matches,
        catalogMeta: catalog.meta,
        log: _write,
        cancelled: () => _cancelRequested,
      );
      _write('Written: ${result.written} object(s), failed: ${result.failed}. '
          'Reload the farms and run again to verify.',
          result.failed == 0 ? Colors.green.shade800 : Colors.red);
      setState(() {
        _results = const [];
        _dryRun = true;
      });
    });
  }

  // ── Export ─────────────────────────────────────────────────────────────

  String _stamp() =>
      DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');

  Future<void> _exportLog() async {
    final text = _log
        .map((l) => '${l.at.toIso8601String().substring(11, 19)}  ${l.text}')
        .join('\n');
    await downloadFile(utf8.encode(text), 'ihcafe_matching_log_${_stamp()}.txt');
  }

  Future<void> _exportCsv() async {
    String q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final header = [
      'level', 'originalLevel', 'willWrite', 'farmUid', 'farmName',
      'farmerUid', 'farmerName', 'nationalId', 'municipio', 'departamento',
      'aldea', 'producer', 'clave', 'productorId', 'identidad', 'vigente',
      'fincaId', 'nameScore', 'farmerAdds', 'farmAdds', 'candidates',
      'bestGuess', 'reasons',
    ];
    final rows = <String>[header.map(q).join(',')];
    for (final r in _results) {
      final p = r.producer;
      rows.add([
        r.level.name,
        r.originalLevel?.name,
        r.isApplicable(_applyLevels),
        r.farm.farmUid,
        r.farm.farmName,
        r.farm.farmerUid,
        r.farm.farmerName,
        r.farm.nationalId,
        r.farm.municipio,
        r.farm.departamento,
        r.farm.aldea,
        p?.nombreCompleto,
        p?.clave,
        p?.productorId,
        p?.identidad,
        p?.esVigente,
        r.finca?.fincaId,
        (r.nameScore * 100).round(),
        r.farmerAdds.map((a) => '${a.label}=${a.uid}').join(' '),
        r.farmAdds.map((a) => '${a.label}=${a.uid}').join(' '),
        r.candidates.map((c) => '${c.nombreCompleto} (${c.clave})').join(' | '),
        r.bestGuess == null
            ? ''
            : '${r.bestGuess!.nombreCompleto} (${r.bestGuess!.clave}) '
                '${(r.bestGuessScore * 100).round()}%',
        r.reasons.join(' | '),
      ].map(q).join(','));
    }
    // BOM, damit Excel die Umlaute/Akzente richtig liest.
    await downloadFile([0xEF, 0xBB, 0xBF, ...utf8.encode(rows.join('\r\n'))],
        'ihcafe_matching_${_stamp()}.csv');
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _busy != null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.science_outlined),
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.ihmTitle, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.ihmExportLog,
              icon: const Icon(Icons.description_outlined),
              onPressed: _log.isEmpty ? null : _exportLog,
            ),
            IconButton(
              tooltip: l10n.ihmExportCsv,
              icon: const Icon(Icons.table_view_outlined),
              onPressed: _results.isEmpty ? null : _exportCsv,
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: '${l10n.ihmTabLog} (${_log.length})'),
            Tab(text: '${l10n.ihmTabResults} (${_results.length})'),
          ]),
        ),
        body: Column(
          children: [
            _buildControls(l10n, busy),
            if (busy)
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(_busy!,
                            style: const TextStyle(color: Colors.black87))),
                    TextButton(
                      onPressed: _cancelRequested
                          ? null
                          : () => setState(() => _cancelRequested = true),
                      child: Text(l10n.ihmStop),
                    ),
                  ],
                ),
              ),
            if (_results.isNotEmpty) _buildSummaryChips(l10n),
            Expanded(
              child: TabBarView(children: [
                _buildLog(l10n),
                _buildResults(l10n),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(AppLocalizations l10n, bool busy) {
    final catalog = _catalog;
    final toApply = _toApply;

    Widget step(String title, String status, List<Widget> actions,
            {bool done = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: done ? Colors.green : Colors.grey),
              SizedBox(
                width: 190,
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
              ...actions,
              Text(status,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ihmIntro,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            step(
              l10n.ihmStepSource,
              catalog == null
                  ? l10n.ihmSourceNone
                  : '${l10n.ihmSourceLoaded(catalog.producers.length, _sourceLabel)}'
                      '${_sourceInMemory ? ' · ${l10n.ihmInMemoryOnly}' : ''}',
              [
                OutlinedButton.icon(
                  onPressed: busy ? null : _loadFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(l10n.ihmLoadFile),
                ),
                TextButton(
                  onPressed: busy ? null : _useStored,
                  child: Text(l10n.ihmUseStored),
                ),
              ],
              done: catalog != null,
            ),
            step(
              l10n.ihmStepFarms,
              _records.isEmpty ? '' : l10n.ihmFarmsLoaded(_records.length),
              [
                OutlinedButton.icon(
                  onPressed: busy ? null : _loadFarms,
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text(l10n.ihmLoadFarms),
                ),
              ],
              done: _records.isNotEmpty,
            ),
            step(
              l10n.ihmStepRun,
              '',
              [
                ElevatedButton.icon(
                  onPressed: busy || catalog == null || _records.isEmpty
                      ? null
                      : _runMatching,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.ihmRunMatching),
                ),
              ],
              done: _results.isNotEmpty,
            ),
            if (_results.isNotEmpty) ...[
              const Divider(),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(l10n.ihmApplyLevels,
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  for (final level in applicableLevels)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(levelLabel(l10n, level),
                          style: const TextStyle(fontSize: 12)),
                      selected: _applyLevels.contains(level),
                      selectedColor: levelColor(level).withValues(alpha: 0.2),
                      onSelected: busy
                          ? null
                          : (v) => setState(() => v
                              ? _applyLevels.add(level)
                              : _applyLevels.remove(level)),
                    ),
                ],
              ),
              Row(
                children: [
                  Switch(
                    value: _dryRun,
                    onChanged: busy ? null : (v) => setState(() => _dryRun = v),
                  ),
                  Flexible(
                    child: Text(l10n.ihmDryRun,
                        style: const TextStyle(color: Colors.black87)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed:
                        busy || _dryRun || toApply.isEmpty ? null : _apply,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(l10n.ihmApply(toApply.length)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChips(AppLocalizations l10n) {
    final counts = <IhcafeLinkLevel, int>{};
    for (final r in _results) {
      counts[r.level] = (counts[r.level] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: Text('${l10n.ihmAllLevels} (${_results.length})',
                style: const TextStyle(fontSize: 12)),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          for (final level in IhcafeLinkLevel.values)
            if ((counts[level] ?? 0) > 0)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: CircleAvatar(backgroundColor: levelColor(level), radius: 5),
                label: Text('${levelLabel(l10n, level)} (${counts[level]})',
                    style: const TextStyle(fontSize: 12)),
                selected: _filter == level,
                onSelected: (_) =>
                    setState(() => _filter = _filter == level ? null : level),
              ),
        ],
      ),
    );
  }

  Widget _buildLog(AppLocalizations l10n) {
    if (_log.isEmpty) {
      return Center(
          child: Text(l10n.ihmNoResults,
              style: TextStyle(color: Colors.grey.shade600)));
    }
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SelectionArea(
        child: ListView.builder(
          controller: _logScroll,
          padding: const EdgeInsets.all(8),
          itemCount: _log.length,
          itemBuilder: (_, i) {
            final line = _log[i];
            final color = line.color;
            return Text(
              '${line.at.toIso8601String().substring(11, 19)}  ${line.text}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.3,
                // Farben für dunklen Hintergrund aufhellen.
                color: color == null
                    ? Colors.grey.shade300
                    : Color.lerp(color, Colors.white, 0.35),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    final list = _filter == null
        ? _results
        : _results.where((r) => r.level == _filter).toList();
    if (list.isEmpty) {
      return Center(
          child: Text(l10n.ihmNoResults,
              style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = list[i];
        final p = r.producer;
        final willWrite = r.isApplicable(_applyLevels);
        final subtitle = p != null
            ? '${p.nombreCompleto} · ${p.clave} · ${p.identidad}'
                '${r.finca != null ? ' · finca ${r.finca!.fincaId}' : ''}'
            : r.candidates.isNotEmpty
                ? r.candidates.map((c) => c.nombreCompleto).join(' | ')
                : (r.bestGuess != null
                    ? '≈ ${r.bestGuess!.nombreCompleto} '
                        '(${(r.bestGuessScore * 100).round()}%)'
                    : '');
        return ExpansionTile(
          key: PageStorageKey(r.farm.farmUid),
          leading: Container(
            width: 10,
            height: 36,
            decoration: BoxDecoration(
              color: levelColor(r.level),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          title: Text(
            '${r.farm.farmerName}'
            '${r.farm.municipio.isNotEmpty ? ' · ${r.farm.municipio}' : ''}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          subtitle: Text(
            '${levelLabel(l10n, r.level)}'
            '${r.originalLevel != null ? ' (${levelLabel(l10n, r.originalLevel!)})' : ''}'
            '${subtitle.isNotEmpty ? ' — $subtitle' : ''}',
            style: TextStyle(fontSize: 12, color: levelColor(r.level)),
          ),
          trailing: Text(
            willWrite
                ? '${l10n.ihmWillWrite} '
                    '+${r.farmerAdds.length + r.farmAdds.length}'
                : l10n.ihmNothingToWrite,
            style: TextStyle(
                fontSize: 11,
                color: willWrite ? Colors.green.shade800 : Colors.grey),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(32, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              [
                'farm ${r.farm.farmUid}  "${r.farm.farmName}"',
                'farmer ${r.farm.farmerUid ?? '-'}',
                ...r.reasons,
                if (r.farmerAdds.isNotEmpty)
                  'farmer += ${r.farmerAdds.map((a) => '${a.label}=${a.uid}').join(', ')}',
                if (r.farmAdds.isNotEmpty)
                  'farm   += ${r.farmAdds.map((a) => '${a.label}=${a.uid}').join(', ')}',
              ].join('\n'),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
            ),
          ],
        );
      },
    );
  }
}

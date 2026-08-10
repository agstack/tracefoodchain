import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/l10n/app_localizations.dart';
import 'package:trace_foodchain_app/services/ihcafe_producer_service.dart';

/// UI-Bausteine für das IHCafe-Produzentenverzeichnis (lokalisiert).
///
/// Beide Bausteine werden ausschließlich im Registrar- und im
/// Fast-Upload-Workflow eingebunden. Im Farmer-/Buyer-Workflow werden sie
/// bewusst nicht angeboten, damit dort kein Speicher belegt wird.

/// Statuskarte: zeigt ob das Verzeichnis lokal vorliegt und erlaubt Import
/// bzw. Löschen.
///
/// Solange nichts importiert ist, weist die Karte darauf hin, dass die Datei
/// im Online-Zustand beschafft werden muss - offline ist danach alles nutzbar.
class IhcafeCatalogCard extends StatefulWidget {
  /// Wird nach erfolgreichem Import oder Löschen aufgerufen.
  final VoidCallback? onChanged;

  /// Kompakte Darstellung ohne Card-Rahmen, z.B. innerhalb eines Steppers.
  final bool dense;

  const IhcafeCatalogCard({super.key, this.onChanged, this.dense = false});

  @override
  State<IhcafeCatalogCard> createState() => _IhcafeCatalogCardState();
}

class _IhcafeCatalogCardState extends State<IhcafeCatalogCard> {
  final _service = IhcafeProducerService.instance;

  IhcafeCatalogMeta? _meta;
  int _sizeBytes = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final meta = await _service.readMeta();
    final size = await _service.storedSizeBytes();
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _sizeBytes = size;
      _loading = false;
    });
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        withReadStream: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) {
        setState(() => _busy = false);
        return;
      }

      final file = result.files.first;
      final bytes = <int>[];
      if (kIsWeb) {
        await file.readStream
            ?.listen((chunk) => bytes.addAll(chunk))
            .asFuture();
      } else {
        bytes.addAll(await File(file.path!).readAsBytes());
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final meta = await _service.importExport(content);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _busy = false;
      });
      await _refresh();
      widget.onChanged?.call();
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.ihcafeDeleteTitle),
        content: Text(l10n.ihcafeDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _service.clear();
    await _refresh();
    widget.onChanged?.call();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final available = _meta != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              available ? Icons.cloud_done : Icons.cloud_download_outlined,
              color: available ? Colors.green[700] : Colors.orange[800],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.ihcafeDirectoryTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!available) ...[
          Text(
            l10n.ihcafeNotAvailable,
            style: TextStyle(color: Colors.grey[800], fontSize: 13),
          ),
        ] else ...[
          _MetaLine(l10n.ihcafeProducersLabel, '${_meta!.recordCount}'),
          if (_meta!.scopeDepartamento.isNotEmpty)
            _MetaLine(l10n.ihcafeDepartamentoLabel, _meta!.scopeDepartamento),
          if (_meta!.proyectoUid.isNotEmpty)
            _MetaLine(l10n.ihcafeProjectLabel, _meta!.proyectoUid),
          if (_meta!.exportedAt.isNotEmpty)
            _MetaLine(
                l10n.ihcafeExportedLabel, _meta!.exportedAt.split('T').first),
          _MetaLine(
              l10n.ihcafeImportedLabel, _meta!.importedAt.split('T').first),
          _MetaLine(l10n.ihcafeStoredSizeLabel, _formatSize(_sizeBytes)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _import,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(available
                  ? l10n.ihcafeReplaceFile
                  : l10n.ihcafeImportFile),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue[700],
              ),
            ),
            if (available) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                label: Text(l10n.delete,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ],
    );

    if (widget.dense) return content;
    return Card(
      elevation: 4,
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;
  const _MetaLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Öffnet die Produzentensuche und liefert die Auswahl zurück (oder null).
///
/// Gibt null zurück und zeigt einen Hinweis, wenn noch kein Verzeichnis
/// importiert wurde.
Future<IhcafeProducer?> showIhcafeProducerPicker(BuildContext context) async {
  final catalog = await IhcafeProducerService.instance.load();
  if (!context.mounted) return null;

  final l10n = AppLocalizations.of(context)!;

  if (catalog == null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.ihcafeMissingTitle),
        content: Text(l10n.ihcafeMissingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    return null;
  }

  return showDialog<IhcafeProducer>(
    context: context,
    builder: (_) => _ProducerPickerDialog(catalog: catalog),
  );
}

/// Lässt den Registrar eine Finca auswählen, wenn der Produzent mehrere hat.
///
/// Die finca_id wird als alternateID an der Farm abgelegt, daher muss sie
/// eindeutig sein. Bei genau einer Finca wird ohne Rückfrage diese genommen.
Future<IhcafeFinca?> pickIhcafeFinca(
    BuildContext context, IhcafeProducer producer) async {
  if (producer.fincas.isEmpty) return null;
  if (producer.fincas.length == 1) return producer.fincas.first;

  final l10n = AppLocalizations.of(context)!;
  return showDialog<IhcafeFinca>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(l10n.ihcafeWhichFincaTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ihcafeWhichFincaBody(
                  producer.nombreCompleto, producer.fincas.length),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: producer.fincas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final f = producer.fincas[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      f.nombreFinca?.isNotEmpty == true
                          ? f.nombreFinca!
                          : l10n.ihcafeFincaLabel('${f.fincaId ?? '?'}'),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    subtitle: Text(
                      [
                        f.locationLabel,
                        if ((f.aldea ?? '').isNotEmpty) f.aldea!,
                        if (f.fincaId != null)
                          l10n.ihcafeFincaLabel('${f.fincaId}'),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(ctx, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.ihcafeSkip),
        ),
      ],
    ),
  );
}

class _ProducerPickerDialog extends StatefulWidget {
  final IhcafeCatalog catalog;
  const _ProducerPickerDialog({required this.catalog});

  @override
  State<_ProducerPickerDialog> createState() => _ProducerPickerDialogState();
}

class _ProducerPickerDialogState extends State<_ProducerPickerDialog> {
  final _controller = TextEditingController();
  List<IhcafeProducer> _results = const [];
  bool _onlyVigente = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    // Die Suche läuft linear über bis zu 31k Einträge. Ab zwei Zeichen ist die
    // Trefferliste klein genug, darunter lohnt sich der Durchlauf nicht.
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    var hits = widget.catalog.search(query, limit: 60);
    if (_onlyVigente) {
      hits = hits.where((p) => p.esVigente).toList();
    }
    setState(() => _results = hits);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.ihcafeSelectProducerTitle,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                '${l10n.ihcafeProducerCount(widget.catalog.meta.recordCount)}'
                '${widget.catalog.meta.scopeDepartamento.isNotEmpty ? ' · ${widget.catalog.meta.scopeDepartamento}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.ihcafeSearchLabel,
                  hintText: l10n.ihcafeSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _runSearch,
              ),
              Row(
                children: [
                  Checkbox(
                    value: _onlyVigente,
                    onChanged: (v) {
                      setState(() => _onlyVigente = v ?? false);
                      _runSearch(_controller.text);
                    },
                  ),
                  Text(l10n.ihcafeOnlyVigente,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87)),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _controller.text.trim().length < 2
                                ? l10n.ihcafeTypeToSearch
                                : l10n.ihcafeNoProducerFound,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.nombreCompleto,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                            subtitle: Text(
                              [
                                if (p.identidad.isNotEmpty) p.identidad,
                                if (p.locationLabel.isNotEmpty) p.locationLabel,
                                if (p.clave.isNotEmpty)
                                  l10n.ihcafeClaveLabel(p.clave),
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: p.esVigente
                                ? const Icon(Icons.verified,
                                    color: Colors.green, size: 18)
                                : Icon(Icons.remove_circle_outline,
                                    color: Colors.grey[400], size: 18),
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

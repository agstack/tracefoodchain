// UI for the upload pause switch and the manual sync trigger (WP A2).
//
// On weak networks a registrar needs to be able to say "stop trying, I will
// sync later" without losing the ability to keep capturing data - and needs to
// see how much is still waiting.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../main.dart'; // cloudSyncService, uploadProgress
import '../providers/app_state.dart';
import '../services/background_sync_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/sync_outbox_service.dart';
import '../services/sync_settings_service.dart';

/// Opens the sync panel as a modal sheet - used by the dashboard status chip.
Future<void> showSyncSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Material statt Container/BoxDecoration: die ListTiles im Panel malen
    // Hintergrund und Ink-Splashes auf das nächste Material - eine DecoratedBox
    // davor würde beides verdecken.
    builder: (context) => Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                AppLocalizations.of(context)!.syncSectionTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
            ),
            const SyncControlCard(showAsCard: false),
          ],
        ),
      ),
    ),
  );
}

class SyncControlCard extends StatefulWidget {
  const SyncControlCard({super.key, this.showAsCard = true});

  /// Settings screens embed the tiles directly into their ListView.
  final bool showAsCard;

  @override
  State<SyncControlCard> createState() => _SyncControlCardState();
}

class _SyncControlCardState extends State<SyncControlCard> {
  @override
  void initState() {
    super.initState();
    // The counter is cheap to compute and should be current whenever the
    // control becomes visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshPendingItemCount();
    });
  }

  /// Live progress of the running sync, right where the button is - the status
  /// banner that carried this before lives on the home screen and is invisible
  /// from inside this sheet.
  Widget _buildLiveProgress(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<SyncProgress?>(
      valueListenable: cloudSyncService.syncProgress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox.shrink();

        final String phaseLabel;
        switch (progress.phase) {
          case SyncPhase.media:
            phaseLabel = l10n.syncPhaseMedia;
            break;
          case SyncPhase.push:
            phaseLabel = l10n.syncPhasePush;
            break;
          case SyncPhase.pull:
            phaseLabel = l10n.syncPhasePull;
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ValueListenableBuilder<double>(
            // Photo uploads also report byte-level progress; folding it in
            // keeps the bar moving during a single large image on a slow line.
            valueListenable: uploadProgress,
            builder: (context, bytePercent, __) {
              double? fraction = progress.fraction;
              if (progress.phase == SyncPhase.media && progress.total > 0) {
                fraction = ((progress.current - 1) + bytePercent / 100.0)
                    .clamp(0.0, progress.total.toDouble()) /
                    progress.total;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phaseLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${progress.current}/${progress.total}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                  if (progress.label != null && progress.label!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      progress.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Lists what is actually waiting. Without this, a count like "2 open" is
  /// unverifiable - the user has no way to tell real work from bookkeeping
  /// artefacts (e.g. an object the cloud flagged as a merge conflict).
  Widget _buildPendingDetails(BuildContext context, AppLocalizations l10n) {
    final items = collectPendingItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 4, bottom: 4),
        title: Text(
          l10n.pendingItemsTitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        children: items.map((item) {
          final isProblem = item.hasConflict || item.isLost;
          final subtitleParts = <String>[
            item.type,
            if (item.isLost) l10n.pendingItemLost,
            if (item.hasConflict) l10n.pendingItemConflict,
            if (!isProblem && item.reason != null && item.reason!.isNotEmpty)
              item.reason!,
          ];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.isLost
                  ? Icons.image_not_supported
                  : item.hasConflict
                      ? Icons.merge_type
                      : (item.isMethod
                          ? Icons.receipt_long
                          : Icons.inventory_2),
              size: 18,
              color: isProblem ? Colors.red[700] : Colors.grey[600],
            ),
            title: Text(
              item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            subtitle: Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isProblem ? Colors.red[700] : Colors.grey[600],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Explains why something is still pending: the retry backoff window and the
  /// last error the cloud reported. Empty when nothing is stuck.
  List<Widget> _buildRetryDiagnostics(
      BuildContext context, AppLocalizations l10n) {
    if (!syncOutbox.isOpen || syncOutbox.failingCount == 0) return const [];

    final widgets = <Widget>[];
    final nextDue = syncOutbox.nextDueAt;
    if (nextDue != null && nextDue.isAfter(DateTime.now().toUtc())) {
      final local = nextDue.toLocal();
      widgets.add(Text(
        l10n.syncNextRetry(
          MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(local)),
        ),
        style: TextStyle(color: Colors.orange[800], fontSize: 12),
      ));
    }

    final error = syncOutbox.lastErrorSeen;
    if (error != null && error.isNotEmpty) {
      widgets.add(Text(
        l10n.syncLastError(error),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.orange[800], fontSize: 12),
      ));
    }
    return widgets;
  }

  String _formatLastSync(BuildContext context, DateTime? utc) {
    final l10n = AppLocalizations.of(context)!;
    if (utc == null) return l10n.lastSyncNever;
    final local = utc.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    final time = materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    // Am selben Tag reicht die Uhrzeit - das volle Datum kostet auf einem
    // schmalen Display nur Zeilen ohne Informationsgewinn.
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return time;
    return '${materialL10n.formatShortDate(local)} $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer<AppState>(
          builder: (context, appState, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: syncSettings.uploadPaused,
              builder: (context, paused, __) {
                return SwitchListTile(
                  secondary: Icon(
                    paused ? Icons.cloud_off : Icons.cloud_upload,
                    color: paused ? Colors.orange[700] : null,
                  ),
                  title: Text(l10n.pauseUploads),
                  subtitle: Text(
                    paused ? l10n.uploadsPausedHint : l10n.uploadsActiveHint,
                    style: TextStyle(
                      color: paused ? Colors.orange[800] : Colors.grey[600],
                    ),
                  ),
                  value: paused,
                  onChanged: (value) => appState.setUploadPaused(value),
                );
              },
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: syncSettings.pendingItemCount,
          builder: (context, pending, _) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: syncSettings.lastSuccessfulSync,
              builder: (context, lastSync, __) {
                // Status und Button untereinander statt als ListTile-trailing:
                // auf einem Smartphone bleibt neben dem Button sonst so wenig
                // Platz, dass der Statustext Buchstabe für Buchstabe umbricht.
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 12),
                            child: Icon(
                              pending > 0
                                  ? Icons.pending_actions
                                  : Icons.check_circle,
                              size: 20,
                              color: pending > 0
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pending > 0
                                      ? l10n.itemsWaitingForUpload(pending)
                                      : l10n.allItemsSynced,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.lastSuccessfulSyncLabel(
                                      _formatLastSync(context, lastSync)),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                // Lost items are reported separately: counting
                                // them as "waiting" would promise an upload
                                // that can never happen - and contradict a
                                // sync that correctly says there is nothing
                                // to do.
                                ValueListenableBuilder<int>(
                                  valueListenable: syncSettings.failedItemCount,
                                  builder: (context, lost, __) {
                                    if (lost <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        l10n.itemsLostForUpload(lost),
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Warum hängt etwas? Ohne diese Zeile ist
                                // "2 offen" eine Zahl ohne Erklärung.
                                ..._buildRetryDiagnostics(context, l10n),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pending > 0) _buildPendingDetails(context, l10n),
                      _buildLiveProgress(context, l10n),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _SyncNowButton(),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );

    if (!widget.showAsCard) return content;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: content,
    );
  }
}

class _SyncNowButton extends StatefulWidget {
  @override
  State<_SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends State<_SyncNowButton> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppState>(context);
    // Deliberately NOT disabled while paused: pausing suppresses automatic
    // traffic precisely so the user can push manually at a moment of their
    // choosing. Only a missing connection or session really blocks it.
    final enabled =
        !_running && appState.isConnected && appState.isAuthenticated;

    return ElevatedButton.icon(
      // The global elevatedButtonTheme returns green-on-white for every state,
      // including disabled - a dead button would look perfectly alive. Both
      // states are therefore spelled out here.
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        disabledForegroundColor: Colors.grey[600],
      ),
      onPressed: enabled
          ? () async {
              setState(() => _running = true);
              try {
                final summary = await appState.syncNow();
                if (mounted) _reportResult(summary, l10n);
              } finally {
                if (mounted) setState(() => _running = false);
              }
            }
          : null,
      icon: _running
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                // While running the button is disabled, so the spinner has to
                // match the disabled foreground - white on grey is unreadable.
                color: Colors.grey[600],
              ),
            )
          : const Icon(Icons.sync, size: 18),
      label: Text(l10n.syncNowButton),
    );
  }

  /// A button press must always produce a visible answer - "nothing happened"
  /// and "it silently failed" have to be distinguishable.
  void _reportResult(SyncSummary summary, AppLocalizations l10n) {
    final parts = <String>[];
    if (summary.blockedByRunningSync) {
      parts.add(l10n.syncAlreadyRunning);
    } else {
      if (summary.pushed > 0) parts.add(l10n.syncResultPushed(summary.pushed));
      if (summary.conflicts > 0) {
        parts.add(l10n.syncResultConflicts(summary.conflicts));
      }
      if (summary.failed > 0) parts.add(l10n.syncResultFailed(summary.failed));
      if (parts.isEmpty) parts.add(l10n.syncResultNothingToDo);
    }

    final isProblem = summary.failed > 0 ||
        summary.conflicts > 0 ||
        summary.blockedByRunningSync;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' · ')),
        backgroundColor: isProblem ? Colors.orange[800] : Colors.green[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

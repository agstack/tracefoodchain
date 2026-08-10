// UI for the upload pause switch and the manual sync trigger (WP A2).
//
// On weak networks a registrar needs to be able to say "stop trying, I will
// sync later" without losing the ability to keep capturing data - and needs to
// see how much is still waiting.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_state.dart';
import '../services/background_sync_service.dart';
import '../services/sync_settings_service.dart';

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

  String _formatLastSync(BuildContext context, DateTime? utc) {
    final l10n = AppLocalizations.of(context)!;
    if (utc == null) return l10n.lastSyncNever;
    final local = utc.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    return '${materialL10n.formatShortDate(local)} '
        '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
                return ListTile(
                  leading: Icon(
                    pending > 0 ? Icons.pending_actions : Icons.check_circle,
                    color: pending > 0 ? Colors.orange[700] : Colors.green[700],
                  ),
                  title: Text(
                    pending > 0
                        ? l10n.itemsWaitingForUpload(pending)
                        : l10n.allItemsSynced,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  subtitle: Text(
                    l10n.lastSuccessfulSyncLabel(
                        _formatLastSync(context, lastSync)),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: _SyncNowButton(),
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
    // "Sync now" needs a connection and makes no sense while paused - toggling
    // the switch off already triggers a run.
    final enabled = !_running &&
        appState.isConnected &&
        appState.isAuthenticated &&
        !appState.uploadPaused;

    return ElevatedButton.icon(
      onPressed: enabled
          ? () async {
              setState(() => _running = true);
              try {
                await appState.syncNow();
              } finally {
                if (mounted) setState(() => _running = false);
              }
            }
          : null,
      icon: _running
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.sync, size: 18),
      label: Text(l10n.syncNowButton),
    );
  }
}

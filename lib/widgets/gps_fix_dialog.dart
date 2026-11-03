import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../services/gps_helper.dart';

/// Outcome of [requireValidPosition]. [proceed] is false when the user gave up
/// or no valid fix was found - the caller must then not save. [position] is
/// always valid, except after the debug-mode skip (last fix seen, or null).
typedef GpsGateResult = ({bool proceed, Position? position});

/// Blocks with a modal dialog until a fresh fix passing [isValidFix] is found,
/// showing the live accuracy meanwhile. On timeout the user can retry or
/// cancel. Use before storing anything that needs a trustworthy geolocation.
Future<GpsGateResult> requireValidPosition(BuildContext context) async {
  final result = await showDialog<GpsGateResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GpsFixDialog(),
  );
  return result ?? (proceed: false, position: null);
}

class _GpsFixDialog extends StatefulWidget {
  const _GpsFixDialog();

  @override
  State<_GpsFixDialog> createState() => _GpsFixDialogState();
}

class _GpsFixDialogState extends State<_GpsFixDialog> {
  ValidFixAcquisition? _acquisition;
  Position? _lastFix;
  bool _failed = false;
  bool _gpsUnavailable = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _acquisition?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _gpsUnavailable = false;
      _lastFix = null;
    });

    if (!await _ensureGpsAccess()) {
      if (mounted) setState(() => _gpsUnavailable = true);
      return;
    }
    if (!mounted) return;

    final acquisition = ValidFixAcquisition(onFix: (fix) {
      if (mounted) setState(() => _lastFix = fix);
    });
    _acquisition = acquisition;
    final position = await acquisition.result;
    if (!mounted || _acquisition != acquisition) return;

    if (position != null) {
      Navigator.of(context).pop((proceed: true, position: position));
    } else {
      setState(() => _failed = true);
    }
  }

  Future<bool> _ensureGpsAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('GPS: permission check failed: $e');
      return false;
    }
  }

  void _cancel() {
    _acquisition?.cancel();
    Navigator.of(context).pop((proceed: false, position: null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searching = !_failed && !_gpsUnavailable;
    final fix = _lastFix;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            searching ? Icons.gps_not_fixed : Icons.gps_off,
            color: searching ? Colors.blue : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.gpsFixTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_gpsUnavailable)
            Text(l10n.gpsDisabledMessage)
          else if (_failed)
            Text(l10n.gpsFixFailed(maxValidAccuracyMeters))
          else ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.gpsFixHint(maxValidAccuracyMeters)),
            const SizedBox(height: 12),
            Text(
              fix == null
                  ? l10n.waitingForGps
                  : '${l10n.accuracy}: ±${fix.accuracy.toStringAsFixed(1)} m',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: fix == null
                    ? Colors.grey
                    : isValidFix(fix)
                        ? Colors.green
                        : Colors.orange,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (kDebugMode)
          TextButton(
            onPressed: () {
              _acquisition?.cancel();
              Navigator.of(context).pop((proceed: true, position: _lastFix));
            },
            child: const Text('Skip (debug)'),
          ),
        TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
        if (!searching)
          ElevatedButton(onPressed: _start, child: Text(l10n.retry)),
      ],
    );
  }
}

// Position acquisition with a time limit that actually holds.
//
// Background: `LocationSettings.timeLimit` is NOT enforced on web. geolocator_web
// 4.1.3 passes the value to the browser in the wrong unit:
//
//   timeout: timeout?.inMicroseconds ?? const Duration(days: 1).inMilliseconds
//
// `PositionOptions.timeout` is milliseconds, so a 10 second limit arrives as
// 10,000,000 ms - about 2h 45m. In practice the call then hangs until the
// browser produces something, which on a desktop without GPS hardware can take
// many minutes. The Dart-side `.timeout()` here is what really bounds the wait.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Worst accuracy a fix may have to be stored with data. Beyond this the fix is
/// almost always a Wi-Fi/cell estimate rather than satellite positioning.
const int maxValidAccuracyMeters = 20;

/// Whether [p] may be stored as the geolocation of a record.
///
/// Freshness is not checked here: positions handed to this come from a live
/// stream ([ValidFixAcquisition]), never from getLastKnownPosition. The fix
/// timestamp is GNSS time and cannot be compared reliably with the device
/// clock, which is often wrong on field phones.
bool isValidFix(Position? p) {
  if (p == null) return false;
  if (p.latitude == 0 && p.longitude == 0) return false;
  if (p.latitude.abs() > 90 || p.longitude.abs() > 180) return false;
  // iOS reports a negative accuracy for invalid fixes.
  return p.accuracy > 0 && p.accuracy <= maxValidAccuracyMeters;
}

/// Listens to live fixes until a valid one ([isValidFix]) arrives, keeps
/// listening for [settle] to pick up an even better one, then completes
/// [result] with the most accurate valid fix. Completes with null after
/// [timeLimit] or [cancel] if no valid fix was seen.
///
/// On Android it starts with raw GNSS. geolocator_android shares one position
/// stream per app, so GNSS and the fused provider cannot run side by side;
/// if GNSS stays silent for [gnssTimeout] (indoors, dense canopy) it switches
/// to the fused provider, which can still reach the threshold near a window.
class ValidFixAcquisition {
  ValidFixAcquisition({
    Duration timeLimit = const Duration(seconds: 45),
    this.settle = const Duration(seconds: 3),
    this.gnssTimeout = const Duration(seconds: 15),
    this.onFix,
  }) {
    _deadline = Timer(timeLimit, _finish);
    _listen(gnssOnly: _isAndroid);
  }

  final Duration settle;
  final Duration gnssTimeout;

  /// Called with every fix, valid or not - for showing live accuracy.
  final void Function(Position fix)? onFix;

  final _completer = Completer<Position?>();
  StreamSubscription<Position>? _subscription;
  late final Timer _deadline;
  Timer? _gnssWatchdog;
  Timer? _settleTimer;
  Position? _best;

  Future<Position?> get result => _completer.future;

  void cancel() => _finish();

  void _listen({required bool gnssOnly}) {
    _subscription?.cancel();
    _gnssWatchdog?.cancel();
    if (gnssOnly) {
      _gnssWatchdog = Timer(gnssTimeout, () {
        debugPrint('GPS: no GNSS fix within ${gnssTimeout.inSeconds}s, '
            'switching to fused provider');
        _listen(gnssOnly: false);
      });
    }
    _subscription = Geolocator.getPositionStream(
      locationSettings: highAccuracyStreamSettings(gnssOnly: gnssOnly),
    ).listen((position) {
      _gnssWatchdog?.cancel();
      onFix?.call(position);
      if (!isValidFix(position)) return;
      if (_best == null || position.accuracy < _best!.accuracy) {
        _best = position;
      }
      _settleTimer ??= Timer(settle, _finish);
    }, onError: (Object e) {
      debugPrint('GPS stream error (gnssOnly: $gnssOnly): $e');
    });
  }

  void _finish() {
    if (_completer.isCompleted) return;
    _deadline.cancel();
    _gnssWatchdog?.cancel();
    _settleTimer?.cancel();
    _subscription?.cancel();
    _completer.complete(_best);
  }
}

/// Settings for a continuous high-accuracy position stream (polygon recording).
///
/// On Android, geolocator defaults to the Fused Location Provider, which blends
/// GNSS with Wi-Fi/cell fixes. Those network fixes report ±10-15 m and the
/// provider switches between sources, so the displayed accuracy jumps around
/// even when a plain GPS app on the same phone shows a steady 3-4 m.
/// [gnssOnly] uses the raw GNSS chip via LocationManager instead. It can fail to
/// produce any fix under dense canopy, so callers should fall back to
/// `gnssOnly: false` if nothing arrives.
///
/// distanceFilter is 0 on purpose: with a filter, a user standing still never
/// receives the improved fix, and only noisy jumps get through.
LocationSettings highAccuracyStreamSettings({bool gnssOnly = true}) {
  if (_isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      forceLocationManager: gnssOnly,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );
}

/// Fetches a position for display or as a pre-fill (status chip, editable
/// coordinate fields).
///
/// Returns null instead of throwing when no position can be obtained in time.
/// The result may be stale (last known position) or inaccurate - anything
/// stored as a record's geolocation must go through [ValidFixAcquisition] /
/// requireValidPosition instead.
///
/// [timeLimit]   hard upper bound on the wait, enforced on every platform.
/// [maxCacheAge] on web, how old a cached browser fix may be before a fresh one
///               is requested. The default of zero forces a new high-accuracy
///               acquisition on every single call, which is the main reason the
///               web camera felt frozen.
/// [fallback]    returned when the lookup times out - e.g. the position the
///               screen already knows.
Future<Position?> getPositionWithTimeout({
  Duration timeLimit = const Duration(seconds: 10),
  Duration maxCacheAge = const Duration(seconds: 15),
  LocationAccuracy accuracy = LocationAccuracy.best,
  Position? fallback,
}) async {
  final LocationSettings settings = kIsWeb
      ? WebSettings(
          accuracy: accuracy,
          maximumAge: maxCacheAge,
          timeLimit: timeLimit,
        )
      : _isAndroid
          // Raw GNSS like the polygon stream, so every screen reports the
          // same accuracy (see highAccuracyStreamSettings).
          ? AndroidSettings(
              accuracy: accuracy,
              timeLimit: timeLimit,
              forceLocationManager: true,
            )
          : LocationSettings(accuracy: accuracy, timeLimit: timeLimit);

  try {
    // The extra second gives a correctly implemented platform timeout the
    // chance to fire first, so we surface its error rather than our own.
    return await Geolocator.getCurrentPosition(locationSettings: settings)
        .timeout(timeLimit + const Duration(seconds: 1));
  } on TimeoutException {
    debugPrint('GPS: no fix within ${timeLimit.inSeconds}s');
    return await _bestEffortFallback(fallback);
  } catch (e) {
    debugPrint('GPS: could not get position: $e');
    return await _bestEffortFallback(fallback);
  }
}

Future<Position?> _bestEffortFallback(Position? fallback) async {
  if (fallback != null) return fallback;
  // getLastKnownPosition throws "unsupported" on web, so only try it natively.
  if (kIsWeb) return null;
  try {
    return await Geolocator.getLastKnownPosition();
  } catch (e) {
    debugPrint('GPS: no last known position either: $e');
    return null;
  }
}

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

/// Fetches a position for tagging a capture (photo, field point, ...).
///
/// Returns null instead of throwing when no position can be obtained in time -
/// a missing geotag must never block the capture itself.
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

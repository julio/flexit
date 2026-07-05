import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'storage.dart';

/// One walking/running distance sample pulled from Apple Health: the metres
/// covered over the interval starting at [start] (local time). HealthKit
/// returns many small interval samples per day; [HealthSync] buckets and sums
/// them into a per-day total.
@immutable
class DistanceSample {
  final DateTime start;
  final double meters;
  const DistanceSample(this.start, this.meters);
}

/// The seam between [HealthSync]'s logic and Apple Health. Production uses
/// [HealthKitGateway]; tests inject a fake so the sync logic can be exercised
/// without the platform. Mirrors how [CloudSync] injects its http client.
abstract class HealthGateway {
  /// Ask the OS for read access to walking+running distance. Returns whether
  /// the grant succeeded (a denial or an unavailable store yields false).
  Future<bool> requestAuthorization();

  /// Every distance sample in `[start, end]`. Empty if none / not authorized.
  Future<List<DistanceSample>> distanceSamples(DateTime start, DateTime end);
}

/// Maps a raw Health data point to our lightweight [DistanceSample]. Extracted
/// (and [visibleForTesting]) so the numeric extraction is unit-tested directly
/// without standing up the platform channel.
@visibleForTesting
DistanceSample distanceSampleFromPoint(HealthDataPoint p) {
  final v = p.value;
  final meters = v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
  return DistanceSample(p.dateFrom, meters);
}

/// Concrete gateway backed by the `health` plugin (Apple Health / HealthKit).
///
/// Note we deliberately skip the plugin's `configure()`: in this version it is
/// a Dart-only call that fetches a device id used solely to tag data we *write*
/// — it makes no native HealthKit setup call, and we only read. Skipping it
/// keeps the read path free of the device-info dependency.
class HealthKitGateway implements HealthGateway {
  final Health _health = Health();

  static const _types = [HealthDataType.DISTANCE_WALKING_RUNNING];

  @override
  Future<bool> requestAuthorization() {
    return _health.requestAuthorization(_types,
        permissions: const [HealthDataAccess.READ]);
  }

  @override
  Future<List<DistanceSample>> distanceSamples(
      DateTime start, DateTime end) async {
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    return points.map(distanceSampleFromPoint).toList();
  }
}

/// Pulls walking+running distance from Apple Health into local storage, keyed
/// by day (`flexit_dist_<date>`, integer metres). Best-effort throughout: a
/// denied permission, an unavailable store, or any platform error leaves
/// existing data untouched and returns 0 — the app never blocks on Health.
class HealthSync {
  /// Flipped off in widget tests so they never touch the platform. Gateway
  /// tests re-enable it with a fake [gateway].
  static bool enabled = true;

  /// Injectable so tests can supply a fake. Production reads real HealthKit.
  static HealthGateway gateway = HealthKitGateway();

  /// How far back to pull on each sync. "All available" in practice: HealthKit
  /// has no earliest-date query, so we sweep a decade — well beyond any real
  /// history — and only the days that actually have samples get written.
  static const defaultLookbackDays = 3650;

  /// Authorize (if needed) and import every day with distance in the lookback
  /// window. Returns the number of days written. `now` is injectable for tests.
  static Future<int> syncDistance({
    DateTime? now,
    int lookbackDays = defaultLookbackDays,
  }) async {
    if (!enabled) return 0;
    try {
      final authorized = await gateway.requestAuthorization();
      if (!authorized) return 0;

      final end = now ?? DateTime.now();
      final start = end.subtract(Duration(days: lookbackDays));
      final samples = await gateway.distanceSamples(start, end);

      // Sum every sample into its local calendar day.
      final byDay = <String, double>{};
      for (final s in samples) {
        final key = formatDate(s.start.toLocal());
        byDay[key] = (byDay[key] ?? 0) + s.meters;
      }

      var written = 0;
      for (final entry in byDay.entries) {
        final meters = entry.value.round();
        if (meters <= 0) continue; // no-data / zero days stay empty cells
        await setDistanceMeters(entry.key, meters);
        written++;
      }
      return written;
    } catch (_) {
      return 0;
    }
  }
}

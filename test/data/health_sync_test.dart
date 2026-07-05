import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:flexit/data/health_sync.dart';
import 'package:flexit/data/storage.dart';

import '../helpers/test_harness.dart';

/// Fake gateway: drives [HealthSync]'s logic without any platform channel.
class FakeHealthGateway implements HealthGateway {
  bool authorized;
  List<DistanceSample> samples;
  Object? throwOnSamples;
  int authCalls = 0;
  DateTime? lastStart;
  DateTime? lastEnd;

  FakeHealthGateway({
    this.authorized = true,
    this.samples = const [],
    this.throwOnSamples,
  });

  @override
  Future<bool> requestAuthorization() async {
    authCalls++;
    return authorized;
  }

  @override
  Future<List<DistanceSample>> distanceSamples(
      DateTime start, DateTime end) async {
    lastStart = start;
    lastEnd = end;
    if (throwOnSamples != null) throw throwOnSamples!;
    return samples;
  }
}

void main() {
  late TestHarness h;

  setUp(() async {
    h = await installTestHarness();
    // installTestHarness disables HealthSync; these tests drive it directly.
    HealthSync.enabled = true;
  });
  tearDown(() {
    HealthSync.enabled = false;
    HealthSync.gateway = HealthKitGateway();
    h.dispose();
  });

  group('HealthSync.syncDistance', () {
    test('does nothing and returns 0 when disabled', () async {
      HealthSync.enabled = false;
      final fake = FakeHealthGateway(samples: [
        DistanceSample(DateTime(2026, 7, 1, 9), 1000),
      ]);
      HealthSync.gateway = fake;

      expect(await HealthSync.syncDistance(), 0);
      expect(fake.authCalls, 0); // never even asked for permission
    });

    test('returns 0 without writing when authorization is denied', () async {
      HealthSync.gateway = FakeHealthGateway(authorized: false, samples: [
        DistanceSample(DateTime(2026, 7, 1, 9), 5000),
      ]);

      expect(await HealthSync.syncDistance(), 0);
      expect(await getDistanceMeters('2026-07-01'), isNull);
    });

    test('buckets samples by local day, sums metres, writes each day',
        () async {
      HealthSync.gateway = FakeHealthGateway(samples: [
        DistanceSample(DateTime(2026, 7, 1, 8), 1234.6),
        DistanceSample(DateTime(2026, 7, 1, 18), 1000.4), // same day → summed
        DistanceSample(DateTime(2026, 7, 2, 12), 3000),
      ]);

      final written = await HealthSync.syncDistance();

      expect(written, 2);
      expect(await getDistanceMeters('2026-07-01'), 2235); // 1234.6+1000.4
      expect(await getDistanceMeters('2026-07-02'), 3000);
    });

    test('skips zero-distance days (they stay empty cells)', () async {
      HealthSync.gateway = FakeHealthGateway(samples: [
        DistanceSample(DateTime(2026, 7, 1, 8), 0),
        DistanceSample(DateTime(2026, 7, 2, 8), 500),
      ]);

      final written = await HealthSync.syncDistance();

      expect(written, 1);
      expect(await getDistanceMeters('2026-07-01'), isNull);
      expect(await getDistanceMeters('2026-07-02'), 500);
    });

    test('honours the lookback window and injected now', () async {
      final fake = FakeHealthGateway(samples: const []);
      HealthSync.gateway = fake;
      final now = DateTime(2026, 7, 4, 10);

      await HealthSync.syncDistance(now: now, lookbackDays: 30);

      expect(fake.lastEnd, now);
      expect(fake.lastStart, now.subtract(const Duration(days: 30)));
    });

    test('returns 0 and swallows a gateway error', () async {
      HealthSync.gateway =
          FakeHealthGateway(throwOnSamples: StateError('boom'));

      expect(await HealthSync.syncDistance(), 0);
    });
  });

  group('distanceSampleFromPoint', () {
    HealthDataPoint point(HealthValue value) => HealthDataPoint(
          uuid: 'u1',
          value: value,
          type: HealthDataType.DISTANCE_WALKING_RUNNING,
          unit: HealthDataUnit.METER,
          dateFrom: DateTime(2026, 7, 1, 8),
          dateTo: DateTime(2026, 7, 1, 9),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: 'dev',
          sourceId: 'src',
          sourceName: 'Watch',
        );

    test('extracts metres from a numeric value', () {
      final s = distanceSampleFromPoint(
          point(NumericHealthValue(numericValue: 2500)));
      expect(s.meters, 2500.0);
      expect(s.start, DateTime(2026, 7, 1, 8));
    });

    test('falls back to 0 for a non-numeric value', () {
      final s = distanceSampleFromPoint(
          point(WorkoutHealthValue(workoutActivityType: HealthWorkoutActivityType.WALKING)));
      expect(s.meters, 0.0);
    });
  });

  group('HealthKitGateway (real plugin over a mocked channel)', () {
    const channel = MethodChannel('flutter_health');
    const deviceInfoChannel =
        MethodChannel('dev.fluttercommunity.plus/device_info');

    // The plugin fetches a device id (via device_info_plus) even on the read
    // path, so that channel must answer too. A minimal-but-complete iOS map.
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceInfoChannel, (call) async {
        return <String, dynamic>{
          'name': 'iPhone',
          'systemName': 'iOS',
          'systemVersion': '27.0',
          'model': 'iPhone',
          'modelName': 'iPhone',
          'localizedModel': 'iPhone',
          'identifierForVendor': 'test-vendor-id',
          'freeDiskSize': 0,
          'totalDiskSize': 0,
          'isPhysicalDevice': true,
          'physicalRamSize': 0,
          'availableRamSize': 0,
          'isiOSAppOnMac': false,
          'isiOSAppOnVision': false,
          'utsname': <String, dynamic>{
            'sysname': 'Darwin',
            'nodename': 'iPhone',
            'release': '27.0',
            'version': '1',
            'machine': 'iPhone',
          },
        };
      });
    });

    tearDown(() {
      final m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMethodCallHandler(channel, null);
      m.setMockMethodCallHandler(deviceInfoChannel, null);
    });

    void mockHealth({required bool auth, List<dynamic> data = const []}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'requestAuthorization':
            return auth;
          case 'getData':
            return data;
          default:
            return null;
        }
      });
    }

    test('requestAuthorization forwards the grant result', () async {
      mockHealth(auth: true);
      expect(await HealthKitGateway().requestAuthorization(), isTrue);

      mockHealth(auth: false);
      expect(await HealthKitGateway().requestAuthorization(), isFalse);
    });

    test('distanceSamples returns empty when the store has no data', () async {
      mockHealth(auth: true, data: const []);
      final samples = await HealthKitGateway()
          .distanceSamples(DateTime(2026, 6, 1), DateTime(2026, 7, 1));
      expect(samples, isEmpty);
    });
  });
}

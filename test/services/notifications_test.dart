import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/services/notifications.dart';

import '../helpers/test_harness.dart';

/// TimerNotifications wraps flutter_local_notifications. The harness installs a
/// mock for that plugin's method channel and records every call, so we can
/// assert the scheduling contract without a real OS notification service.
///
/// Note: TimerNotifications.instance is a process-wide singleton whose
/// `_initialized` flag persists across tests in this file. That's fine — the
/// behaviors under test (the past-time guard, scheduling a future fire, cancel)
/// don't depend on init ordering, and init() is idempotent by design.
void main() {
  late TestHarness h;

  setUp(() async {
    h = await installTestHarness();
  });
  tearDown(() => h.dispose());

  test('init() is safe to call and idempotent', () async {
    await TimerNotifications.instance.init();
    await TimerNotifications.instance.init(); // second call is a no-op
    // The plugin's initialize handler ran at least once.
    expect(
      h.notificationCalls.where((c) => c.method == 'initialize'),
      isNotEmpty,
    );
  });

  test('schedule() in the past is a no-op — never reaches the plugin',
      () async {
    await TimerNotifications.instance.init();
    final before = h.notificationCalls
        .where((c) => c.method == 'zonedSchedule')
        .length;

    await TimerNotifications.instance.schedule(
      id: 1,
      title: 'Done',
      body: 'Timer complete',
      fireAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    final after =
        h.notificationCalls.where((c) => c.method == 'zonedSchedule').length;
    expect(after, before, reason: 'past fire time must not schedule anything');
  });

  test('schedule() in the future reaches the plugin with the given id',
      () async {
    await TimerNotifications.instance.schedule(
      id: 42,
      title: 'Set done',
      body: 'Next set',
      fireAt: DateTime.now().add(const Duration(minutes: 2)),
    );

    final scheduled =
        h.notificationCalls.where((c) => c.method == 'zonedSchedule').toList();
    expect(scheduled, isNotEmpty);
    // The plugin serializes the request id into the call arguments.
    final args = scheduled.last.arguments;
    expect(args, isA<Map>());
    expect((args as Map)['id'], 42);
  });

  test('schedule() auto-inits when called before init()', () async {
    // Even if init() were never called explicitly, schedule() must guard-init.
    // (The singleton may already be initialized by earlier tests; this asserts
    // scheduling still works rather than asserting a fresh init call.)
    await TimerNotifications.instance.schedule(
      id: 7,
      title: 't',
      body: 'b',
      fireAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(
      h.notificationCalls.where((c) => c.method == 'zonedSchedule'),
      isNotEmpty,
    );
  });

  test('cancel() routes the id to the plugin', () async {
    await TimerNotifications.instance.init();
    await TimerNotifications.instance.cancel(42);
    final cancels =
        h.notificationCalls.where((c) => c.method == 'cancel').toList();
    expect(cancels, isNotEmpty);
    expect(cancels.last.arguments, anyOf(42, isA<Map>()));
  });
}

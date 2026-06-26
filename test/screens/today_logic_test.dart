import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexit/data/storage.dart';
import 'package:flexit/models/session.dart';
import 'package:flexit/screens/today_screen.dart' show reconcileDailyCompletion;

/// Pure-logic tests for the daily-session reconciliation extracted from the
/// Today screen. The un-complete branch in particular is unreachable through
/// the UI (the completion banner replaces the toggle controls once the day is
/// done), so this is the only place it can be exercised.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reconcileDailyCompletion', () {
    test('writes a daily session when the day just became complete', () async {
      final now = DateTime(2026, 6, 25, 9, 30);
      final changed =
          await reconcileDailyCompletion(allDone: true, wasDone: false, now: now);

      expect(changed, isTrue);
      final sessions = await getSessions();
      expect(sessions.length, 1);
      expect(sessions.single.date, formatDate(now));
      expect(sessions.single.type, 'daily');
    });

    test('removes the session when a complete day is no longer complete',
        () async {
      final now = DateTime(2026, 6, 25, 9, 30);
      await saveSession(Session(
        date: formatDate(now),
        completedAt: now.toUtc().toIso8601String(),
        type: 'daily',
      ));

      final changed =
          await reconcileDailyCompletion(allDone: false, wasDone: true, now: now);

      expect(changed, isTrue);
      expect(await getSessions(), isEmpty);
    });

    test('does nothing when the completion state is unchanged', () async {
      final now = DateTime(2026, 6, 25);
      // Still incomplete.
      expect(
          await reconcileDailyCompletion(
              allDone: false, wasDone: false, now: now),
          isFalse);
      // Still complete.
      expect(
          await reconcileDailyCompletion(allDone: true, wasDone: true, now: now),
          isFalse);
      expect(await getSessions(), isEmpty);
    });
  });
}

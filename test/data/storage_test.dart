import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexit/data/storage.dart';
import 'package:flexit/models/session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('formatDate', () {
    test('formats single-digit month and day with padding', () {
      expect(formatDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('formats double-digit month and day', () {
      expect(formatDate(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });

  group('getSessions / saveSession', () {
    test('returns empty list when no sessions saved', () async {
      final sessions = await getSessions();
      expect(sessions, isEmpty);
    });

    test('saves and retrieves a session', () async {
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:00:00.000',
        type: 'daily',
      ));

      final sessions = await getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].date, '2026-04-10');
      expect(sessions[0].type, 'daily');
    });

    test('replaces session with same date', () async {
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:00:00.000',
        type: 'daily',
      ));
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T15:00:00.000',
        type: 'weekend',
      ));

      final sessions = await getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].completedAt, '2026-04-10T15:00:00.000');
      expect(sessions[0].type, 'weekend');
    });

    test('stores multiple sessions for different dates', () async {
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:00:00.000',
        type: 'daily',
      ));
      await saveSession(const Session(
        date: '2026-04-11',
        completedAt: '2026-04-11T10:00:00.000',
        type: 'daily',
      ));

      final sessions = await getSessions();
      expect(sessions.length, 2);
    });
  });

  group('removeSession', () {
    test('removes a session by date', () async {
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:00:00.000',
        type: 'daily',
      ));
      await saveSession(const Session(
        date: '2026-04-11',
        completedAt: '2026-04-11T10:00:00.000',
        type: 'daily',
      ));

      await removeSession('2026-04-10');
      final sessions = await getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].date, '2026-04-11');
    });

    test('does nothing when date not found', () async {
      await saveSession(const Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:00:00.000',
        type: 'daily',
      ));

      await removeSession('2026-04-15');
      final sessions = await getSessions();
      expect(sessions.length, 1);
    });

    test('handles empty sessions list', () async {
      await removeSession('2026-04-10');
      final sessions = await getSessions();
      expect(sessions, isEmpty);
    });
  });

  group('isTodayComplete', () {
    test('returns false when no sessions', () async {
      expect(await isTodayComplete(), false);
    });

    test('returns true when today has a session', () async {
      final today = formatDate(DateTime.now());
      await saveSession(Session(
        date: today,
        completedAt: DateTime.now().toIso8601String(),
        type: 'daily',
      ));
      expect(await isTodayComplete(), true);
    });
  });

  group('getCurrentStreak', () {
    test('returns 0 for empty sessions', () {
      expect(getCurrentStreak([]), 0);
    });

    test('returns 1 when only today is done', () {
      final today = formatDate(DateTime.now());
      final sessions = [
        Session(date: today, completedAt: '', type: 'daily'),
      ];
      expect(getCurrentStreak(sessions), 1);
    });

    test('counts consecutive days backwards', () {
      final now = DateTime.now();
      final sessions = List.generate(
        5,
        (i) => Session(
          date: formatDate(now.subtract(Duration(days: i))),
          completedAt: '',
          type: 'daily',
        ),
      );
      expect(getCurrentStreak(sessions), 5);
    });

    test('streak from yesterday when today not done', () {
      final now = DateTime.now();
      final sessions = [
        Session(
            date: formatDate(now.subtract(const Duration(days: 1))),
            completedAt: '',
            type: 'daily'),
        Session(
            date: formatDate(now.subtract(const Duration(days: 2))),
            completedAt: '',
            type: 'daily'),
      ];
      expect(getCurrentStreak(sessions), 2);
    });

    test('breaks streak on gap', () {
      final now = DateTime.now();
      final sessions = [
        Session(date: formatDate(now), completedAt: '', type: 'daily'),
        // skip yesterday
        Session(
            date: formatDate(now.subtract(const Duration(days: 2))),
            completedAt: '',
            type: 'daily'),
      ];
      expect(getCurrentStreak(sessions), 1);
    });
  });

  group('getLongestStreak', () {
    test('returns 0 for empty sessions', () {
      expect(getLongestStreak([]), 0);
    });

    test('returns 1 for single session', () {
      final sessions = [
        const Session(date: '2026-04-10', completedAt: '', type: 'daily'),
      ];
      expect(getLongestStreak(sessions), 1);
    });

    test('finds longest consecutive run', () {
      final sessions = [
        const Session(date: '2026-04-01', completedAt: '', type: 'daily'),
        const Session(date: '2026-04-02', completedAt: '', type: 'daily'),
        const Session(date: '2026-04-03', completedAt: '', type: 'daily'),
        // gap
        const Session(date: '2026-04-05', completedAt: '', type: 'daily'),
        const Session(date: '2026-04-06', completedAt: '', type: 'daily'),
      ];
      expect(getLongestStreak(sessions), 3);
    });

    test('handles unsorted input', () {
      final sessions = [
        const Session(date: '2026-04-03', completedAt: '', type: 'daily'),
        const Session(date: '2026-04-01', completedAt: '', type: 'daily'),
        const Session(date: '2026-04-02', completedAt: '', type: 'daily'),
      ];
      expect(getLongestStreak(sessions), 3);
    });
  });

  group('exercise completion tracking', () {
    test('returns empty set when nothing saved', () async {
      final completed = await getTodayCompletedExercises();
      expect(completed, isEmpty);
    });

    test('saves and retrieves completed exercises', () async {
      await saveTodayCompletedExercises({'cat-cow', 'hip-cars'});
      final completed = await getTodayCompletedExercises();
      expect(completed, {'cat-cow', 'hip-cars'});
    });

    test('overwrites previous exercise completions', () async {
      await saveTodayCompletedExercises({'cat-cow'});
      await saveTodayCompletedExercises({'cat-cow', 'hip-cars', '90-90'});
      final completed = await getTodayCompletedExercises();
      expect(completed.length, 3);
    });
  });

  group('getCompletedExercises', () {
    test('returns empty set for date with no data', () async {
      final completed = await getCompletedExercises('2026-04-10');
      expect(completed, isEmpty);
    });

    test('saves and retrieves exercises for a specific date', () async {
      await saveCompletedExercises('2026-04-10', {'cat-cow', 'hip-cars'});
      final completed = await getCompletedExercises('2026-04-10');
      expect(completed, {'cat-cow', 'hip-cars'});
    });

    test('different dates have independent data', () async {
      await saveCompletedExercises('2026-04-10', {'cat-cow'});
      await saveCompletedExercises('2026-04-11', {'hip-cars', '90-90'});

      final day1 = await getCompletedExercises('2026-04-10');
      final day2 = await getCompletedExercises('2026-04-11');
      expect(day1, {'cat-cow'});
      expect(day2, {'hip-cars', '90-90'});
    });

    test('overwrites exercises for the same date', () async {
      await saveCompletedExercises('2026-04-10', {'cat-cow'});
      await saveCompletedExercises('2026-04-10', {'cat-cow', 'hip-cars'});
      final completed = await getCompletedExercises('2026-04-10');
      expect(completed, {'cat-cow', 'hip-cars'});
    });

    test('getTodayCompletedExercises delegates to getCompletedExercises',
        () async {
      final today = formatDate(DateTime.now());
      await saveCompletedExercises(today, {'cat-cow', 'pigeon'});
      final completed = await getTodayCompletedExercises();
      expect(completed, {'cat-cow', 'pigeon'});
    });

    test('saveTodayCompletedExercises delegates to saveCompletedExercises',
        () async {
      await saveTodayCompletedExercises({'glute-bridge'});
      final today = formatDate(DateTime.now());
      final completed = await getCompletedExercises(today);
      expect(completed, {'glute-bridge'});
    });
  });

  group('getAllCompletedExercises', () {
    test('returns empty map when nothing saved', () async {
      final all = await getAllCompletedExercises();
      expect(all, isEmpty);
    });

    test('returns a map keyed by date', () async {
      await saveCompletedExercises('2026-04-10', {'cat-cow'});
      await saveCompletedExercises('2026-04-11', {'hip-cars', '90-90'});

      final all = await getAllCompletedExercises();
      expect(all.length, 2);
      expect(all['2026-04-10'], {'cat-cow'});
      expect(all['2026-04-11'], {'hip-cars', '90-90'});
    });

    test('skips dates with empty exercise lists', () async {
      await saveCompletedExercises('2026-04-10', {'cat-cow'});
      await saveCompletedExercises('2026-04-11', {});

      final all = await getAllCompletedExercises();
      expect(all.keys, {'2026-04-10'});
    });

    test('ignores unrelated SharedPreferences keys', () async {
      SharedPreferences.setMockInitialValues({
        'flexit_exercises_2026-04-10': ['cat-cow'],
        'some_other_key': 'value',
        'flexit_sessions': '[]',
      });
      final all = await getAllCompletedExercises();
      expect(all.keys, {'2026-04-10'});
    });
  });

  group('timer settings', () {
    test('returns default when no value saved', () async {
      expect(await getTimerSeconds('plank', 60), 60);
    });

    test('saves and retrieves a timer setting', () async {
      await setTimerSeconds('plank', 90);
      expect(await getTimerSeconds('plank', 60), 90);
    });

    test('different keys store independent values', () async {
      await setTimerSeconds('plank', 120);
      await setTimerSeconds('hang', 45);
      expect(await getTimerSeconds('plank', 60), 120);
      expect(await getTimerSeconds('hang', 60), 45);
    });
  });
}

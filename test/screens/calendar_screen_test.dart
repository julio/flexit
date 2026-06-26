import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flexit/data/exercises.dart';
import 'package:flexit/data/storage.dart';
import 'package:flexit/models/session.dart';
import 'package:flexit/screens/calendar_screen.dart';
import 'package:flexit/screens/settings_screen.dart';
import 'package:flexit/screens/weight_chart_screen.dart';

import '../helpers/test_harness.dart';

/// Widget tests for the Calendar screen. These drive real gestures (taps,
/// swipes, text entry) and assert both the resulting UI and the persisted
/// SharedPreferences writes via the storage layer.
void main() {
  late TestHarness harness;

  // A fixed past month we can address deterministically regardless of when
  // the suite runs. April 2024 is comfortably in the past.
  const pastYear = 2024;
  const pastMonth = 4; // April
  String d(int day) => '$pastYear-04-${day.toString().padLeft(2, '0')}';

  String monthLabel(DateTime now) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  /// Finds a stat-box value glyph (the big fontSize-28 number) reading [text],
  /// so calendar day-number cells that happen to share the digits don't count.
  Finder statValue(WidgetTester tester, String text) {
    return find.byWidgetPredicate((w) =>
        w is Text &&
        w.data == text &&
        w.style?.fontSize == 28);
  }

  /// Finds a back-pain chip glyph (white, fontSize 11, weight w800) reading
  /// [text]. Distinguishes the chip from a calendar day cell with the same
  /// digits, which renders at fontSize 14.
  Finder backPainChip(String text) {
    return find.byWidgetPredicate((w) =>
        w is Text &&
        w.data == text &&
        w.style?.fontSize == 11 &&
        w.style?.fontWeight == FontWeight.w800);
  }

  Future<void> seedAndReload(
    WidgetTester tester,
    GlobalKey<CalendarScreenState> key,
  ) async {
    key.currentState!.reload();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Steps the calendar's focused month backwards from "now" to [pastMonth]
  /// [pastYear] by tapping the left chevron until the header reads the target.
  Future<void> navigateToPastMonth(WidgetTester tester) async {
    final target = '${_monthNames[pastMonth - 1]} $pastYear';
    // Cap iterations low so a wrong finder can't spin: April 2024 is only a
    // couple of years back, well within 40 month-steps.
    for (var i = 0; i < 40; i++) {
      if (find.text(target).evaluate().isNotEmpty) return;
      // The left chevron in the month header navigates to the previous month.
      // It's the first chevron_left in the tree (the measurement pill's
      // chevron_left is its "previous measurement" button — distinguish by
      // tapping the month-header one, which is inside the calendar card).
      final lefts = find.byIcon(Icons.chevron_left);
      // The month-header chevron is the *last* chevron_left (pill renders
      // first in the ListView, calendar card after it).
      await tester.tap(lefts.last);
      await tester.pump();
    }
    fail('Could not navigate to $target');
  }

  setUp(() {});

  tearDown(() => harness.dispose());

  group('stats row', () {
    testWidgets('shows zero streaks and zero sessions when empty',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      // Three stat boxes: current streak, longest streak, total sessions.
      expect(find.text('Current\nStreak'), findsOneWidget);
      expect(find.text('Longest\nStreak'), findsOneWidget);
      expect(find.text('Total\nSessions'), findsOneWidget);
      // All three values are 0.
      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('No sessions yet. Complete your first workout!'),
          findsOneWidget);
    });

    testWidgets('computes current/longest streak and total from sessions',
        (tester) async {
      final now = DateTime.now();
      // Three consecutive days ending today => current streak 3, longest 3,
      // total 3.
      final sessions = List.generate(3, (i) {
        final date = formatDate(now.subtract(Duration(days: i)));
        return Session(date: date, completedAt: '${date}T12:00:00Z',
            type: 'daily');
      });
      harness = await installTestHarness(prefs: {
        'flexit_sessions':
            '[${sessions.map((s) => '{"date":"${s.date}","completedAt":"${s.completedAt}","type":"daily"}').join(',')}]',
      });
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      // current streak, longest streak, total sessions — all 3. Scope to the
      // stat-box value glyphs (fontSize 28) so a calendar day cell that also
      // reads "3" doesn't inflate the count.
      expect(statValue(tester, '3'), findsNWidgets(3));
      // Recent-sessions empty state is gone.
      expect(find.text('No sessions yet. Complete your first workout!'),
          findsNothing);
    });
  });

  group('measurement switcher', () {
    testWidgets('renders the default completion measurement', (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);
      expect(find.text('Completion'), findsOneWidget);
    });

    testWidgets('tapping next chevron cycles measurement and persists it',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      expect(find.text('Completion'), findsOneWidget);

      // The pill's "Next" chevron is the first chevron_right in the tree.
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('p rating'), findsOneWidget);
      expect(find.text('Completion'), findsNothing);
      expect(await getCalendarMeasurement(), 'p');
    });

    testWidgets('tapping prev chevron wraps from completion to weight',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      // The pill's "Previous" chevron is the first chevron_left.
      await tester.tap(find.byIcon(Icons.chevron_left).first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Weight'), findsOneWidget);
      expect(await getCalendarMeasurement(), 'weight');
    });

    testWidgets('swiping the pill left advances to the next measurement',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      // Fling left (negative x velocity) over the pill => onNext.
      await tester.fling(
          find.text('Completion'), const Offset(-300, 0), 1000);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('p rating'), findsOneWidget);
      expect(await getCalendarMeasurement(), 'p');
    });

    testWidgets('restores the persisted measurement on load', (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'backpain',
      });
      await pumpScreen(tester, const CalendarScreen(), settle: true);
      expect(find.text('Back pain'), findsOneWidget);
    });
  });

  group('month navigation', () {
    testWidgets('shows the current month by default', (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);
      expect(find.text(monthLabel(DateTime.now())), findsOneWidget);
    });

    testWidgets('right chevron in header advances one month', (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1);
      // The month-header chevron_right is the *last* one in the tree.
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pump();
      expect(find.text(monthLabel(nextMonth)), findsOneWidget);
    });
  });

  group('day selection and detail sheet', () {
    testWidgets('tapping a past day opens the inline detail with editors',
        (tester) async {
      // Use Daily 30 (fixed routine, stable blocks) and seed a first session
      // so the day is a "tracked day" and editable.
      harness = await installTestHarness(prefs: {
        'flexit_routine': daily30RoutineId,
      });
      await setActiveRoutineId(daily30RoutineId);
      // A session in the past so navigated month has tracked, editable days.
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      await navigateToPastMonth(tester);

      // Tap day 15 (past, after the first session => editable).
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Detail surfaces the compact editors: P / DRINKS / BACK PAIN / WEIGHT.
      expect(find.text('P'), findsWidgets);
      expect(find.text('DRINKS'), findsOneWidget);
      expect(find.text('BACK PAIN'), findsOneWidget);
      expect(find.text('WEIGHT'), findsOneWidget);
    });

    testWidgets('editing a p-rating in the detail persists it', (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // The P editor chips read +2, +1, 0, -1, -2. Tap "+2" (excellent).
      await tester.tap(find.text('+2'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getPRating(d(15)), 2);
      // The label for the selected value renders in the detail.
      expect(find.text('excellent'), findsOneWidget);
    });

    testWidgets('editing back pain in the detail persists it', (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Back-pain chips are 0..10. The detail editor sits below the calendar
      // in the ListView; scroll the "7" chip into view before tapping.
      final chip = backPainChip('7');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getBackPainRating(d(15)), 7);
    });

    testWidgets('editing alcohol (Drinks) in the detail persists it',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Tap "Drinks" (value 1).
      await tester.tap(find.text('Drinks'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(await getAlcoholRating(d(15)), 1);

      // Now tap "No drinks" (value 0) to flip it.
      await tester.tap(find.text('No drinks'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(await getAlcoholRating(d(15)), 0);
    });

    testWidgets('entering a weight in the detail persists grams', (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // The WEIGHT field is the only TextField in the detail.
      await tester.enterText(find.byType(TextField), '80.5');
      await tester.pump(const Duration(milliseconds: 200));

      // 80.5 kg => 80500 grams (default unit is kg).
      expect(await getWeightGrams(d(15)), kgToGrams(80.5));
    });

    testWidgets(
        'weight field syncs to external changes and unfocuses on tap-outside',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      await setWeightGrams(d(15), kgToGrams(70.0));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // The detail weight field shows the seeded value.
      expect(find.widgetWithText(TextField, '70.0'), findsOneWidget);

      // Change the weight externally and reload: the field is unfocused, so
      // _CompactWeight.didUpdateWidget syncs the controller text to the new
      // value rather than fighting the user's edit.
      await setWeightGrams(d(15), kgToGrams(73.5));
      await seedAndReload(tester, key);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '73.5'), findsOneWidget);

      // Focus the field, then tap outside it: the TextField's onTapOutside
      // callback fires and unfocuses it. Tap a point just above the field —
      // on-screen (the field itself is on-screen and tappable) and inside the
      // app's TapRegionSurface, but outside the field's own tap region.
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      // Tap the AppBar title, far from the field and with no competing tap
      // handler, so the TapRegionSurface routes it to the field's onTapOutside.
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // The field still shows the synced value after the tap-outside.
      expect(find.widgetWithText(TextField, '73.5'), findsOneWidget);
    });

    testWidgets('clearing the weight field in the detail removes it',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      // Seed an existing weight on the 15th so there is something to clear.
      await setWeightGrams(d(15), kgToGrams(77.0));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(await getWeightGrams(d(15)), kgToGrams(77.0));

      // Emptying the WEIGHT field drives _setSelectedWeight(null) => clearWeight.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getWeightGrams(d(15)), isNull);
    });
  });

  group('completion editing (per-exercise toggles)', () {
    testWidgets('tapping an exercise row persists its atomic ids',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // The Daily 30 routine has a "100 Jumps in Place" exercise (single
      // atomic id 'jumps'). The exercise list sits below the day editors in
      // the ListView, so scroll the row into view before tapping it.
      final jumps = find.text('100 Jumps in Place');
      expect(jumps, findsOneWidget);
      await tester.ensureVisible(jumps);
      await tester.pumpAndSettle();
      await tester.tap(jumps);
      await tester.pump(const Duration(milliseconds: 200));

      final saved = await getCompletedExercises(d(15));
      expect(saved.contains('jumps'), isTrue);

      // Tapping again un-marks it (removes the atomic ids).
      await tester.ensureVisible(find.text('100 Jumps in Place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100 Jumps in Place'));
      await tester.pump(const Duration(milliseconds: 200));
      final after = await getCompletedExercises(d(15));
      expect(after.contains('jumps'), isFalse);
    });
  });

  group('heatmap reflects seeded ratings', () {
    testWidgets('weight measurement renders weight labels in the grid',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'weight',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      // 80.0 kg on the 15th.
      await setWeightGrams(d(15), kgToGrams(80.0));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // The grid cell for the 15th shows the weight value "80.0" instead of
      // the day number. The "View evolution chart" affordance also appears
      // because weights are non-empty.
      expect(find.text('80.0'), findsOneWidget);
      expect(find.text('View evolution chart'), findsOneWidget);
    });

    testWidgets('back-pain measurement keeps day numbers but paints cells',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'backpain',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      await setBackPainRating(d(15), 8);

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // Back pain doesn't replace the day number, so '15' is still shown.
      expect(find.text('15'), findsOneWidget);
      // Round-trip confirms the seeded rating is what the grid reads.
      expect(await getBackPainRating(d(15)), 8);
    });
  });

  group('quick-edit long-press sheet', () {
    testWidgets('long-pressing a day opens the quick editor and persists',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'backpain',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // Long-press day 15 — for a non-completion measurement this opens the
      // modal bottom sheet with just that measurement's editor.
      await tester.longPress(find.text('15'));
      await tester.pumpAndSettle();

      // The sheet shows the BACK PAIN editor.
      expect(find.text('BACK PAIN'), findsWidgets);

      // A medium-impact haptic fires when the sheet opens.
      expect(harness.hapticCalls, isNotEmpty);

      // Tap "5" in the sheet's back-pain row.
      await tester.tap(find.text('5').last);
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getBackPainRating(d(15)), 5);
    });

    testWidgets('long-press with p measurement opens P quick editor and persists',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'p',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.longPress(find.text('15'));
      await tester.pumpAndSettle();

      // The sheet shows the P editor (its label) and the +2..-2 chips.
      expect(find.text('P'), findsWidgets);
      await tester.tap(find.text('+1'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getPRating(d(15)), 1);
    });

    testWidgets('long-press with drinks measurement opens Drinks quick editor',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'drinks',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.longPress(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.text('DRINKS'), findsWidgets);
      // Two "Drinks" texts exist: the pill label (size 14) and the sheet chip
      // (size 13, weight 800). The chip renders last in the tree.
      await tester.tap(find.text('Drinks').last);
      await tester.pump(const Duration(milliseconds: 200));

      expect(await getAlcoholRating(d(15)), 1);
    });

    testWidgets('long-press with weight measurement opens Weight quick editor',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'weight',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.longPress(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.text('WEIGHT'), findsWidgets);

      // Enter a valid value while the sheet is mounted; this drives the weight
      // quick-edit onChange (persist + setState) live — the behavior under test.
      await tester.enterText(find.byType(TextField), '72.0');
      await tester.pump(const Duration(milliseconds: 200));
      expect(await getWeightGrams(d(15)), kgToGrams(72.0));

      // Empty the field while still mounted: the quick-edit onChange(null) path
      // clears the stored weight (and removes it from the in-memory map).
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 200));
      expect(await getWeightGrams(d(15)), isNull);

      // Leave the field holding a non-positive value. _CompactWeight._commit
      // rejects "<= 0" with an early return *before* calling onChange, so when
      // the editor disposes at teardown it does NOT fire the async setState on
      // its (by-then-defunct) StatefulBuilder — sidestepping that benign
      // teardown artifact while still exercising the reject branch.
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump(const Duration(milliseconds: 200));
      expect(await getWeightGrams(d(15)), isNull);
    });
  });

  group('measurement cell painting', () {
    testWidgets('p measurement paints a cell for a seeded p rating',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'p',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      await setPRating(d(15), 2);

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // The pill shows the p-rating measurement label and the day cell is
      // still numbered (p doesn't replace the day number).
      expect(find.text('p rating'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(await getPRating(d(15)), 2);
    });

    testWidgets('drinks measurement paints filled cells for seeded ratings',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'drinks',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      // 15th drank (>0 => red), 16th sober (0 => white).
      await setAlcoholRating(d(15), 1);
      await setAlcoholRating(d(16), 0);

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      expect(find.text('Drinks'), findsOneWidget);
      // Drinks doesn't replace the day number.
      expect(find.text('15'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(await getAlcoholRating(d(15)), 1);
      expect(await getAlcoholRating(d(16)), 0);
    });
  });

  group('measurement pill swipe right', () {
    testWidgets('swiping the pill right goes to the previous measurement',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      // Default is Completion; a rightward fling (positive x velocity) => prev,
      // which wraps to the last measurement (Weight).
      await tester.fling(
          find.text('Completion'), const Offset(300, 0), 1000);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Weight'), findsOneWidget);
      expect(await getCalendarMeasurement(), 'weight');
    });
  });

  group('settings navigation', () {
    testWidgets('tapping the settings action opens the settings screen',
        (tester) async {
      harness = await installTestHarness();
      await pumpScreen(tester, const CalendarScreen(), settle: true);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Returning from Settings re-runs _loadSessions() (the awaited reload
      // after the push resolves). Pop back and settle so that path executes.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Calendar'), findsOneWidget);
    });
  });

  group('weight evolution chart link', () {
    testWidgets('tapping View evolution chart pushes the weight chart screen',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_calendar_measurement': 'weight',
      });
      await setActiveRoutineId(daily30RoutineId);
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));
      await setWeightGrams(d(15), kgToGrams(80.0));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      final link = find.text('View evolution chart');
      expect(link, findsOneWidget);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.byType(WeightChartScreen), findsOneWidget);
    });
  });

  group('completed session detail and duration formatting', () {
    testWidgets('a session with a start time shows duration in detail and list',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      // A real session (startedAt set) on the 15th yields a non-null duration:
      // started 12:00:00, completed 12:05:30 => 5m 30s.
      await saveSession(Session(
        date: d(15),
        startedAt: '${d(15)}T12:00:00Z',
        completedAt: '${d(15)}T12:05:30Z',
        type: 'daily',
      ));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // The recent-sessions list renders the routine title with the duration
      // ("Daily 30 · 5m 30s") — formatDuration's m/s branch.
      expect(find.textContaining('5m 30s'), findsWidgets);

      // Opening the day detail surfaces the "Completed at … · … · took 5m 30s"
      // line for the session.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(find.textContaining('took 5m 30s'), findsOneWidget);
    });

    testWidgets('a sub-minute session formats duration in seconds only',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      // started 12:00:00, completed 12:00:45 => 45s (m == 0 branch).
      await saveSession(Session(
        date: d(10),
        startedAt: '${d(10)}T12:00:00Z',
        completedAt: '${d(10)}T12:00:45Z',
        type: 'daily',
      ));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      expect(find.textContaining('45s'), findsWidgets);
    });

    testWidgets('a whole-minute session formats duration in minutes only',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      // started 12:00:00, completed 12:03:00 => 3m (s == 0 branch).
      await saveSession(Session(
        date: d(11),
        startedAt: '${d(11)}T12:00:00Z',
        completedAt: '${d(11)}T12:03:00Z',
        type: 'daily',
      ));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      expect(find.textContaining('3m'), findsWidgets);
    });
  });

  group('retroactive session reconciliation', () {
    // The Daily 30 routine's full atomic-id set across all blocks.
    Set<String> daily30AtomicIds() {
      final routine = routineById(daily30RoutineId);
      return routine.blocks
          .expand((b) => b.exercises)
          .expand((e) => e.atomicIds)
          .toSet();
    }

    testWidgets(
        'completing the final exercise creates a retroactive session; '
        'un-completing removes it', (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      // Seed an earlier first session so the 15th counts as a tracked,
      // editable day.
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      // Pre-mark every atomic id for the 15th EXCEPT the single 'jumps' unit,
      // so a single toggle of the Jumps row pushes the day to "all done".
      final all = daily30AtomicIds();
      expect(all.contains('jumps'), isTrue);
      final allButJumps = {...all}..remove('jumps');
      await saveCompletedExercises(d(15), allButJumps);

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // No retroactive session yet for the 15th.
      final before = await getSessions();
      expect(before.any((s) => s.date == d(15)), isFalse);

      // Toggle the last remaining exercise => all done => session created.
      final jumps = find.text('100 Jumps in Place');
      await tester.ensureVisible(jumps);
      await tester.pumpAndSettle();
      await tester.tap(jumps);
      await tester.pump(const Duration(milliseconds: 200));

      final after = await getSessions();
      final created = after.where((s) => s.date == d(15)).toList();
      expect(created, hasLength(1));
      // Retroactive sessions carry no startedAt timestamp.
      expect(created.single.startedAt, isNull);

      // Toggle Jumps off again => no longer all done => the retroactive
      // session is removed.
      await tester.ensureVisible(find.text('100 Jumps in Place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100 Jumps in Place'));
      await tester.pump(const Duration(milliseconds: 200));

      final cleared = await getSessions();
      expect(cleared.any((s) => s.date == d(15)), isFalse);
    });
  });

  group('program routine (Hip & Lumbar Reset)', () {
    testWidgets(
        'program completion ratio paints the grid for a partially-done day',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_routine': hipLumbarResetRoutineId,
      });
      await setActiveRoutineId(hipLumbarResetRoutineId);
      // Anchor the program so week math (_blocksForDate program branch) runs.
      await setProgramStartDate(hipLumbarResetRoutineId,
          DateTime(pastYear, pastMonth, 1));
      // First session on the 1st so the 15th is a tracked, non-completed day
      // (drives the completionRatio program-blocks branch in the grid).
      await saveSession(Session(
          date: d(1), completedAt: '${d(1)}T12:00:00Z', type: 'daily'));

      // Mark one atomic id of week-1 blocks done for the 15th so the day has
      // a partial completion ratio (0 < ratio < 1).
      final week1Atomic = hipLumbarResetProgram
          .blocksForWeek(1)
          .expand((b) => b.exercises)
          .expand((e) => e.atomicIds)
          .toList();
      expect(week1Atomic, isNotEmpty);
      await saveCompletedExercises(d(15), {week1Atomic.first});

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);
      await navigateToPastMonth(tester);

      // The grid still renders the day number for the partially-filled cell.
      expect(find.text('15'), findsOneWidget);
      // Opening the detail confirms the program-derived exercise list renders.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Missed'), findsOneWidget);
    });

    testWidgets('future day in a program routine shows the upcoming week banner',
        (tester) async {
      harness = await installTestHarness(prefs: {
        'flexit_routine': hipLumbarResetRoutineId,
      });
      await setActiveRoutineId(hipLumbarResetRoutineId);
      // Program started ~3 weeks ago so a future day lands in a later week.
      final start = DateTime.now().subtract(const Duration(days: 20));
      await setProgramStartDate(hipLumbarResetRoutineId, start);
      await saveSession(Session(
          date: formatDate(start),
          completedAt: '${formatDate(start)}T12:00:00Z',
          type: 'daily'));

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      // Advance to next month so we can tap a definitely-future day.
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pump();

      // Day 15 of next month is in the future => Upcoming banner with the
      // program's week/phase/walk target.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Upcoming'), findsOneWidget);
      expect(find.textContaining('Week'), findsOneWidget);
      expect(find.textContaining('Walk:'), findsOneWidget);
    });
  });

  group('today detail', () {
    testWidgets('selecting today shows the bare in-progress banner',
        (tester) async {
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      // The current month is shown by default; tap today's day number.
      final todayDay = DateTime.now().day.toString();
      await tester.tap(find.text(todayDay).last);
      await tester.pumpAndSettle();

      // No exercise data yet => the plain "In progress" banner (no count).
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('selecting today with partial exercise data shows the count',
        (tester) async {
      final today = formatDate(DateTime.now());
      harness = await installTestHarness();
      await setActiveRoutineId(daily30RoutineId);
      // Mark one atomic id done for today so hasExerciseData is true and the
      // "In progress · X/Y done" banner renders.
      await saveCompletedExercises(today, {'jumps'});

      final key = GlobalKey<CalendarScreenState>();
      await pumpScreen(tester, CalendarScreen(key: key), settle: true);
      await seedAndReload(tester, key);

      final todayDay = DateTime.now().day.toString();
      await tester.tap(find.text(todayDay).last);
      await tester.pumpAndSettle();

      expect(find.textContaining('In progress ·'), findsOneWidget);
      expect(find.textContaining('done'), findsOneWidget);
    });
  });
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

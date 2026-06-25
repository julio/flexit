import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexit/screens/settings_screen.dart';
import 'package:flexit/data/storage.dart';
import 'package:flexit/data/daily_backup.dart';
import 'package:flexit/data/exercises.dart';
import 'package:flexit/main.dart' show themeIsDark;

import '../helpers/test_harness.dart';

/// Real-behavior widget tests for SettingsScreen.
///
/// The screen reads/writes SharedPreferences through `lib/data/storage.dart`
/// and the daily-backup module, drives the global `themeIsDark` notifier, and
/// opens dialogs / bottom sheets. Each test asserts both the resulting UI
/// change and the persisted prefs write.
void main() {
  late TestHarness h;

  // themeIsDark is a process-global ValueNotifier. Reset it before/after each
  // test so dark-mode assertions don't leak across cases.
  setUp(() {
    themeIsDark.value = true;
  });
  tearDown(() {
    themeIsDark.value = true;
    h.dispose();
  });

  group('Dark mode toggle', () {
    testWidgets('toggling off persists setDarkMode(false) and flips the switch',
        (tester) async {
      // Default getDarkMode() is true, so the switch starts on.
      h = await installTestHarness(prefs: {'flexit_dark_mode': true});
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      expect(find.byType(Switch), findsOneWidget);
      Switch sw() => tester.widget<Switch>(find.byType(Switch));
      expect(sw().value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 200));

      // UI flipped (the ValueListenableBuilder rebuilds off themeIsDark).
      expect(sw().value, isFalse);
      expect(themeIsDark.value, isFalse);
      // Persisted.
      expect(await getDarkMode(), isFalse);
    });

    testWidgets('toggling on from a light-seeded state persists true',
        (tester) async {
      h = await installTestHarness(prefs: {'flexit_dark_mode': false});
      themeIsDark.value = false; // mirror the seeded state
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      Switch sw() => tester.widget<Switch>(find.byType(Switch));
      expect(sw().value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 200));

      expect(sw().value, isTrue);
      expect(themeIsDark.value, isTrue);
      expect(await getDarkMode(), isTrue);
    });
  });

  group('Routine picker', () {
    testWidgets('all routine tiles render with the default selected',
        (tester) async {
      h = await installTestHarness();
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      expect(find.text('Daily PT'), findsOneWidget);
      expect(find.text('Hip & Lumbar Reset'), findsOneWidget);
      expect(find.text('Daily 30'), findsOneWidget);

      // Default routine is Daily PT -> its tile shows the checked radio; the
      // other two tiles show unchecked radios.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });

    testWidgets('selecting Daily 30 persists the active routine id and reloads',
        (tester) async {
      h = await installTestHarness();
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      expect(await getActiveRoutineId(), ptDailyRoutineId);

      await tester.tap(find.text('Daily 30'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(await getActiveRoutineId(), daily30RoutineId);

      // Daily 30 has timed + repped exercises, so those sections appear after
      // the reload — proof the reload actually swapped the active routine.
      // They live far down a scrollable ListView (lazily built), so scroll
      // them into view before asserting.
      await tester.scrollUntilVisible(find.text('TIMERS'), 300,
          maxScrolls: 30);
      expect(find.text('TIMERS'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('REPS'), 300, maxScrolls: 30);
      expect(find.text('REPS'), findsOneWidget);
    });

    testWidgets('selecting Hip & Lumbar Reset from Daily 30 switches back',
        (tester) async {
      h = await installTestHarness(prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      expect(await getActiveRoutineId(), daily30RoutineId);

      await tester.tap(find.text('Hip & Lumbar Reset'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(await getActiveRoutineId(), hipLumbarResetRoutineId);
      // HLR has no timer/rep exercises in its block list -> sections gone.
      expect(find.text('TIMERS'), findsNothing);
      expect(find.text('REPS'), findsNothing);
    });
  });

  group('Program start tile', () {
    testWidgets('shows for HLR when a start date exists, and opens a picker',
        (tester) async {
      h = await installTestHarness(prefs: {
        'flexit_routine': hipLumbarResetRoutineId,
        'flexit_program_start_$hipLumbarResetRoutineId': '2026-06-01',
      });
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      expect(find.text('Program start'), findsOneWidget);
      // Formatted "Jun 1, 2026 · Week N of 6" subtitle is present.
      expect(
        find.textContaining('Jun 1, 2026'),
        findsOneWidget,
      );

      // Tapping opens the date picker dialog.
      await tester.tap(find.text('Program start'));
      await tester.pumpAndSettle();
      expect(find.text('Program start date'), findsOneWidget); // helpText

      // Cancel — no write, no crash.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await getProgramStartDate(hipLumbarResetRoutineId),
          DateTime(2026, 6, 1));
    });

    testWidgets('not shown for Daily 30 (no program)', (tester) async {
      h = await installTestHarness(prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const SettingsScreen(), settle: true);
      expect(find.text('Program start'), findsNothing);
    });
  });

  group('Rep setting tile (Daily 30)', () {
    testWidgets('dragging the pull-ups slider right raises the persisted reps',
        (tester) async {
      h = await installTestHarness(prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      // pull-ups: default 5, min 1, max 15. Its tile is far down the list.
      await tester.scrollUntilVisible(find.text('Pull-Ups'), 300,
          maxScrolls: 30);
      expect(find.text('Pull-Ups'), findsOneWidget);
      expect(find.text('3 × 5 reps'), findsOneWidget);

      // The pull-ups slider is the descendant Slider of its tile Column.
      final pullUpsTile = find
          .ancestor(of: find.text('Pull-Ups'), matching: find.byType(Column))
          .first;
      final slider =
          find.descendant(of: pullUpsTile, matching: find.byType(Slider));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      // Drag far right -> value increases toward the max (15).
      await tester.drag(slider, const Offset(1000, 0));
      await tester.pump(const Duration(milliseconds: 200));

      // Pixel-exact slider results aren't deterministic across surfaces, so
      // assert the true property: the persisted value went up from the
      // default and stayed within [minReps, maxReps].
      final stored = await getRepsCount('pull-ups', 5);
      expect(stored, greaterThan(5),
          reason: 'dragging right raises the rep count');
      expect(stored, inInclusiveRange(1, 15));
      // The subtitle reflects the same stored value.
      expect(find.text('3 × $stored reps'), findsOneWidget);
    });

    testWidgets('dragging left lowers pull-ups toward minReps', (tester) async {
      h = await installTestHarness(prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_reps_pull-ups': 10,
      });
      await pumpScreen(tester, const SettingsScreen(), settle: true);
      await tester.scrollUntilVisible(find.text('Pull-Ups'), 300,
          maxScrolls: 30);
      expect(find.text('3 × 10 reps'), findsOneWidget);

      final pullUpsTile = find
          .ancestor(of: find.text('Pull-Ups'), matching: find.byType(Column))
          .first;
      final slider =
          find.descendant(of: pullUpsTile, matching: find.byType(Slider));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(-1000, 0));
      await tester.pump(const Duration(milliseconds: 200));

      final stored = await getRepsCount('pull-ups', 5);
      expect(stored, lessThan(10),
          reason: 'dragging left lowers the rep count');
      expect(stored, inInclusiveRange(1, 15));
      expect(find.text('3 × $stored reps'), findsOneWidget);
    });
  });

  group('Timer setting tile (Daily 30)', () {
    testWidgets('dragging the plank slider right raises the persisted seconds',
        (tester) async {
      h = await installTestHarness(prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      // plank default 60. Slider range is 15..300. Tile is far down the list.
      await tester.scrollUntilVisible(find.text('Plank'), 300, maxScrolls: 30);
      expect(find.text('Plank'), findsOneWidget);

      final plankTile = find
          .ancestor(of: find.text('Plank'), matching: find.byType(Column))
          .first;
      final slider =
          find.descendant(of: plankTile, matching: find.byType(Slider));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(2000, 0));
      await tester.pump(const Duration(milliseconds: 200));

      final stored = await getTimerSeconds('plank', 60);
      expect(stored, greaterThan(60),
          reason: 'dragging right raises the timer seconds');
      expect(stored, inInclusiveRange(15, 300));
    });
  });

  group('Back up to clipboard', () {
    testWidgets('exports JSON and shows a confirmation snackbar',
        (tester) async {
      h = await installTestHarness(prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_p_2026-06-01': 2,
      });
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      await tester.tap(find.text('Back up to clipboard'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('characters of backup to clipboard'),
          findsOneWidget);
    });
  });

  group('Restore from clipboard', () {
    testWidgets('empty clipboard reports "Clipboard is empty."',
        (tester) async {
      // Harness clipboard handler returns {'text': ''} -> empty path.
      h = await installTestHarness(prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      // The third routine tile pushed this button just past the bottom edge.
      // It's already built (lazily off-screen), so scrollUntilVisible no-ops —
      // ensureVisible scrolls the built widget into the viewport.
      await tester.ensureVisible(find.text('Restore from clipboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore from clipboard'));
      // _importFromClipboard awaits Clipboard.getData (method channel) before
      // showing the snackbar — settle to flush that async gap + the animation.
      await tester.pumpAndSettle();

      expect(find.text('Clipboard is empty.'), findsOneWidget);
    });
  });

  group('Daily backups bottom sheet', () {
    testWidgets('with no backups shows the empty-state message',
        (tester) async {
      h = await installTestHarness();
      await pumpScreen(tester, const SettingsScreen(), settle: true);

      // _showBackupsList() does real filesystem I/O (listBackups). In a
      // testWidgets body the fake-async clock never completes real-I/O
      // futures, so the tap that triggers it must run inside runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.text('Daily backups on device'));
        await tester.pump();
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('No backups yet'), findsOneWidget);
    });

    // NOTE: the file-backed flows of this sheet (list an existing backup, then
    // Cancel or confirm Restore) are intentionally NOT driven through the UI.
    // Tapping a backup entry pops the sheet and chains into showDialog →
    // (on Restore) restoreFromBackup's real filesystem I/O. Inside a
    // testWidgets body that runs on the fake-async clock, even with runAsync
    // wrapping the taps the pop+dialog+I/O sequence does not settle and hangs.
    // The actual behavior (listBackups + restoreFromBackup) is covered by the
    // plain `test()`s in the "Daily backup file I/O (data module)" group
    // below, which run in real async with no deadlock.
  });

  // Backup file I/O asserted directly against the data module (real async,
  // no fake-async deadlock). The screen's "Daily backups on device" action
  // calls exactly these functions.
  group('Daily backup file I/O (data module)', () {
    test('runDailyBackupIfNeeded writes a snapshot under the docs dir',
        () async {
      h = await installTestHarness(prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_reps_pull-ups': 9,
      });
      final path = await runDailyBackupIfNeeded(now: DateTime(2026, 6, 12));
      expect(path, isNotNull);
      final file = File(path!);
      expect(file.existsSync(), isTrue);
      // It landed under the harness docs dir / flexit_backups.
      expect(path, startsWith(h.docsDir.path));
      expect(path, contains('flexit_backups'));
      final contents = file.readAsStringSync();
      expect(contents, contains('flexit_reps_pull-ups'));
      expect(contents, contains('"value": 9'));
    });

    test('restoreFromBackup re-applies a wiped key', () async {
      h = await installTestHarness(prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_p_2026-06-01': 2,
      });
      final path = await runDailyBackupIfNeeded(now: DateTime(2026, 6, 13));
      expect(path, isNotNull);

      // Wipe the captured key, then restore from the backup.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('flexit_p_2026-06-01');
      expect(await getPRating('2026-06-01'), isNull);

      final backups = await listBackups();
      expect(backups, hasLength(1));
      final n = await restoreFromBackup(backups.first);
      expect(n, greaterThan(0));
      expect(await getPRating('2026-06-01'), 2);
    });
  });
}

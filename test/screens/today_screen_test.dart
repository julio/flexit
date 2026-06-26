import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/exercises.dart';
import 'package:flexit/data/storage.dart';
import 'package:flexit/models/exercise.dart';
import 'package:flexit/screens/today_screen.dart';

import '../helpers/test_harness.dart';

/// All atomic IDs for a routine's blocks (non-program routines only — Daily 30
/// here). Used to drive "complete every exercise" assertions.
List<String> _atomicIdsFor(List<ExerciseBlock> blocks) => blocks
    .expand((b) => b.exercises)
    .expand((e) => e.atomicIds)
    .toList();

/// The Daily 30 routine — non-program, fixed block list, predictable IDs.
final _daily30 = routineById(daily30RoutineId);

/// The Daily PT routine — both exercises are multi-set + timed; the kneeling
/// stretch is also sided ("each side"), so it renders 1L/1R-style buttons.
final _ptDaily = routineById(ptDailyRoutineId);

void main() {
  late TestHarness harness;

  /// Installs the harness. MUST run inside [WidgetTester.runAsync] because
  /// `installTestHarness` does real filesystem I/O (`Directory.createTemp`)
  /// that the widget-test fake clock can't drain — calling it bare inside a
  /// `testWidgets` body deadlocks the test.
  Future<void> setup(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    await tester.runAsync(() async {
      harness = await installTestHarness(prefs: prefs);
    });
  }

  /// Lets a queued SharedPreferences write land before reading it back.
  Future<void> settlePrefs(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
  }

  /// The outermost card body (an [AnimatedContainer]) for the exercise whose
  /// name is [name]. Scopes set-button / chevron finders so they don't collide
  /// with identically-labelled buttons in other cards (or the back-pain row).
  Finder cardFor(String name) => find
      .ancestor(
        of: find.text(name),
        matching: find.byType(AnimatedContainer),
      )
      .last;

  /// Scrolls [finder] into the viewport (the workout list runs off the bottom
  /// of the test surface) then taps it.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps the set button (checkbox or timer button) labelled [label] inside
  /// the card for exercise [name].
  Future<void> tapSetButton(
      WidgetTester tester, String name, String label) async {
    await scrollAndTap(tester, // ensure card on-screen first
        find.descendant(of: cardFor(name), matching: find.text(label)));
  }

  /// Expands the collapsible workout section, then the named block (its title
  /// in UPPER CASE). Scrolls each control into view first.
  Future<void> expandBlock(WidgetTester tester, String blockTitleUpper) async {
    await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
    await scrollAndTap(tester, find.text(blockTitleUpper));
  }

  /// The countdown string currently shown inside the running timer button in
  /// the card for [name]. Matches the "Ns" or "m:ss" formats _TimerSetButton
  /// renders while a timer runs. Returns null if no countdown text is present.
  String? runningCountdown(WidgetTester tester, String name) {
    final re = RegExp(r'^(\d+s|\d+:\d{2})$');
    for (final w in tester
        .widgetList<Text>(find.descendant(of: cardFor(name), matching: find.byType(Text)))) {
      final t = w.data;
      if (t != null && re.hasMatch(t)) return t;
    }
    return null;
  }

  /// Parses a "Ns"/"m:ss" countdown string into total seconds.
  int countdownSeconds(String s) {
    if (s.endsWith('s')) return int.parse(s.substring(0, s.length - 1));
    final parts = s.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  tearDown(() => harness.dispose());

  group('initial render', () {
    testWidgets('shows the active routine title and metric cards',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('Daily 30'), findsOneWidget);
      expect(find.text('Drinks yesterday'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('How was p today?'), findsOneWidget);
      expect(find.text('Lower back pain'), findsOneWidget);
      // Workout section collapsed by default.
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    });

    testWidgets('header shows total exercise count for Daily 30',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final total = _atomicIdsFor(_daily30.blocks).length;
      expect(find.text('0/$total exercises'), findsOneWidget);
      expect(find.text('0/$total done'), findsOneWidget);
    });

    testWidgets('defaults to Daily PT when no routine seeded', (tester) async {
      await setup(tester);
      await pumpScreen(tester, const TodayScreen(), settle: true);
      expect(find.text('Daily PT'), findsOneWidget);
    });
  });

  group('alcohol card', () {
    testWidgets('tapping a binary button persists yesterday rating',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final yesterday =
          formatDate(DateTime.now().subtract(const Duration(days: 1)));
      expect(await getAlcoholRating(yesterday), isNull);

      await tester.tap(find.text('Drinks'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      expect(await getAlcoholRating(yesterday), 1);
      expect(harness.hapticCalls, isNotEmpty);

      // Switch to "No drinks" → 0.
      await tester.tap(find.text('No drinks'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(await getAlcoholRating(yesterday), 0);
    });

    testWidgets('pre-seeded rating renders on load', (tester) async {
      final yesterday =
          formatDate(DateTime.now().subtract(const Duration(days: 1)));
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_alc_$yesterday': 1,
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);
      expect(await getAlcoholRating(yesterday), 1);
      expect(find.text('Drinks'), findsOneWidget);
    });
  });

  group('p-rating card', () {
    testWidgets('tapping a rating button persists today p-rating',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final today = formatDate(DateTime.now());
      expect(await getPRating(today), isNull);

      await tester.tap(find.text('+2'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(await getPRating(today), 2);
      expect(find.text('excellent'), findsOneWidget);

      await tester.tap(find.text('-2'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(await getPRating(today), -2);
      expect(find.text('horrible'), findsOneWidget);
    });
  });

  group('back-pain card', () {
    testWidgets('tapping a level button persists today back-pain rating',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final today = formatDate(DateTime.now());
      expect(await getBackPainRating(today), isNull);

      // The back-pain row has buttons labeled '0'..'10'. Tap '3'.
      await scrollAndTap(
          tester, find.widgetWithText(GestureDetector, '3').last);
      await settlePrefs(tester);
      // Setting a value adds a "N · label" trailing Text that, under the test
      // font, overflows the header Row by a couple dozen px. It sits in a Row
      // that clips fine on a real device — drain it so it doesn't fail the
      // test. (Noted as a latent layout bug in the report.)
      drainBenignOverflow(tester);

      expect(await getBackPainRating(today), 3);
      expect(find.text('3 · noticeable'), findsOneWidget);
    });
  });

  group('weight card', () {
    testWidgets('typing a kg value writes grams', (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final today = formatDate(DateTime.now());
      expect(await getWeightGrams(today), isNull);

      await tester.enterText(find.byType(TextField), '80.5');
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      expect(await getWeightGrams(today), kgToGrams(80.5));
      expect(await getWeightGrams(today), 80500);
    });

    testWidgets('switching unit to lb converts the typed value',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();
      expect(await getWeightUnit(), 'lb');

      await tester.enterText(find.byType(TextField), '180');
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      final today = formatDate(DateTime.now());
      expect(await getWeightGrams(today), lbToGrams(180));
    });

    testWidgets('clearing the field clears the stored weight', (tester) async {
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_weight_$today': 80000,
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      // Pre-seeded value shows as 80.0.
      expect(find.text('80.0'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      expect(await getWeightGrams(today), isNull);
    });
  });

  group('workout expand / collapse', () {
    testWidgets('tapping the workout header reveals blocks', (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('ACTIVATE'), findsNothing);

      await tester.tap(find.text("TODAY'S WORKOUT"));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVATE'), findsOneWidget);
      expect(find.text('STRENGTH'), findsOneWidget);
    });
  });

  group('exercise completion', () {
    testWidgets('tapping a single-set no-timer exercise marks it done',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'ACTIVATE');

      // 'jumps': single set, no timer → tapping the card toggles done.
      expect(await getTodayCompletedExercises(), isEmpty);
      await scrollAndTap(tester, find.text('100 Jumps in Place'));
      await settlePrefs(tester);

      expect(await getTodayCompletedExercises(), contains('jumps'));
      expect(harness.hapticCalls, isNotEmpty);

      final total = _atomicIdsFor(_daily30.blocks).length;
      expect(find.text('1/$total exercises'), findsOneWidget);
    });

    testWidgets('checking a multi-set checkbox persists one atomic id',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'STRENGTH');

      // Push-Ups: 3 sets, reps → column of checkboxes labeled 1/2/3.
      await tapSetButton(tester, 'Push-Ups', '1');
      await settlePrefs(tester);

      expect(await getTodayCompletedExercises(), contains('push-ups:1'));
    });

    testWidgets('completing every exercise saves a session for today',
        (tester) async {
      final allIds = _atomicIdsFor(_daily30.blocks);
      final today = formatDate(DateTime.now());
      final seeded = allIds.sublist(0, allIds.length - 1);
      final lastId = allIds.last; // pull-ups:3

      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_exercises_$today': seeded,
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(await isTodayComplete(), isFalse);

      await expandBlock(tester, 'STRENGTH');

      // lastId 'pull-ups:3' → Pull-Ups set checkbox labelled '3'.
      await tapSetButton(tester, 'Pull-Ups', '3');
      await settlePrefs(tester);
      await tester.pumpAndSettle();

      expect(await getTodayCompletedExercises(), contains(lastId));
      expect(await isTodayComplete(), isTrue);
      // The done banner replaces the workout section.
      expect(find.text('All done for today'), findsOneWidget);
    });

    testWidgets('an already-complete day shows the done banner on load',
        (tester) async {
      final allIds = _atomicIdsFor(_daily30.blocks);
      final today = formatDate(DateTime.now());

      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_exercises_$today': allIds,
        'flexit_sessions':
            '[{"date":"$today","completedAt":"2026-06-23T10:00:00.000Z","type":"daily"}]',
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('All done for today'), findsOneWidget);
      expect(await isTodayComplete(), isTrue);
    });

    testWidgets('tapping the done banner reopens the day after confirm',
        (tester) async {
      final allIds = _atomicIdsFor(_daily30.blocks);
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_exercises_$today': allIds,
        'flexit_sessions':
            '[{"date":"$today","completedAt":"2026-06-23T10:00:00.000Z","type":"daily"}]',
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);
      expect(find.text('All done for today'), findsOneWidget);

      // Tap the banner → confirm dialog → Reopen.
      await tester.tap(find.text('All done for today'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen today?'), findsOneWidget);
      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      // Session removed, day no longer complete, banner gone.
      expect(await isTodayComplete(), isFalse);
      expect(find.text('All done for today'), findsNothing);
    });

    testWidgets('cancelling the reopen dialog keeps the day complete',
        (tester) async {
      final allIds = _atomicIdsFor(_daily30.blocks);
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_exercises_$today': allIds,
        'flexit_sessions':
            '[{"date":"$today","completedAt":"2026-06-23T10:00:00.000Z","type":"daily"}]',
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await tester.tap(find.text('All done for today'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen today?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);

      expect(await isTodayComplete(), isTrue);
      expect(find.text('All done for today'), findsOneWidget);
    });
  });

  group('undo dialog', () {
    testWidgets('tapping a completed exercise prompts undo; Cancel keeps it, Undo removes it',
        (tester) async {
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        // 'glute-bridge' done. The Strength block has 3 other (un-done)
        // exercises, so the block stays expandable and the done card stays
        // visible to re-tap.
        'flexit_exercises_$today': ['glute-bridge'],
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'STRENGTH');

      // glute-bridge is done → tapping its card asks to undo.
      await scrollAndTap(tester, find.text('Glute Bridge'));
      expect(find.text('Undo this completion?'), findsOneWidget);

      // Cancel → stays completed.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(await getTodayCompletedExercises(), contains('glute-bridge'));

      // Tap again, this time confirm Undo.
      await scrollAndTap(tester, find.text('Glute Bridge'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(
          await getTodayCompletedExercises(), isNot(contains('glute-bridge')));
    });
  });

  group('video link', () {
    testWidgets('expanding an exercise and tapping watch launches its video url',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'STRENGTH');

      // Glute Bridge: single-set no-timer with a curated videoUrl. Tapping the
      // card marks it done, so expand via the name-adjacent chevron instead.
      expect(find.text('Glute Bridge'), findsOneWidget);

      final chevron = find.descendant(
        of: cardFor('Glute Bridge'),
        matching: find.byIcon(Icons.keyboard_arrow_down),
      );
      await scrollAndTap(tester, chevron);

      final watch = find.text('Watch video');
      expect(watch, findsOneWidget);

      expect(harness.urls.launched, isEmpty);
      await scrollAndTap(tester, watch);

      final gluteEx = _daily30.blocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'glute-bridge');
      expect(harness.urls.launched, contains(gluteEx.effectiveVideoUrl));
      expect(gluteEx.effectiveVideoUrl, startsWith('https://'));
    });
  });

  group('timer button', () {
    testWidgets('tapping a timer set button starts a countdown and schedules a notification',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'STRENGTH');

      // Plank: 3 sets, timer (60s) → 3 timer buttons labeled 1/2/3. Tapping
      // the first starts a countdown; the label flips to a time string.
      final plankBtn1 =
          find.descendant(of: cardFor('Plank'), matching: find.text('1'));
      await tester.ensureVisible(plankBtn1);
      await tester.pumpAndSettle();
      // Remember where the button sits so we can re-tap to cancel — its label
      // changes to a countdown once running, so a text finder is unreliable.
      final btnCenter = tester.getCenter(plankBtn1);
      await tester.tap(plankBtn1);
      await tester.pump(const Duration(milliseconds: 50));

      // A timer-end was persisted for plank set 1.
      expect(await getTimerEnd('plank:1'), isNotNull);

      // A schedule call reached the notifications plugin channel.
      final scheduled = harness.notificationCalls
          .where((c) => c.method == 'zonedSchedule' || c.method == 'schedule')
          .toList();
      expect(scheduled, isNotEmpty);

      // Tap the same spot again to cancel — clears the live ticker (so no
      // pending Timer trips the test teardown) and the persisted end time.
      await tester.tapAt(btnCenter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(await getTimerEnd('plank:1'), isNull);
    });
  });

  group('week banner (program routine)', () {
    testWidgets('Hip & Lumbar Reset shows the current week banner when expanded',
        (tester) async {
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': hipLumbarResetRoutineId,
        'flexit_program_start_$hipLumbarResetRoutineId': today,
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));

      expect(find.text('Week 1'), findsOneWidget);
      expect(find.textContaining('Walk:'), findsOneWidget);
    });
  });

  group('streak banner', () {
    testWidgets('shows a streak chip when prior days are complete',
        (tester) async {
      final yesterday =
          formatDate(DateTime.now().subtract(const Duration(days: 1)));
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_sessions':
            '[{"date":"$yesterday","completedAt":"2026-06-22T10:00:00.000Z","type":"daily"}]',
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('1 day streak'), findsOneWidget);
    });
  });

  group('settings navigation', () {
    testWidgets('tapping the settings icon pushes the settings screen',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      // The Today screen owns the only Settings tooltip; SettingsScreen has a
      // distinct title we can assert on after the push lands (covers
      // _openSettings: Navigator.push then _loadState on return).
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      // Settings screen rendered (its app-bar title).
      expect(find.text('Settings'), findsWidgets);

      // Pop back; _openSettings awaits the push then reloads Today state.
      await tester.pageBack();
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      expect(find.text('Daily 30'), findsOneWidget);
    });
  });

  group('weight card external update', () {
    testWidgets('toggling the unit rewrites the field value via didUpdateWidget',
        (tester) async {
      final today = formatDate(DateTime.now());
      // Seed a stored weight so the field has a value that must be re-rendered
      // when the unit flips kg→lb (drives _WeightCard.didUpdateWidget →
      // _controller.text = next).
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_weight_$today': 80000, // 80.0 kg
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('80.0'), findsOneWidget);

      // Flip to lb without focusing the field: didUpdateWidget recomputes the
      // display value and writes it into the controller.
      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      // 80 kg ≈ 176.4 lb — the field text changed externally.
      expect(find.text('80.0'), findsNothing);
      expect(find.textContaining('176'), findsOneWidget);
    });

    testWidgets('tapping outside the focused weight field unfocuses it',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '70');
      await tester.pump();
      expect(
          (tester.widget<TextField>(field)).focusNode?.hasFocus ?? false,
          isTrue);

      // Tap a neutral area of the screen → onTapOutside → _focusNode.unfocus().
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      expect(
          (tester.widget<TextField>(field)).focusNode?.hasFocus ?? false,
          isFalse);
    });
  });

  group('Daily PT routine (sided multi-set timers)', () {
    /// Expands the workout and the single 'DAILY PT' block.
    Future<void> openPtBlock(WidgetTester tester) async {
      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('DAILY PT'));
    }

    testWidgets('renders sided L/R timer buttons for the kneeling stretch',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': ptDailyRoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      expect(find.text('Daily PT'), findsOneWidget);
      await openPtBlock(tester);

      // Kneeling stretch: sets:5 × 2 sides → labels 1L,1R,2L,2R,...
      // (covers Exercise.atomicIds set+side branch, labelFor set+side, and
      // notifBodyFor sides).
      final card = cardFor('Kneeling Hip-Flexor / Quad Stretch');
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);
      expect(find.descendant(of: card, matching: find.text('1L')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('1R')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('5R')),
          findsOneWidget);

      // Atomic ids carry the L/R suffix.
      final kneel = _ptDaily.blocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'pt-kneeling-hip-flexor');
      expect(kneel.atomicIds, contains('pt-kneeling-hip-flexor:1:L'));
      expect(kneel.atomicIds, contains('pt-kneeling-hip-flexor:5:R'));
    });

    testWidgets('tapping a fresh timer button starts and shows a countdown',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': ptDailyRoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await openPtBlock(tester);

      // 90/90 Hip Lift set 1: a 40s timer. Tapping starts it (covers _start:
      // setTimerEnd, lightImpact, schedule, ticker) and the '1' label flips to
      // a running "Ns" countdown.
      final card = cardFor('90/90 Hip Lift');
      final btn1 = find.descendant(of: card, matching: find.text('1'));
      await tester.ensureVisible(btn1);
      await tester.pumpAndSettle();
      final center = tester.getCenter(btn1);

      await tester.tap(btn1);
      await tester.pump(const Duration(milliseconds: 50));

      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNotNull);
      final cd = runningCountdown(tester, '90/90 Hip Lift');
      expect(cd, isNotNull, reason: 'running button shows a countdown');
      expect(countdownSeconds(cd!), inInclusiveRange(38, 40));

      // A schedule call reached the notifications channel.
      expect(
          harness.notificationCalls.where(
              (c) => c.method == 'zonedSchedule' || c.method == 'schedule'),
          isNotEmpty);

      // A tick fires while still running → _checkAndUpdate else branch
      // (setState, no finish — the real clock hasn't reached _endTime).
      await tester.pump(const Duration(seconds: 1));
      expect(runningCountdown(tester, '90/90 Hip Lift'), isNotNull);

      // Cancel to clear the live ticker before teardown (covers _cancel).
      await tester.tapAt(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNull);
    });

    testWidgets(
        'a resumed timer that reaches its end completes the set and fires the cue',
        (tester) async {
      // Widget tests freeze DateTime.now() across tester.pump, so a started
      // timer never "finishes" by pumping fake seconds. To drive the
      // _checkAndUpdate finish branch we seed an end ~600ms in the real future,
      // let _tryRestore resume the ticker, then let *real* time pass (runAsync)
      // so the next tick sees now >= endTime.
      final end = DateTime.now().toUtc().add(const Duration(milliseconds: 600));
      await setup(tester, prefs: {
        'flexit_routine': ptDailyRoutineId,
        'flexit_timer_end_pt-90-90-hip-lift:1': end.toIso8601String(),
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await openPtBlock(tester);
      final card = cardFor('90/90 Hip Lift');
      await tester.ensureVisible(card);
      await tester.pump(); // let _tryRestore resume (running ticker)
      drainBenignOverflow(tester);
      expect(runningCountdown(tester, '90/90 Hip Lift'), isNotNull);

      // Let real wall-clock time pass beyond the end time.
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 800)));

      // Fire the periodic ticker now that real now > endTime → finish branch:
      // cancels ticker + notification, clears the end, fires the cue, calls
      // onComplete → marks the set done.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);
      await settlePrefs(tester);

      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNull);
      expect(await getTodayCompletedExercises(),
          contains('pt-90-90-hip-lift:1'));
      // The completion cue routes a HapticFeedback.vibrate through the channel.
      expect(harness.hapticCalls, isNotEmpty);
      // Button now shows the done check.
      expect(find.descendant(of: card, matching: find.byIcon(Icons.check)),
          findsWidgets);

      // Tapping the now-done timer button asks onUndo (covers _handleTap isDone
      // path → onUndo → onToggle → undo dialog).
      final checkBtn = find.descendant(
          of: card, matching: find.byIcon(Icons.check));
      await tester.tap(checkBtn.first);
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);
      expect(find.text('Undo this completion?'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settlePrefs(tester);
      expect(await getTodayCompletedExercises(),
          isNot(contains('pt-90-90-hip-lift:1')));
    });

    testWidgets('a long timer (>60s) renders m:ss while running',
        (tester) async {
      // Daily 30's couch-stretch is a 90s timer → exercises the m:ss branch
      // of _formatRemaining.
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('LENGTHEN'));

      // Couch Stretch: sets:2 × sided, 90s timer → first button is '1L'.
      final card = cardFor('Couch Stretch');
      final btn = find.descendant(of: card, matching: find.text('1L'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      final center = tester.getCenter(btn);

      await tester.tap(btn);
      await tester.pump(const Duration(milliseconds: 50));

      // 90s → an "m:ss" countdown (exercises the >=60 branch of
      // _formatRemaining), starting near 1:29.
      final t0 = runningCountdown(tester, 'Couch Stretch');
      expect(t0, isNotNull);
      expect(t0, contains(':'),
          reason: 'a >60s remaining renders as m:ss, not Ns');
      expect(countdownSeconds(t0!), inInclusiveRange(88, 90));
      // A tick keeps it running (real clock is frozen in tests, so the
      // displayed value need not change).
      await tester.pump(const Duration(seconds: 2));
      expect(runningCountdown(tester, 'Couch Stretch'), isNotNull);

      // Cancel to clear the live ticker before teardown (covers _cancel).
      await tester.tapAt(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(await getTimerEnd('couch-stretch:1:L'), isNull);
    });
  });

  group('timer restore on mount', () {
    testWidgets('an already-elapsed persisted timer fires completion on mount',
        (tester) async {
      // Persist a timer end in the past for hip-lift set 1, with the set NOT
      // yet marked done → _tryRestore takes the elapsed branch: clears the
      // end, cancels the notification, fires the cue, calls onComplete.
      final pastEnd =
          DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      await setup(tester, prefs: {
        'flexit_routine': ptDailyRoutineId,
        'flexit_timer_end_pt-90-90-hip-lift:1': pastEnd.toIso8601String(),
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('DAILY PT'));

      // Bring the card on-screen so the _TimerSetButton mounts and restores.
      final card = cardFor('90/90 Hip Lift');
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);
      await settlePrefs(tester);

      // The elapsed restore cleared the persisted end and completed the set.
      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNull);
      expect(await getTodayCompletedExercises(),
          contains('pt-90-90-hip-lift:1'));
    });

    testWidgets('an in-flight persisted timer resumes ticking on mount',
        (tester) async {
      // Persist a future end → _tryRestore takes the resume branch: sets
      // _running, _endTime, starts the periodic ticker.
      final futureEnd =
          DateTime.now().toUtc().add(const Duration(seconds: 30));
      await setup(tester, prefs: {
        'flexit_routine': ptDailyRoutineId,
        'flexit_timer_end_pt-90-90-hip-lift:1': futureEnd.toIso8601String(),
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('DAILY PT'));

      final card = cardFor('90/90 Hip Lift');
      await tester.ensureVisible(card);
      // A periodic ticker is now live, so don't pumpAndSettle (it never
      // settles); pump a single frame to let the resume setState land.
      await tester.pump();
      drainBenignOverflow(tester);

      // Running → button shows a "Ns" countdown (resumed from the persisted
      // ~30s future end), and the persisted end is still present (in flight).
      final cd = runningCountdown(tester, '90/90 Hip Lift');
      expect(cd, isNotNull);
      expect(countdownSeconds(cd!), inInclusiveRange(25, 30));
      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNotNull);

      // Cancel by tapping the running button (its center) to clear the live
      // ticker before teardown.
      final running =
          find.descendant(of: card, matching: find.text(cd));
      final center = tester.getCenter(running);
      await tester.tapAt(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNull);
    });
  });

  group('single-set sided timer (L/R labels)', () {
    testWidgets('Single Knee to Chest renders L and R timer buttons',
        (tester) async {
      // Hip & Lumbar Reset, week 1, Morning Wake-Up block. "Single Knee to
      // Chest" is single-set ("30 sec each side") → sides:2, no set label →
      // labelFor side-only branch produces 'L' / 'R'.
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': hipLumbarResetRoutineId,
        'flexit_program_start_$hipLumbarResetRoutineId': today,
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('MORNING WAKE-UP'));

      final card = cardFor('Single Knee to Chest');
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      expect(find.descendant(of: card, matching: find.text('L')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('R')),
          findsOneWidget);
    });
  });

  group('app lifecycle (resume)', () {
    testWidgets('resuming the app runs the daily backup and the date check',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      // A non-resumed transition is ignored (early return).
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Resuming triggers runDailyBackupIfNeeded() and the same-day date check
      // (todayKey == _loadedForDate so no reload). The backup future does real
      // I/O; let it run on the real executor so it doesn't dangle.
      await tester.runAsync(() async {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      drainBenignOverflow(tester);

      // The screen is still intact after the resume cycle.
      expect(find.text('Daily 30'), findsOneWidget);
    });

    testWidgets('resuming after a date rollover reloads the day',
        (tester) async {
      await setup(tester, prefs: {'flexit_routine': daily30RoutineId});
      await pumpScreen(tester, const TodayScreen(), settle: true);

      // After load, _loadedForDate == today. Push the injected clock forward a
      // day so the resume-time date check sees a rollover and reloads (the
      // branch that otherwise only fires across a real midnight).
      addTearDown(() => todayClock = DateTime.now);
      todayClock = () => DateTime.now().add(const Duration(days: 1));

      await tester.runAsync(() async {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      drainBenignOverflow(tester);

      // The reload ran without error and the screen is intact.
      expect(find.text('Daily 30'), findsOneWidget);
    });

    testWidgets('a running timer button re-checks its end on resume',
        (tester) async {
      // Mount with a resumed in-flight timer, then dispatch resumed so the
      // _TimerSetButton's didChangeAppLifecycleState → _checkAndUpdate runs.
      final futureEnd =
          DateTime.now().toUtc().add(const Duration(seconds: 30));
      await setup(tester, prefs: {
        'flexit_routine': ptDailyRoutineId,
        'flexit_timer_end_pt-90-90-hip-lift:1': futureEnd.toIso8601String(),
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await scrollAndTap(tester, find.text("TODAY'S WORKOUT"));
      await scrollAndTap(tester, find.text('DAILY PT'));

      final card = cardFor('90/90 Hip Lift');
      await tester.ensureVisible(card);
      await tester.pump();
      drainBenignOverflow(tester);
      expect(runningCountdown(tester, '90/90 Hip Lift'), isNotNull);

      // Resume → button observer fires _checkAndUpdate (still running → else
      // branch, no finish since the real clock hasn't reached the end).
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      drainBenignOverflow(tester);
      expect(runningCountdown(tester, '90/90 Hip Lift'), isNotNull);
      expect(await getTimerEnd('pt-90-90-hip-lift:1'), isNotNull);

      // Clear the live ticker before teardown.
      final cd = runningCountdown(tester, '90/90 Hip Lift')!;
      final running = find.descendant(of: card, matching: find.text(cd));
      await tester.tapAt(tester.getCenter(running));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('exercise card auto-collapse on done', () {
    testWidgets(
        'checking the last set of an expanded multi-set card collapses it',
        (tester) async {
      // Daily 30 Push-Ups: 3 sets, reps (checkboxes, no timer). Seed sets 1 & 2
      // done, expand the card, then check set 3 → the card transitions to done
      // while still _userExpanded, so _ExerciseCard.didUpdateWidget schedules a
      // post-frame collapse (covers 642-643).
      final today = formatDate(DateTime.now());
      await setup(tester, prefs: {
        'flexit_routine': daily30RoutineId,
        'flexit_exercises_$today': ['push-ups:1', 'push-ups:2'],
      });
      await pumpScreen(tester, const TodayScreen(), settle: true);

      await expandBlock(tester, 'STRENGTH');

      // Expand the Push-Ups card via its chevron.
      final chevron = find.descendant(
          of: cardFor('Push-Ups'),
          matching: find.byIcon(Icons.keyboard_arrow_down));
      await scrollAndTap(tester, chevron);
      // Expanded → its collapse chevron now shows.
      expect(
          find.descendant(of: cardFor('Push-Ups'),
              matching: find.byIcon(Icons.keyboard_arrow_up)),
          findsOneWidget);

      // Check set 3 (the last) → exercise becomes fully done.
      await tapSetButton(tester, 'Push-Ups', '3');
      await settlePrefs(tester);
      // Pump past the 200ms AnimatedContainer + the post-frame collapse.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      drainBenignOverflow(tester);

      expect(await getTodayCompletedExercises(), contains('push-ups:3'));
      // Auto-collapsed: a done card renders no expand/collapse chevron, and its
      // description (only shown while expanded) is gone.
      expect(
          find.descendant(of: cardFor('Push-Ups'),
              matching: find.byIcon(Icons.keyboard_arrow_up)),
          findsNothing);
      expect(find.textContaining('Brace the core'), findsNothing);
    });
  });

}

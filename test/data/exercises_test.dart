import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/exercises.dart';
import 'package:flexit/models/exercise.dart';
import 'package:flexit/models/program.dart';

void main() {
  group('dailyBlocks', () {
    test('has 5 blocks', () {
      expect(dailyBlocks.length, 5);
    });

    test('activate block has 1 exercise', () {
      expect(dailyBlocks[0].exercises.length, 1);
    });

    test('all exercises have required fields', () {
      for (final block in dailyBlocks) {
        for (final exercise in block.exercises) {
          expect(exercise.id, isNotEmpty);
          expect(exercise.name, isNotEmpty);
          expect(exercise.duration, isNotEmpty);
          expect(exercise.description, isNotEmpty);
          expect(exercise.cue, isNotEmpty);
        }
      }
    });

    test('any video urls use https', () {
      for (final block in dailyBlocks) {
        for (final exercise in block.exercises) {
          if (exercise.videoUrl != null) {
            expect(exercise.videoUrl, startsWith('https://'));
          }
        }
      }
    });

    test('total daily exercises is 11', () {
      final total =
          dailyBlocks.fold<int>(0, (sum, b) => sum + b.exercises.length);
      expect(total, 11);
    });

    test('push-ups and plank have 3 sets each', () {
      final pushUps = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'push-ups');
      final plank = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'plank');
      expect(pushUps.sets, 3);
      expect(plank.sets, 3);
      expect(pushUps.atomicIds, ['push-ups:1', 'push-ups:2', 'push-ups:3']);
      expect(plank.atomicIds, ['plank:1', 'plank:2', 'plank:3']);
    });

    test('single-set exercises have atomic id equal to id', () {
      for (final e in dailyBlocks.expand((b) => b.exercises)) {
        if (e.sets == 1) {
          expect(e.atomicIds, [e.id]);
        }
      }
    });

    test('plank has a 60-second default timer', () {
      final plank = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'plank');
      expect(plank.timer, isNotNull);
      expect(plank.timer!.settingKey, 'plank');
      expect(plank.timer!.defaultSeconds, 60);
    });

    test('couch stretch has 2 sets with a 90-second default timer', () {
      final couch = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'couch-stretch');
      expect(couch.sets, 2);
      expect(couch.timer, isNotNull);
      expect(couch.timer!.settingKey, 'couch-stretch');
      expect(couch.timer!.defaultSeconds, 90);
      // "90 sec per side" → 2 sides × 2 sets = 4 atomic IDs
      expect(couch.atomicIds, [
        'couch-stretch:1:L',
        'couch-stretch:1:R',
        'couch-stretch:2:L',
        'couch-stretch:2:R',
      ]);
    });

    test('pigeon pose has 2 sets with a 90-second default timer', () {
      final pigeon = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'pigeon');
      expect(pigeon.sets, 2);
      expect(pigeon.timer, isNotNull);
      expect(pigeon.timer!.settingKey, 'pigeon');
      expect(pigeon.timer!.defaultSeconds, 90);
    });

    test('push-ups has a 20-rep default rep spec', () {
      final pushUps = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'push-ups');
      expect(pushUps.reps, isNotNull);
      expect(pushUps.reps!.settingKey, 'push-ups');
      expect(pushUps.reps!.defaultReps, 20);
    });

    test('pull-ups replaces dead-hang with a 5-rep default rep spec', () {
      final all =
          dailyBlocks.expand((b) => b.exercises).map((e) => e.id).toSet();
      expect(all.contains('dead-hang'), isFalse);
      expect(all.contains('pull-ups'), isTrue);
      final pullUps = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'pull-ups');
      expect(pullUps.sets, 3);
      expect(pullUps.reps, isNotNull);
      expect(pullUps.reps!.settingKey, 'pull-ups');
      expect(pullUps.reps!.defaultReps, 5);
      expect(pullUps.reps!.minReps, 1);
      expect(pullUps.reps!.maxReps, 15);
    });

    test('push-ups uses default rep bounds (5–50)', () {
      final pushUps = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'push-ups');
      expect(pushUps.reps!.minReps, 5);
      expect(pushUps.reps!.maxReps, 50);
    });
  });

  group('routines', () {
    test('exposes Daily 30 and Hip & Lumbar Reset', () {
      final ids = routines.map((r) => r.id).toSet();
      expect(ids, {daily30RoutineId, hipLumbarResetRoutineId});
    });

    test('default routine is Hip & Lumbar Reset', () {
      expect(defaultRoutineId, hipLumbarResetRoutineId);
    });

    test('routineById falls back to first routine for unknown ids', () {
      expect(routineById('not-a-routine').id, routines.first.id);
    });

    test('routineById returns the matching routine', () {
      expect(routineById(daily30RoutineId).blocks, dailyBlocks);
      expect(routineById(hipLumbarResetRoutineId).blocks, hipLumbarResetBlocks);
    });
  });

  group('hipLumbarResetBlocks', () {
    test('has 5 blocks (Wake-Up, Decompress, Mobilize, Strengthen, Cool Down)',
        () {
      expect(hipLumbarResetBlocks.length, 5);
      expect(hipLumbarResetBlocks.map((b) => b.title).toList(), [
        'Morning Wake-Up',
        'A. Decompress',
        'B. Mobilize',
        'C. Strengthen',
        'D. Cool Down',
      ]);
    });

    test('all exercises have required fields and hlr- prefix', () {
      for (final block in hipLumbarResetBlocks) {
        for (final exercise in block.exercises) {
          expect(exercise.id, startsWith('hlr-'));
          expect(exercise.name, isNotEmpty);
          expect(exercise.duration, isNotEmpty);
          expect(exercise.description, isNotEmpty);
          expect(exercise.cue, isNotEmpty);
        }
      }
    });

    test('no ID collisions with Daily 30', () {
      final daily30Ids =
          dailyBlocks.expand((b) => b.exercises).map((e) => e.id).toSet();
      final hlrIds = hipLumbarResetBlocks
          .expand((b) => b.exercises)
          .map((e) => e.id)
          .toSet();
      expect(daily30Ids.intersection(hlrIds), isEmpty);
    });

    test('strength block exercises all have sets > 1', () {
      final strength =
          hipLumbarResetBlocks.firstWhere((b) => b.title == 'C. Strengthen');
      for (final e in strength.exercises) {
        expect(e.sets, greaterThan(1),
            reason: '${e.id} should be multi-set in the strengthen block');
      }
    });

    test('total exercises in the Week-1 view', () {
      // Block B (Mobilize) gained the anterior-hip release and the 90/90 IR
      // lift-off after the critique panel; Week-1 strength stayed the same
      // 6 exercises. 6 wake-up + 8 mobilize + 6 strength + 4 cool-down = 24.
      final total = hipLumbarResetBlocks.fold<int>(
          0, (sum, b) => sum + b.exercises.length);
      expect(total, 24);
    });
  });

  group('hipLumbarResetProgram', () {
    test('has 6 weeks', () {
      expect(hipLumbarResetProgram.weeks.length, 6);
      expect(hipLumbarResetProgram.weeks.map((w) => w.weekNumber),
          [1, 2, 3, 4, 5, 6]);
    });

    test('routine wires the program in', () {
      final routine = routineById(hipLumbarResetRoutineId);
      expect(routine.hasProgram, isTrue);
      expect(routine.program, hipLumbarResetProgram);
    });

    test('Daily 30 has no program', () {
      expect(routineById(daily30RoutineId).hasProgram, isFalse);
    });

    test('currentWeek is 1 on start date', () {
      final start = DateTime(2026, 5, 26);
      expect(hipLumbarResetProgram.currentWeek(start, start), 1);
    });

    test('currentWeek rolls over every 7 days', () {
      final start = DateTime(2026, 5, 26);
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.add(const Duration(days: 6))),
          1);
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.add(const Duration(days: 7))),
          2);
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.add(const Duration(days: 35))),
          6);
      // Week 7 onwards = maintenance, but currentWeek keeps incrementing.
      // weekProgram clamps to the last defined week.
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.add(const Duration(days: 42))),
          7);
      expect(
          hipLumbarResetProgram.weekProgram(7).weekNumber, 6);
    });

    test('currentWeek before start clamps to week 1', () {
      final start = DateTime(2026, 5, 26);
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.subtract(const Duration(days: 30))),
          1);
    });

    test('currentWeek session-aware: misses extend the current week', () {
      final start = DateTime(2026, 5, 26);
      // Day 8 calendar with 6 sessions (1 missed) — still week 1.
      final target = start.add(const Duration(days: 7));
      final completed = {
        '2026-05-26', '2026-05-27', '2026-05-28', '2026-05-29',
        '2026-05-31', '2026-06-01', // missed 2026-05-30
      };
      expect(
          hipLumbarResetProgram.currentWeek(start, target, completed), 1);
    });

    test('currentWeek session-aware: week 2 starts after 7 sessions', () {
      final start = DateTime(2026, 5, 26);
      // Day 8 calendar with 7 perfect sessions on days 1-7 → week 2.
      final target = start.add(const Duration(days: 7));
      final completed = {
        '2026-05-26', '2026-05-27', '2026-05-28', '2026-05-29',
        '2026-05-30', '2026-05-31', '2026-06-01',
      };
      expect(
          hipLumbarResetProgram.currentWeek(start, target, completed), 2);
    });

    test('currentWeek session-aware: capped by calendar week', () {
      final start = DateTime(2026, 5, 26);
      // Calendar day 3 with somehow 14 sessions logged — capped at week 1
      // (the calendar ceiling) because only 2 calendar days have passed.
      final target = start.add(const Duration(days: 2));
      final completed = {
        for (var i = 0; i < 14; i++)
          '2026-05-${(20 + i).toString().padLeft(2, '0')}'
      };
      expect(
          hipLumbarResetProgram.currentWeek(start, target, completed), 1);
    });

    test('currentWeek falls back to calendar math when no sessions given',
        () {
      final start = DateTime(2026, 5, 26);
      expect(
          hipLumbarResetProgram.currentWeek(
              start, start.add(const Duration(days: 7))),
          2);
    });

    test('blocksForWeek inserts the right strength block', () {
      final w1Blocks = hipLumbarResetProgram.blocksForWeek(1);
      final w3Blocks = hipLumbarResetProgram.blocksForWeek(3);
      // Block C is at index 3 (after wake-up, decompress, mobilize).
      final w1Strength = w1Blocks[3];
      final w3Strength = w3Blocks[3];
      expect(w1Strength.exercises.any((e) => e.id == 'hlr-glute-bridge'),
          isTrue);
      expect(w3Strength.exercises.any((e) => e.id == 'hlr-single-leg-bridge'),
          isTrue);
      // Week 3 now introduces the RDL hinge precursor (added after the
      // critique panel dropped Bear Hold from W3).
      expect(w3Strength.exercises.any((e) => e.id == 'hlr-rdl-light'),
          isTrue);
    });

    test('walking targets escalate week over week', () {
      final miles =
          hipLumbarResetProgram.weeks.map((w) => w.walkingMilesMax).toList();
      for (var i = 1; i < miles.length; i++) {
        expect(miles[i], greaterThanOrEqualTo(miles[i - 1]));
      }
    });

    test('every strength block exercise has a hlr- prefix', () {
      for (final week in hipLumbarResetProgram.weeks) {
        for (final ex in week.strengthBlock.exercises) {
          expect(ex.id, startsWith('hlr-'),
              reason: 'week ${week.weekNumber}: ${ex.id}');
        }
      }
    });

    test('all expected strength exercises exist somewhere in the program',
        () {
      final allIds = hipLumbarResetProgram.weeks
          .expand((w) => w.strengthBlock.exercises)
          .map((e) => e.id)
          .toSet();
      for (final id in [
        'hlr-single-leg-bridge',
        'hlr-reverse-lunge',
        'hlr-side-plank-mod',
        'hlr-side-plank-chair',
        'hlr-side-plank-full',
        'hlr-walking-lunge',
        'hlr-goblet-squat',
        'hlr-single-leg-deadlift',
        'hlr-rdl-light',
        'hlr-hip-hinge-bodyweight',
        'hlr-chair-squat-test',
      ]) {
        expect(allIds, contains(id));
      }
    });

    test('bear hold removed after critique panel', () {
      final allIds = hipLumbarResetProgram.weeks
          .expand((w) => w.strengthBlock.exercises)
          .map((e) => e.id)
          .toSet();
      expect(allIds.contains('hlr-bear-hold'), isFalse);
    });
  });

  group('Exercise.sidesPerSet and atomicIds', () {
    Exercise mk({
      required String duration,
      int sets = 1,
    }) =>
        Exercise(
          id: 'x',
          name: 'X',
          duration: duration,
          description: 'd',
          cue: 'c',
          sets: sets,
        );

    test('returns 1 when no side language is present', () {
      expect(mk(duration: '60 sec').sidesPerSet, 1);
      expect(mk(duration: '5 min').sidesPerSet, 1);
      expect(mk(duration: '20 sec').sidesPerSet, 1);
    });

    test('returns 2 for "each side"', () {
      expect(mk(duration: '60 sec each side').sidesPerSet, 2);
    });

    test('returns 2 for "per side"', () {
      expect(mk(duration: '90 sec per side').sidesPerSet, 2);
    });

    test('returns 2 for "each leg"', () {
      expect(mk(duration: '12 sec each leg').sidesPerSet, 2);
    });

    test('returns 1 for rep-only exercises even with "each side"', () {
      // Rep-based exercises stay as a single tap per set — Julio asked
      // specifically for time-based per-side timers.
      expect(mk(duration: '8 reps each side').sidesPerSet, 1);
      expect(mk(duration: '15 reps each side').sidesPerSet, 1);
    });

    test('atomicIds: single set, one side', () {
      expect(mk(duration: '60 sec').atomicIds, ['x']);
    });

    test('atomicIds: single set, two sides', () {
      expect(mk(duration: '60 sec each side').atomicIds, ['x:L', 'x:R']);
    });

    test('atomicIds: multi-set, one side (current Daily 30 behavior)', () {
      expect(mk(duration: '30 sec', sets: 3).atomicIds,
          ['x:1', 'x:2', 'x:3']);
    });

    test('atomicIds: multi-set, two sides', () {
      expect(
          mk(duration: '60 sec each side', sets: 2).atomicIds,
          ['x:1:L', 'x:1:R', 'x:2:L', 'x:2:R']);
    });
  });

  group('Exercise.parsedDurationSeconds', () {
    Exercise mk(String dur) => Exercise(
        id: 'x', name: 'X', duration: dur, description: 'd', cue: 'c');

    test('parses sec', () {
      expect(mk('60 sec').parsedDurationSeconds, 60);
      expect(mk('30 sec each side').parsedDurationSeconds, 30);
      expect(mk('20 sec').parsedDurationSeconds, 20);
    });

    test('parses min and converts to sec', () {
      expect(mk('5 min').parsedDurationSeconds, 300);
      expect(mk('1 min').parsedDurationSeconds, 60);
    });

    test('takes the lower bound from ranges', () {
      expect(mk('40–45 sec each side').parsedDurationSeconds, 40);
    });

    test('finds the hold seconds in rep×hold patterns', () {
      expect(mk('5 reps × 5 sec hold').parsedDurationSeconds, 5);
    });

    test('returns null for pure rep counts', () {
      expect(mk('10 reps').parsedDurationSeconds, isNull);
      expect(mk('8 reps each side').parsedDurationSeconds, isNull);
      expect(mk('8–10 reps').parsedDurationSeconds, isNull);
      expect(mk('100 reps').parsedDurationSeconds, isNull);
      expect(mk('10 switches').parsedDurationSeconds, isNull);
      expect(mk('3 reps each side').parsedDurationSeconds, isNull);
    });

    test('HLR time-based exercises all have a parsed timer', () {
      final timedNames = <String>[];
      for (final block in hipLumbarResetProgram.constantBlocks) {
        for (final e in block.exercises) {
          if (RegExp(r'(sec|min)\b').hasMatch(e.duration)) {
            expect(e.parsedDurationSeconds, isNotNull,
                reason: '${e.name} ("${e.duration}") should parse');
            timedNames.add(e.name);
          }
        }
      }
      expect(timedNames, isNotEmpty);
    });
  });

  group('Exercise.effectiveVideoUrl', () {
    test('uses the curated URL when one is set', () {
      const e = Exercise(
        id: 'x',
        name: 'X',
        duration: '1 rep',
        description: 'd',
        cue: 'c',
        videoUrl: 'https://example.com/specific-video',
      );
      expect(e.effectiveVideoUrl, 'https://example.com/specific-video');
    });

    test('falls back to a YouTube search URL when none is curated', () {
      const e = Exercise(
        id: 'x',
        name: "World's Greatest Stretch",
        duration: '1 rep',
        description: 'd',
        cue: 'c',
      );
      expect(e.effectiveVideoUrl, startsWith('https://www.youtube.com/results?search_query='));
      expect(e.effectiveVideoUrl, contains('Greatest'));
    });

    test('searchQuery overrides the default name-based search', () {
      const e = Exercise(
        id: 'x',
        name: 'Right Anterior Hip Release',
        duration: '5 min',
        description: 'd',
        cue: 'c',
        searchQuery: 'iliacus release lacrosse ball self massage',
      );
      expect(e.effectiveVideoUrl, contains('iliacus'));
      expect(e.effectiveVideoUrl, contains('lacrosse'));
      // The unusual display name should NOT leak into the URL.
      expect(e.effectiveVideoUrl, isNot(contains('Anterior')));
    });

    test('curated videoUrl beats both searchQuery and name', () {
      const e = Exercise(
        id: 'x',
        name: 'X',
        duration: '1 rep',
        description: 'd',
        cue: 'c',
        videoUrl: 'https://example.com/curated',
        searchQuery: 'should not be used',
      );
      expect(e.effectiveVideoUrl, 'https://example.com/curated');
    });

    test('every Daily 30 and HLR exercise yields a non-empty URL', () {
      final allExercises = <Exercise>[
        ...dailyBlocks.expand((b) => b.exercises),
        ...hipLumbarResetProgram.weeks
            .expand((w) => w.strengthBlock.exercises),
        for (final b in hipLumbarResetProgram.constantBlocks) ...b.exercises,
      ];
      for (final e in allExercises) {
        expect(e.effectiveVideoUrl, isNotEmpty,
            reason: '${e.id} has no derivable video URL');
        expect(Uri.tryParse(e.effectiveVideoUrl), isNotNull,
            reason: '${e.id} produced an invalid URL');
      }
    });
  });

  group('WeekProgram.walkingTarget', () {
    test('renders single value when min == max', () {
      const w = WeekProgram(
        weekNumber: 1,
        phase: 'p',
        theme: 't',
        strengthBlock: ExerciseBlock(
            id: 'x', title: 'x', duration: '1 min', exercises: []),
        walkingMilesMin: 0.5,
        walkingMilesMax: 0.5,
      );
      expect(w.walkingTarget, '0.5 mi/day');
    });

    test('renders range when min != max', () {
      const w = WeekProgram(
        weekNumber: 4,
        phase: 'p',
        theme: 't',
        strengthBlock: ExerciseBlock(
            id: 'x', title: 'x', duration: '1 min', exercises: []),
        walkingMilesMin: 1.5,
        walkingMilesMax: 2,
      );
      expect(w.walkingTarget, '1.5–2 mi/day');
    });
  });
}

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
      expect(couch.atomicIds, ['couch-stretch:1', 'couch-stretch:2']);
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

    test('total exercises is 22 (Week 1 view)', () {
      final total = hipLumbarResetBlocks.fold<int>(
          0, (sum, b) => sum + b.exercises.length);
      expect(total, 22);
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
      expect(w3Strength.exercises.any((e) => e.id == 'hlr-bear-hold'),
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

    test('all new strength exercises exist somewhere in the program', () {
      final allIds = hipLumbarResetProgram.weeks
          .expand((w) => w.strengthBlock.exercises)
          .map((e) => e.id)
          .toSet();
      for (final id in [
        'hlr-single-leg-bridge',
        'hlr-bear-hold',
        'hlr-reverse-lunge',
        'hlr-side-plank-mod',
        'hlr-side-plank-full',
        'hlr-walking-lunge',
        'hlr-goblet-squat',
        'hlr-single-leg-deadlift',
      ]) {
        expect(allIds, contains(id));
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

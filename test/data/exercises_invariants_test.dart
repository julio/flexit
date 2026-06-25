import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/exercises.dart';
import 'package:flexit/models/exercise.dart';

/// Structural invariants that must hold across EVERY routine and EVERY program
/// week. The existing exercises_test.dart spot-checks specific exercises; this
/// file asserts properties the whole dataset must satisfy, so a future edit
/// that, say, duplicates an exercise id or breaks the atomic-id scheme fails
/// loudly. 100% line coverage of a static data file proves nothing about these
/// properties — they need their own assertions.

/// Every ExerciseBlock referenced anywhere: both routines' constant/blocks and
/// every program week's strength block.
List<ExerciseBlock> _allBlocks() {
  final blocks = <ExerciseBlock>[];
  for (final r in routines) {
    if (r.hasProgram) {
      blocks.addAll(r.program!.constantBlocks);
      for (final w in r.program!.weeks) {
        blocks.add(w.strengthBlock);
      }
    } else {
      blocks.addAll(r.blocks);
    }
  }
  return blocks;
}

/// Exercises grouped per "day view" — the set of exercises a user sees on one
/// screen. For a program routine that's constantBlocks + one week's strength
/// block; atomic ids must be unique within each such view.
Iterable<List<Exercise>> _dayViews() sync* {
  for (final r in routines) {
    if (r.hasProgram) {
      for (final w in r.program!.weeks) {
        yield [
          ...r.program!.constantBlocks.expand((b) => b.exercises),
          ...w.strengthBlock.exercises,
        ];
      }
    } else {
      yield r.blocks.expand((b) => b.exercises).toList();
    }
  }
}

void main() {
  final blocks = _allBlocks();
  final allExercises = blocks.expand((b) => b.exercises).toList();

  group('exercise field invariants', () {
    test('every exercise has non-empty id/name/duration/description/cue', () {
      for (final e in allExercises) {
        expect(e.id, isNotEmpty);
        expect(e.name.trim(), isNotEmpty, reason: e.id);
        expect(e.duration.trim(), isNotEmpty, reason: e.id);
        expect(e.description.trim(), isNotEmpty, reason: e.id);
        expect(e.cue.trim(), isNotEmpty, reason: e.id);
      }
    });

    test('ids contain no whitespace and no colon (colon is the atomic sep)',
        () {
      for (final e in allExercises) {
        expect(e.id, isNot(contains(':')),
            reason: '${e.id}: colon collides with atomic-id suffixes');
        expect(e.id, isNot(matches(RegExp(r'\s'))), reason: e.id);
      }
    });

    test('every curated videoUrl is https and parseable', () {
      for (final e in allExercises) {
        if (e.videoUrl != null) {
          expect(e.videoUrl, startsWith('https://'), reason: e.id);
          expect(Uri.tryParse(e.videoUrl!), isNotNull, reason: e.id);
        }
      }
    });

    test('sets is at least 1 everywhere', () {
      for (final e in allExercises) {
        expect(e.sets, greaterThanOrEqualTo(1), reason: e.id);
      }
    });
  });

  group('rep spec invariants', () {
    test('minReps <= defaultReps <= maxReps and minReps >= 1', () {
      for (final e in allExercises) {
        final r = e.reps;
        if (r == null) continue;
        expect(r.minReps, greaterThanOrEqualTo(1), reason: e.id);
        expect(r.minReps, lessThanOrEqualTo(r.defaultReps),
            reason: '${e.id}: min ${r.minReps} > default ${r.defaultReps}');
        expect(r.defaultReps, lessThanOrEqualTo(r.maxReps),
            reason: '${e.id}: default ${r.defaultReps} > max ${r.maxReps}');
      }
    });
  });

  group('timer spec invariants', () {
    test('timer defaultSeconds is positive', () {
      for (final e in allExercises) {
        if (e.timer == null) continue;
        expect(e.timer!.defaultSeconds, greaterThan(0), reason: e.id);
      }
    });

    test('a given timer settingKey maps to a single defaultSeconds', () {
      // Two exercises sharing a settingKey must agree on the default, or the
      // settings screen would show a contradictory value.
      final byKey = <String, int>{};
      for (final e in allExercises) {
        final t = e.timer;
        if (t == null) continue;
        if (byKey.containsKey(t.settingKey)) {
          expect(byKey[t.settingKey], t.defaultSeconds,
              reason: 'settingKey ${t.settingKey} has conflicting defaults');
        } else {
          byKey[t.settingKey] = t.defaultSeconds;
        }
      }
    });

    test('a rep settingKey maps to a single set of bounds', () {
      final byKey = <String, RepSpec>{};
      for (final e in allExercises) {
        final r = e.reps;
        if (r == null) continue;
        final prior = byKey[r.settingKey];
        if (prior != null) {
          expect(
              [prior.defaultReps, prior.minReps, prior.maxReps],
              [r.defaultReps, r.minReps, r.maxReps],
              reason: 'rep settingKey ${r.settingKey} has conflicting bounds');
        } else {
          byKey[r.settingKey] = r;
        }
      }
    });
  });

  group('atomic-id invariants', () {
    test('atomicIds are unique within a single day view', () {
      for (final view in _dayViews()) {
        final ids = view.expand((e) => e.atomicIds).toList();
        expect(ids.length, ids.toSet().length,
            reason: 'duplicate atomic id in a day view: '
                '${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
      }
    });

    test('atomic-id count equals sets × sidesPerSet for every exercise', () {
      for (final e in allExercises) {
        final expected = (e.sets < 1 ? 1 : e.sets) * e.sidesPerSet;
        expect(e.atomicIds.length, expected,
            reason: '${e.id}: ${e.atomicIds.length} atomic ids, '
                'expected $expected (sets=${e.sets}, sides=${e.sidesPerSet})');
      }
    });

    test('every atomic id is prefixed by its base id', () {
      for (final e in allExercises) {
        for (final aid in e.atomicIds) {
          expect(aid == e.id || aid.startsWith('${e.id}:'), isTrue,
              reason: '$aid is not a child of ${e.id}');
        }
      }
    });
  });

  group('routine wiring invariants', () {
    test('routine ids are unique', () {
      final ids = routines.map((r) => r.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('defaultRoutineId resolves to a real routine', () {
      expect(routines.any((r) => r.id == defaultRoutineId), isTrue);
      expect(routineById(defaultRoutineId).id, defaultRoutineId);
    });

    test('every block has at least one exercise', () {
      for (final b in blocks) {
        expect(b.exercises, isNotEmpty, reason: 'block ${b.id} is empty');
      }
    });

    test('block ids are unique within each routine', () {
      for (final r in routines) {
        final bs = r.hasProgram
            ? [
                ...r.program!.constantBlocks,
                ...r.program!.weeks.map((w) => w.strengthBlock)
              ]
            : r.blocks;
        // Strength blocks across weeks may legitimately reuse an id ("blockC"),
        // so only assert uniqueness among the constant blocks of a view.
        final constant = r.hasProgram ? r.program!.constantBlocks : r.blocks;
        final ids = constant.map((b) => b.id).toList();
        expect(ids.length, ids.toSet().length,
            reason: 'routine ${r.id} has duplicate constant block ids');
        expect(bs, isNotEmpty);
      }
    });
  });

  group('program week invariants', () {
    test('hipLumbarReset weeks are numbered 1..N with no gaps', () {
      final weeks = hipLumbarResetProgram.weeks;
      for (var i = 0; i < weeks.length; i++) {
        expect(weeks[i].weekNumber, i + 1);
      }
    });

    test('walking targets are non-negative and min <= max each week', () {
      for (final w in hipLumbarResetProgram.weeks) {
        expect(w.walkingMilesMin, greaterThanOrEqualTo(0));
        expect(w.walkingMilesMin, lessThanOrEqualTo(w.walkingMilesMax),
            reason: 'week ${w.weekNumber}');
      }
    });

    test('strengthBlockIndex is a valid insertion point', () {
      expect(hipLumbarResetProgram.strengthBlockIndex, greaterThanOrEqualTo(0));
      expect(hipLumbarResetProgram.strengthBlockIndex,
          lessThanOrEqualTo(hipLumbarResetProgram.constantBlocks.length));
    });

    test('blocksForWeek returns constantBlocks.length + 1 blocks', () {
      for (var w = 1; w <= hipLumbarResetProgram.weeks.length; w++) {
        expect(hipLumbarResetProgram.blocksForWeek(w).length,
            hipLumbarResetProgram.constantBlocks.length + 1);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/exercises.dart';

void main() {
  group('dailyBlocks', () {
    test('has 4 blocks', () {
      expect(dailyBlocks.length, 4);
    });

    test('block 1 has 2 exercises', () {
      expect(dailyBlocks[0].exercises.length, 2);
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

    test('all exercises have video urls', () {
      for (final block in dailyBlocks) {
        for (final exercise in block.exercises) {
          expect(exercise.videoUrl, isNotNull);
          expect(exercise.videoUrl, startsWith('https://'));
        }
      }
    });

    test('total daily exercises is 8', () {
      final total =
          dailyBlocks.fold<int>(0, (sum, b) => sum + b.exercises.length);
      expect(total, 8);
    });
  });

  group('weekendExtras', () {
    test('has 5 exercises', () {
      expect(weekendExtras.exercises.length, 5);
    });

    test('all weekend exercises have video urls', () {
      for (final exercise in weekendExtras.exercises) {
        expect(exercise.videoUrl, isNotNull);
      }
    });
  });

  group('getTodayBlocks', () {
    test('returns at least daily blocks', () {
      final blocks = getTodayBlocks();
      expect(blocks.length, greaterThanOrEqualTo(4));
    });
  });

  group('isWeekendDay', () {
    test('Saturday is weekend', () {
      // April 11, 2026 is Saturday
      expect(isWeekendDay(DateTime(2026, 4, 11)), true);
    });

    test('Sunday is weekend', () {
      // April 12, 2026 is Sunday
      expect(isWeekendDay(DateTime(2026, 4, 12)), true);
    });

    test('Monday is not weekend', () {
      // April 13, 2026 is Monday
      expect(isWeekendDay(DateTime(2026, 4, 13)), false);
    });

    test('Friday is not weekend', () {
      // April 10, 2026 is Friday
      expect(isWeekendDay(DateTime(2026, 4, 10)), false);
    });
  });
}

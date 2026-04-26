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
}

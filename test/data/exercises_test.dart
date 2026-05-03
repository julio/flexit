import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/data/exercises.dart';

void main() {
  group('dailyBlocks', () {
    test('has 6 blocks', () {
      expect(dailyBlocks.length, 6);
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

    test('push-ups has a 20-rep default rep spec', () {
      final pushUps = dailyBlocks
          .expand((b) => b.exercises)
          .firstWhere((e) => e.id == 'push-ups');
      expect(pushUps.reps, isNotNull);
      expect(pushUps.reps!.settingKey, 'push-ups');
      expect(pushUps.reps!.defaultReps, 20);
    });
  });
}

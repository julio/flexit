import 'package:flutter_test/flutter_test.dart';
import 'package:flexit/models/session.dart';

void main() {
  group('Session', () {
    test('toJson produces correct map', () {
      const session = Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:30:00.000',
        type: 'daily',
      );
      final json = session.toJson();
      expect(json['date'], '2026-04-10');
      expect(json['completedAt'], '2026-04-10T10:30:00.000');
      expect(json['type'], 'daily');
    });

    test('fromJson restores session', () {
      final json = {
        'date': '2026-04-10',
        'completedAt': '2026-04-10T10:30:00.000',
        'type': 'weekend',
      };
      final session = Session.fromJson(json);
      expect(session.date, '2026-04-10');
      expect(session.completedAt, '2026-04-10T10:30:00.000');
      expect(session.type, 'weekend');
    });

    test('roundtrip toJson/fromJson', () {
      const original = Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:30:00.000',
        type: 'daily',
      );
      final restored = Session.fromJson(original.toJson());
      expect(restored.date, original.date);
      expect(restored.completedAt, original.completedAt);
      expect(restored.type, original.type);
    });

    test('startedAt round-trips when set', () {
      const original = Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:30:00.000',
        type: 'daily',
        startedAt: '2026-04-10T10:14:00.000',
      );
      final restored = Session.fromJson(original.toJson());
      expect(restored.startedAt, '2026-04-10T10:14:00.000');
    });

    test('startedAt is null when omitted (backward compatible)', () {
      final json = {
        'date': '2026-04-10',
        'completedAt': '2026-04-10T10:30:00.000',
        'type': 'daily',
      };
      final session = Session.fromJson(json);
      expect(session.startedAt, isNull);
      expect(session.toJson().containsKey('startedAt'), isFalse);
    });

    test('duration is computed from startedAt and completedAt', () {
      const session = Session(
        date: '2026-04-10',
        startedAt: '2026-04-10T10:14:00.000',
        completedAt: '2026-04-10T10:30:30.000',
        type: 'daily',
      );
      expect(session.duration, const Duration(minutes: 16, seconds: 30));
    });

    test('duration is null when startedAt missing', () {
      const session = Session(
        date: '2026-04-10',
        completedAt: '2026-04-10T10:30:00.000',
        type: 'daily',
      );
      expect(session.duration, isNull);
    });

    test('duration is null when timestamps are out of order', () {
      const session = Session(
        date: '2026-04-10',
        startedAt: '2026-04-10T10:30:00.000',
        completedAt: '2026-04-10T10:14:00.000',
        type: 'daily',
      );
      expect(session.duration, isNull);
    });
  });
}

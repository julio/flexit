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
  });
}

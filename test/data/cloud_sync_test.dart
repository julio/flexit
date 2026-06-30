import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexit/data/cloud_sync.dart';
import 'package:flexit/data/storage.dart';

String _sessions(List<String> dates) => jsonEncode([
      for (final d in dates)
        {'date': d, 'completedAt': '${d}T10:00:00.000', 'type': 'daily'}
    ]);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CloudSync.enabled = true;
  });
  tearDown(() {
    CloudSync.enabled = true;
    CloudSync.client = http.Client();
  });

  group('mergeExports', () {
    test('unions keys; local wins a direct conflict', () {
      final remote = {
        'entries': {
          'flexit_a': {'type': 'int', 'value': 1},
          'flexit_shared': {'type': 'int', 'value': 10},
        }
      };
      final local = {
        'exportedAt': 'LOCAL',
        'entries': {
          'flexit_b': {'type': 'int', 'value': 2},
          'flexit_shared': {'type': 'int', 'value': 99},
        }
      };
      final m = mergeExports(remote, local);
      final e = m['entries'] as Map;
      expect(e['flexit_a']['value'], 1);
      expect(e['flexit_b']['value'], 2);
      expect(e['flexit_shared']['value'], 99);
      expect(m['exportedAt'], 'LOCAL');
    });

    test('unions sessions by date so no completed day is dropped', () {
      final remote = {
        'entries': {
          'flexit_sessions': {
            'type': 'string',
            'value': _sessions(['2026-05-01', '2026-05-02'])
          }
        }
      };
      final local = {
        'entries': {
          'flexit_sessions': {
            'type': 'string',
            'value': _sessions(['2026-05-02', '2026-06-01'])
          }
        }
      };
      final m = mergeExports(remote, local);
      final merged =
          jsonDecode((m['entries'] as Map)['flexit_sessions']['value']) as List;
      expect(merged.map((s) => s['date']).toList(),
          ['2026-05-01', '2026-05-02', '2026-06-01']);
    });

    test('falls back to remote exportedAt when local lacks one', () {
      final m = mergeExports({'exportedAt': 'REMOTE', 'entries': {}}, {'entries': {}});
      expect(m['exportedAt'], 'REMOTE');
    });

    test('tolerates missing entries and unparseable sessions', () {
      final m = mergeExports({}, {
        'entries': {
          'flexit_sessions': {'type': 'string', 'value': 'not-json'}
        }
      });
      // The bad sessions entry survives the union; no crash, no synthesized list.
      expect((m['entries'] as Map).containsKey('flexit_sessions'), isTrue);
      expect(mergeExports({}, {})['entries'], isEmpty);
    });
  });

  group('pull', () {
    test('returns the data map on 200', () async {
      CloudSync.client = MockClient((_) async => http.Response(
          jsonEncode([
            {
              'data': {
                'entries': {
                  'flexit_x': {'type': 'int', 'value': 5}
                }
              }
            }
          ]),
          200));
      final d = await CloudSync.pull();
      expect((d!['entries'] as Map)['flexit_x']['value'], 5);
    });

    test('null on empty list, non-200, non-map data, and exceptions',
        () async {
      CloudSync.client = MockClient((_) async => http.Response('[]', 200));
      expect(await CloudSync.pull(), isNull);

      CloudSync.client = MockClient((_) async => http.Response('nope', 500));
      expect(await CloudSync.pull(), isNull);

      CloudSync.client = MockClient((_) async =>
          http.Response(jsonEncode([{'data': 'oops'}]), 200));
      expect(await CloudSync.pull(), isNull);

      CloudSync.client = MockClient((_) async => throw Exception('boom'));
      expect(await CloudSync.pull(), isNull);
    });

    test('null when disabled', () async {
      CloudSync.enabled = false;
      expect(await CloudSync.pull(), isNull);
    });
  });

  group('push', () {
    test('false when disabled', () async {
      CloudSync.enabled = false;
      expect(await CloudSync.push(), isFalse);
    });

    test('posts local snapshot when cloud is empty', () async {
      SharedPreferences.setMockInitialValues({
        'flexit_sessions': _sessions(['2026-06-01']),
      });
      Map<String, dynamic>? posted;
      CloudSync.client = MockClient((req) async {
        if (req.method == 'GET') return http.Response('[]', 200);
        posted = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('', 201);
      });
      expect(await CloudSync.push(), isTrue);
      final data = posted!['data'] as Map<String, dynamic>;
      expect((data['entries'] as Map).containsKey('flexit_sessions'), isTrue);
    });

    test('merges with the cloud copy before writing (no remote loss)',
        () async {
      SharedPreferences.setMockInitialValues({
        'flexit_sessions': _sessions(['2026-06-01']),
      });
      Map<String, dynamic>? posted;
      CloudSync.client = MockClient((req) async {
        if (req.method == 'GET') {
          return http.Response(
              jsonEncode([
                {
                  'data': {
                    'entries': {
                      'flexit_sessions': {
                        'type': 'string',
                        'value': _sessions(['2026-05-01'])
                      }
                    }
                  }
                }
              ]),
              200);
        }
        posted = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('', 200);
      });
      expect(await CloudSync.push(), isTrue);
      final sessions = jsonDecode(((posted!['data'] as Map)['entries']
          as Map)['flexit_sessions']['value']) as List;
      expect(sessions.map((s) => s['date']).toList(),
          ['2026-05-01', '2026-06-01']);
    });

    test('false on a server error and on exceptions', () async {
      CloudSync.client = MockClient((req) async =>
          req.method == 'GET' ? http.Response('[]', 200) : http.Response('', 500));
      expect(await CloudSync.push(), isFalse);

      CloudSync.client = MockClient((_) async => throw Exception('down'));
      expect(await CloudSync.push(), isFalse);
    });
  });

  group('restoreIfLocalEmpty', () {
    test('false when disabled', () async {
      CloudSync.enabled = false;
      expect(await CloudSync.restoreIfLocalEmpty(), isFalse);
    });

    test('skips when local already has sessions', () async {
      SharedPreferences.setMockInitialValues({
        'flexit_sessions': _sessions(['2026-06-01']),
      });
      CloudSync.client = MockClient((_) async => throw Exception('must not call'));
      expect(await CloudSync.restoreIfLocalEmpty(), isFalse);
    });

    test('skips when local has per-day data but no session', () async {
      SharedPreferences.setMockInitialValues({'flexit_p_2026-06-01': 1});
      CloudSync.client = MockClient((_) async => throw Exception('must not call'));
      expect(await CloudSync.restoreIfLocalEmpty(), isFalse);
    });

    test('returns false when cloud has nothing', () async {
      CloudSync.client = MockClient((_) async => http.Response('[]', 200));
      expect(await CloudSync.restoreIfLocalEmpty(), isFalse);
    });

    test('imports the cloud snapshot into a blank install', () async {
      // Blank local (only a non-data key present).
      SharedPreferences.setMockInitialValues({'flexit_routine': 'ptDaily'});
      CloudSync.client = MockClient((_) async => http.Response(
          jsonEncode([
            {
              'data': {
                'entries': {
                  'flexit_sessions': {
                    'type': 'string',
                    'value': _sessions(['2026-05-01', '2026-05-02'])
                  },
                  'flexit_p_2026-05-01': {'type': 'int', 'value': 2},
                }
              }
            }
          ]),
          200));
      expect(await CloudSync.restoreIfLocalEmpty(), isTrue);
      final sessions = await getSessions();
      expect(sessions.length, 2);
      expect(await getPRating('2026-05-01'), 2);
    });
  });
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_config.dart';
import 'storage.dart';

/// Cloud backup to Supabase (PostgREST). Everything here is best-effort: if the
/// network is down or the server errors, the app keeps working on local data
/// and syncs next time. The contract that matters:
///
///   * [push] never *loses* remote history — it merges the local snapshot with
///     whatever is already in the cloud before writing back. So a partial local
///     state (e.g. right after a wipe, before a restore) can never clobber a
///     full cloud backup.
///   * [restoreIfLocalEmpty] pulls the cloud snapshot into a blank install.
///     This is the reinstall/data-loss guarantee: delete the app, reinstall,
///     launch → your data comes back with no manual step.
class CloudSync {
  /// Disabled in widget tests (the harness flips this) so they never hit the
  /// network. Cloud-specific tests re-enable it with a mock [client].
  static bool enabled = true;

  /// Injectable so tests can supply a `MockClient`.
  static http.Client client = http.Client();

  static Map<String, String> get _headers => {
        'apikey': cloudKey,
        'Authorization': 'Bearer $cloudKey',
        'Content-Type': 'application/json',
      };

  /// The cloud snapshot (`{version, exportedAt, entries}`), or null if there is
  /// none yet or the request failed.
  static Future<Map<String, dynamic>?> pull() async {
    if (!enabled) return null;
    try {
      final res = await client.get(
        Uri.parse(
            '$cloudUrl/rest/v1/backups?id=eq.$cloudBackupRowId&select=data'),
        headers: _headers,
      );
      if (res.statusCode != 200) return null;
      final rows = jsonDecode(res.body) as List;
      if (rows.isEmpty) return null;
      final data = (rows.first as Map<String, dynamic>)['data'];
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Merge the current local snapshot with the cloud copy and write it back.
  /// Returns true on a successful write.
  static Future<bool> push() async {
    if (!enabled) return false;
    try {
      final local =
          jsonDecode(await exportAllJson()) as Map<String, dynamic>;
      final remote = await pull();
      final merged = remote == null ? local : mergeExports(remote, local);
      final res = await client.post(
        Uri.parse('$cloudUrl/rest/v1/backups'),
        headers: {..._headers, 'Prefer': 'resolution=merge-duplicates'},
        body: jsonEncode({'id': cloudBackupRowId, 'data': merged}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// On a blank install (no sessions and no per-day data yet), pull the cloud
  /// snapshot and import it. Returns true if a restore happened.
  static Future<bool> restoreIfLocalEmpty() async {
    if (!enabled) return false;
    if (!await _localIsEmpty()) return false;
    final remote = await pull();
    if (remote == null) return false;
    await importAllJson(jsonEncode(remote));
    return true;
  }

  static Future<bool> _localIsEmpty() async {
    final sessions = await getSessions();
    if (sessions.isNotEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    const dataPrefixes = [
      'flexit_exercises_',
      'flexit_p_',
      'flexit_bp_',
      'flexit_alc_',
      'flexit_weight_2',
    ];
    return !prefs
        .getKeys()
        .any((k) => dataPrefixes.any((p) => k.startsWith(p)));
  }
}

/// Merge two export maps (`{version, exportedAt, entries}`). Union of all keys
/// with `local` winning on conflicts — EXCEPT `flexit_sessions`, whose JSON
/// array is unioned by date so no completed day is ever dropped from either
/// side. This is what makes [CloudSync.push] non-destructive.
Map<String, dynamic> mergeExports(
    Map<String, dynamic> remote, Map<String, dynamic> local) {
  final remoteEntries =
      Map<String, dynamic>.from(remote['entries'] as Map? ?? const {});
  final localEntries =
      Map<String, dynamic>.from(local['entries'] as Map? ?? const {});
  final out = <String, dynamic>{...remoteEntries, ...localEntries};

  final byDate = <String, Map<String, dynamic>>{};
  for (final s in _sessionsOf(remoteEntries['flexit_sessions'])) {
    byDate[s['date'] as String] = s;
  }
  for (final s in _sessionsOf(localEntries['flexit_sessions'])) {
    byDate[s['date'] as String] = s; // local wins a same-date conflict
  }
  if (byDate.isNotEmpty) {
    final merged = byDate.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    out['flexit_sessions'] = {'type': 'string', 'value': jsonEncode(merged)};
  }

  return {
    'version': 1,
    'exportedAt': local['exportedAt'] ?? remote['exportedAt'],
    'entries': out,
  };
}

List<Map<String, dynamic>> _sessionsOf(dynamic entry) {
  try {
    final raw = (entry as Map)['value'] as String;
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return const [];
  }
}

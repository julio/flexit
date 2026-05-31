import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercises.dart';
import '../models/exercise.dart';
import '../models/session.dart';

const _sessionsKey = 'flexit_sessions';
const _exercisesPrefix = 'flexit_exercises_';
const _timerPrefix = 'flexit_timer_';
const _repsPrefix = 'flexit_reps_';
const _startPrefix = 'flexit_start_';
const _pRatingPrefix = 'flexit_p_';
const _alcoholPrefix = 'flexit_alc_';
const _backPainPrefix = 'flexit_bp_';
const _weightPrefix = 'flexit_weight_'; // stored as integer grams
const _weightUnitKey = 'flexit_weight_unit'; // 'kg' or 'lb'
const _calendarMeasurementKey = 'flexit_calendar_measurement';
const _darkModeKey = 'flexit_dark_mode';
const _routineKey = 'flexit_routine';
const _programStartPrefix = 'flexit_program_start_';
const _migrationPerSideKey = 'flexit_migration_per_side_v1';

/// Which single measurement the calendar should render. The order is also the
/// swipe order (right = next, left = previous).
const calendarMeasurements = [
  'completion',
  'p',
  'drinks',
  'backpain',
  'weight',
];

/// Grams ↔ kg / lb conversions. Storage is always in integer grams so we
/// never mishandle floating-point precision across reads.
const double gramsPerKg = 1000.0;
const double gramsPerLb = 453.59237;
double gramsToKg(int g) => g / gramsPerKg;
double gramsToLb(int g) => g / gramsPerLb;
int kgToGrams(double kg) => (kg * gramsPerKg).round();
int lbToGrams(double lb) => (lb * gramsPerLb).round();

Future<List<Session>> getSessions() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_sessionsKey);
  if (raw == null) return [];
  final list = jsonDecode(raw) as List;
  return list.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveSession(Session session) async {
  final sessions = await getSessions();
  sessions.removeWhere((s) => s.date == session.date);
  sessions.add(session);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _sessionsKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
}

Future<void> removeSession(String date) async {
  final sessions = await getSessions();
  sessions.removeWhere((s) => s.date == date);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _sessionsKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
}

Future<bool> isTodayComplete() async {
  final today = formatDate(DateTime.now());
  final sessions = await getSessions();
  return sessions.any((s) => s.date == today);
}

Future<Set<String>> getCompletedExercises(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('$_exercisesPrefix$date');
  return raw?.toSet() ?? {};
}

Future<Set<String>> getTodayCompletedExercises() async {
  return getCompletedExercises(formatDate(DateTime.now()));
}

Future<Map<String, Set<String>>> getAllCompletedExercises() async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, Set<String>>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_exercisesPrefix)) continue;
    final list = prefs.getStringList(key);
    if (list == null || list.isEmpty) continue;
    result[key.substring(_exercisesPrefix.length)] = list.toSet();
  }
  return result;
}

Future<void> saveCompletedExercises(
    String date, Set<String> exerciseIds) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('$_exercisesPrefix$date', exerciseIds.toList());
}

Future<void> saveTodayCompletedExercises(Set<String> exerciseIds) async {
  await saveCompletedExercises(formatDate(DateTime.now()), exerciseIds);
}

Future<DateTime?> getStartTime(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_startPrefix$date');
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

Future<void> setStartTime(String date, DateTime time) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_startPrefix$date', time.toIso8601String());
}

Future<void> clearStartTime(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_startPrefix$date');
}

/// Per-exercise countdown timer end time (UTC ISO). Stored so an in-flight
/// timer survives the user collapsing the workout section, switching tabs,
/// backgrounding the app, or force-quitting — when the widget rebuilds it
/// reads the end time back and resumes or auto-completes.
String _timerEndKey(String atomicId) => 'flexit_timer_end_$atomicId';

Future<DateTime?> getTimerEnd(String atomicId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_timerEndKey(atomicId));
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

Future<void> setTimerEnd(String atomicId, DateTime end) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _timerEndKey(atomicId), end.toUtc().toIso8601String());
}

Future<void> clearTimerEnd(String atomicId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_timerEndKey(atomicId));
}

/// Diagnostic only: count keys in SharedPreferences that start with the
/// flexit_ namespace. Used to detect when writes don't land.
Future<int> debugCountFlexitKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getKeys().where((k) => k.startsWith('flexit_')).length;
}

/// Snapshot every `flexit_*` key into a JSON string. Round-trips through
/// [importAllJson]. Use to back up before risky deploys or to migrate data
/// between devices.
Future<String> exportAllJson() async {
  final prefs = await SharedPreferences.getInstance();
  final out = <String, dynamic>{
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'entries': <String, dynamic>{},
  };
  final entries = out['entries'] as Map<String, dynamic>;
  for (final key in prefs.getKeys()) {
    if (!key.startsWith('flexit_')) continue;
    final v = prefs.get(key);
    if (v is String) {
      entries[key] = {'type': 'string', 'value': v};
    } else if (v is int) {
      entries[key] = {'type': 'int', 'value': v};
    } else if (v is bool) {
      entries[key] = {'type': 'bool', 'value': v};
    } else if (v is double) {
      entries[key] = {'type': 'double', 'value': v};
    } else if (v is List<String>) {
      entries[key] = {'type': 'stringList', 'value': v};
    }
  }
  return const JsonEncoder.withIndent('  ').convert(out);
}

/// Restore from a JSON snapshot produced by [exportAllJson]. Returns the
/// number of keys written. Does NOT clear existing keys — anything already
/// in prefs that's not in the import stays.
Future<int> importAllJson(String json) async {
  final prefs = await SharedPreferences.getInstance();
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  final entries = decoded['entries'] as Map<String, dynamic>;
  var written = 0;
  for (final entry in entries.entries) {
    final key = entry.key;
    if (!key.startsWith('flexit_')) continue;
    final spec = entry.value as Map<String, dynamic>;
    final type = spec['type'] as String;
    final value = spec['value'];
    switch (type) {
      case 'string':
        await prefs.setString(key, value as String);
        break;
      case 'int':
        await prefs.setInt(key, value as int);
        break;
      case 'bool':
        await prefs.setBool(key, value as bool);
        break;
      case 'double':
        await prefs.setDouble(key, value as double);
        break;
      case 'stringList':
        await prefs.setStringList(
            key, (value as List).map((e) => e as String).toList());
        break;
      default:
        continue;
    }
    written++;
  }
  return written;
}

/// Total accumulated paused time for a session (in seconds), excluding any
/// pause currently in progress. Returns Duration.zero when nothing's stored.
Future<Duration> getPauseTotal(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final s = prefs.getInt('${_startPrefix}pause_total_$date') ?? 0;
  return Duration(seconds: s);
}

Future<void> setPauseTotal(String date, Duration value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('${_startPrefix}pause_total_$date', value.inSeconds);
}

/// When the user is currently paused, this returns when the pause began;
/// null otherwise.
Future<DateTime?> getPauseStartedAt(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('${_startPrefix}pause_started_$date');
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

Future<void> setPauseStartedAt(String date, DateTime time) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      '${_startPrefix}pause_started_$date', time.toIso8601String());
}

Future<void> clearPauseStartedAt(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('${_startPrefix}pause_started_$date');
}

Future<void> clearPauseState(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('${_startPrefix}pause_total_$date');
  await prefs.remove('${_startPrefix}pause_started_$date');
}

Future<int> getTimerSeconds(String settingKey, int defaultSeconds) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_timerPrefix$settingKey') ?? defaultSeconds;
}

Future<void> setTimerSeconds(String settingKey, int seconds) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_timerPrefix$settingKey', seconds);
}

Future<int?> getPRating(String date) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_pRatingPrefix$date');
}

Future<void> setPRating(String date, int value) async {
  assert(value >= -2 && value <= 2, 'p rating must be in [-2, 2]');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_pRatingPrefix$date', value);
}

Future<Map<String, int>> getAllPRatings() async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, int>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_pRatingPrefix)) continue;
    final value = prefs.getInt(key);
    if (value == null) continue;
    result[key.substring(_pRatingPrefix.length)] = value;
  }
  return result;
}

Future<int?> getAlcoholRating(String date) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_alcoholPrefix$date');
}

Future<void> setAlcoholRating(String date, int value) async {
  assert(value >= 0 && value <= 4, 'alcohol rating must be in [0, 4]');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_alcoholPrefix$date', value);
}

Future<Map<String, int>> getAllAlcoholRatings() async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, int>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_alcoholPrefix)) continue;
    final value = prefs.getInt(key);
    if (value == null) continue;
    result[key.substring(_alcoholPrefix.length)] = value;
  }
  return result;
}

Future<int?> getBackPainRating(String date) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_backPainPrefix$date');
}

Future<void> setBackPainRating(String date, int value) async {
  assert(value >= 0 && value <= 10, 'back pain rating must be in [0, 10]');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_backPainPrefix$date', value);
}

Future<int?> getWeightGrams(String date) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_weightPrefix$date');
}

Future<void> setWeightGrams(String date, int grams) async {
  assert(grams > 0, 'weight must be positive');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_weightPrefix$date', grams);
}

Future<void> clearWeight(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_weightPrefix$date');
}

Future<Map<String, int>> getAllWeightGrams() async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, int>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_weightPrefix)) continue;
    // _weightUnitKey ('flexit_weight_unit') also starts with _weightPrefix
    // but holds a String, not an int. Skip it explicitly — otherwise
    // prefs.getInt throws TypeError mid-iteration and kills _loadSessions
    // entirely.
    if (key == _weightUnitKey) continue;
    final value = prefs.getInt(key);
    if (value == null) continue;
    result[key.substring(_weightPrefix.length)] = value;
  }
  return result;
}

/// 'kg' (default) or 'lb'. Storage stays in grams either way; the unit
/// controls input/display only.
Future<String> getWeightUnit() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_weightUnitKey);
  return (raw == 'lb' || raw == 'kg') ? raw! : 'kg';
}

Future<void> setWeightUnit(String unit) async {
  assert(unit == 'kg' || unit == 'lb', 'unit must be kg or lb');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_weightUnitKey, unit);
}

Future<Map<String, int>> getAllBackPainRatings() async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, int>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_backPainPrefix)) continue;
    final value = prefs.getInt(key);
    if (value == null) continue;
    result[key.substring(_backPainPrefix.length)] = value;
  }
  return result;
}

Future<String> getCalendarMeasurement() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_calendarMeasurementKey);
  if (raw != null && calendarMeasurements.contains(raw)) return raw;
  return calendarMeasurements.first;
}

Future<void> setCalendarMeasurement(String value) async {
  assert(calendarMeasurements.contains(value),
      'unknown calendar measurement: $value');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_calendarMeasurementKey, value);
}

Future<bool> getDarkMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_darkModeKey) ?? true;
}

Future<void> setDarkMode(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_darkModeKey, value);
}

Future<String> getActiveRoutineId() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_routineKey);
  if (raw != null && routines.any((r) => r.id == raw)) return raw;
  return defaultRoutineId;
}

Future<void> setActiveRoutineId(String id) async {
  assert(routines.any((r) => r.id == id), 'unknown routine: $id');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_routineKey, id);
}

/// Program start date for a routine. If missing, returns null (caller
/// should default to today on first read for a program-based routine).
Future<DateTime?> getProgramStartDate(String routineId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_programStartPrefix$routineId');
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

Future<void> setProgramStartDate(String routineId, DateTime date) async {
  final prefs = await SharedPreferences.getInstance();
  final iso = formatDate(date);
  await prefs.setString('$_programStartPrefix$routineId', iso);
}

/// Convenience: ensures a routine with a program has a start date. If one
/// already exists, leaves it; otherwise sets it to today. Returns the
/// effective start date.
Future<DateTime> ensureProgramStartDate(String routineId) async {
  final existing = await getProgramStartDate(routineId);
  if (existing != null) return existing;
  final today = DateTime.now();
  await setProgramStartDate(routineId, today);
  return DateTime(today.year, today.month, today.day);
}

Future<int> getRepsCount(String settingKey, int defaultReps) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_repsPrefix$settingKey') ?? defaultReps;
}

Future<void> setRepsCount(String settingKey, int reps) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_repsPrefix$settingKey', reps);
}

String formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int getCurrentStreak(List<Session> sessions) {
  if (sessions.isEmpty) return 0;

  final dateSet = sessions.map((s) => s.date).toSet();
  var streak = 0;
  final today = DateTime.now();

  for (var i = 0; i < 365; i++) {
    final d = today.subtract(Duration(days: i));
    final key = formatDate(d);
    if (dateSet.contains(key)) {
      streak++;
    } else if (i == 0) {
      continue; // today not done yet, check yesterday
    } else {
      break;
    }
  }

  return streak;
}

int getLongestStreak(List<Session> sessions) {
  if (sessions.isEmpty) return 0;

  final dates = sessions.map((s) => s.date).toList()..sort();
  var longest = 1;
  var current = 1;

  for (var i = 1; i < dates.length; i++) {
    final prev = DateTime.parse(dates[i - 1]);
    final curr = DateTime.parse(dates[i]);
    final diff = curr.difference(prev).inDays;
    if (diff == 1) {
      current++;
      if (current > longest) longest = current;
    } else if (diff > 1) {
      current = 1;
    }
  }

  return longest;
}

/// One-shot migration for the per-side atomic ID change. Before commit
/// 2e8f933 a "30 sec each side" exercise had one atomic ID per set; after,
/// it has one per (set × side). Existing completion entries like
/// `hlr-single-knee-chest` or `couch-stretch:1` need to expand to their
/// `:L` and `:R` variants so previously-completed days stay completed.
Future<void> migrateCompletionPerSideV1() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_migrationPerSideKey) == true) return;

  // Collect base IDs of every exercise that currently has per-side atomic
  // IDs (sidesPerSet > 1) across both routines and every program week.
  final sidedBases = <String>{};
  for (final routine in routines) {
    final blocks = <ExerciseBlock>[];
    if (routine.hasProgram) {
      blocks.addAll(routine.program!.constantBlocks);
      for (final week in routine.program!.weeks) {
        blocks.add(week.strengthBlock);
      }
    } else {
      blocks.addAll(routine.blocks);
    }
    for (final block in blocks) {
      for (final ex in block.exercises) {
        if (ex.sidesPerSet > 1) sidedBases.add(ex.id);
      }
    }
  }

  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_exercisesPrefix)) continue;
    final raw = prefs.getStringList(key);
    if (raw == null || raw.isEmpty) continue;
    final migrated = <String>{};
    var changed = false;
    for (final id in raw) {
      // Already has a side suffix — leave it.
      if (id.endsWith(':L') || id.endsWith(':R')) {
        migrated.add(id);
        continue;
      }
      // Find the base exercise id (everything before the first ':').
      final colon = id.indexOf(':');
      final baseId = colon == -1 ? id : id.substring(0, colon);
      if (sidedBases.contains(baseId)) {
        migrated.add('$id:L');
        migrated.add('$id:R');
        changed = true;
      } else {
        migrated.add(id);
      }
    }
    if (changed) {
      await prefs.setStringList(key, migrated.toList());
    }
  }

  await prefs.setBool(_migrationPerSideKey, true);
}

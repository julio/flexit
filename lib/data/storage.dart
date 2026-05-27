import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercises.dart';
import '../models/session.dart';

const _sessionsKey = 'flexit_sessions';
const _exercisesPrefix = 'flexit_exercises_';
const _timerPrefix = 'flexit_timer_';
const _repsPrefix = 'flexit_reps_';
const _startPrefix = 'flexit_start_';
const _pRatingPrefix = 'flexit_p_';
const _alcoholPrefix = 'flexit_alc_';
const _backPainPrefix = 'flexit_bp_';
const _calendarMeasurementKey = 'flexit_calendar_measurement';
const _darkModeKey = 'flexit_dark_mode';
const _routineKey = 'flexit_routine';
const _programStartPrefix = 'flexit_program_start_';

/// Which single measurement the calendar should render. The order is also the
/// swipe order (right = next, left = previous).
const calendarMeasurements = ['completion', 'p', 'drinks', 'backpain'];

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

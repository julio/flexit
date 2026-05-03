import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

const _sessionsKey = 'flexit_sessions';
const _exercisesPrefix = 'flexit_exercises_';
const _timerPrefix = 'flexit_timer_';

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

Future<int> getTimerSeconds(String settingKey, int defaultSeconds) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_timerPrefix$settingKey') ?? defaultSeconds;
}

Future<void> setTimerSeconds(String settingKey, int seconds) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_timerPrefix$settingKey', seconds);
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

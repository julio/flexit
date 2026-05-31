import 'exercise.dart';

/// A multi-week training program. Only Block C (Strengthen) changes; the
/// other blocks (wake-up, decompress, mobilize, cool-down) stay constant
/// every week.
class Program {
  final List<ExerciseBlock> constantBlocks;

  /// Where Block C slots into the final block list. For Hip & Lumbar Reset
  /// the order is wake-up → decompress → mobilize → STRENGTHEN → cool-down,
  /// so this is index 3.
  final int strengthBlockIndex;
  final List<WeekProgram> weeks;

  const Program({
    required this.constantBlocks,
    required this.strengthBlockIndex,
    required this.weeks,
  });

  /// Program week (1-indexed). Weeks past the last defined one all map to
  /// the last week — that's the "maintenance" phase.
  ///
  /// When [doneDates] is provided, the program "extends itself" through
  /// missed days: week N+1 only begins after the user has completed 7
  /// sessions of week N (not just 7 calendar days). Capped at the calendar
  /// week so doing 7 sessions in 3 days still keeps you in week 1 for the
  /// remaining calendar days.
  ///
  /// With an empty [doneDates] (the default) it falls back to pure
  /// calendar-day math — convenient for tests and for callers that don't
  /// have the session list handy.
  int currentWeek(
    DateTime startDate,
    DateTime targetDate, [
    Set<String> doneDates = const {},
  ]) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (target.isBefore(start)) return 1;

    final calendarDays = target.difference(start).inDays;
    final calendarWeek = (calendarDays ~/ 7) + 1;

    if (doneDates.isEmpty) return calendarWeek;

    final startKey = _fmtDate(start);
    final targetKey = _fmtDate(target);
    // Sessions strictly before [target] — those determine which week the
    // user enters [target] in.
    final sessions = doneDates
        .where(
            (d) => d.compareTo(startKey) >= 0 && d.compareTo(targetKey) < 0)
        .length;
    final sessionWeek = (sessions ~/ 7) + 1;

    return sessionWeek < calendarWeek ? sessionWeek : calendarWeek;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  WeekProgram weekProgram(int week) {
    if (week < 1) return weeks.first;
    if (week > weeks.length) return weeks.last;
    return weeks[week - 1];
  }

  List<ExerciseBlock> blocksForWeek(int week) {
    final wp = weekProgram(week);
    final result = [...constantBlocks];
    result.insert(strengthBlockIndex, wp.strengthBlock);
    return result;
  }
}

class WeekProgram {
  final int weekNumber;
  final String phase;
  final String theme;
  final ExerciseBlock strengthBlock;
  final double walkingMilesMin;
  final double walkingMilesMax;

  const WeekProgram({
    required this.weekNumber,
    required this.phase,
    required this.theme,
    required this.strengthBlock,
    required this.walkingMilesMin,
    required this.walkingMilesMax,
  });

  String get walkingTarget {
    final lo = _fmt(walkingMilesMin);
    final hi = _fmt(walkingMilesMax);
    return walkingMilesMin == walkingMilesMax
        ? '$lo mi/day'
        : '$lo–$hi mi/day';
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }
}

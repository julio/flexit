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
  int currentWeek(DateTime startDate, DateTime now) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceStart = today.difference(start).inDays;
    if (daysSinceStart < 0) return 1;
    return (daysSinceStart ~/ 7) + 1;
  }

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

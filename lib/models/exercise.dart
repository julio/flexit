class TimerSpec {
  final String settingKey;
  final int defaultSeconds;
  const TimerSpec({required this.settingKey, required this.defaultSeconds});
}

class RepSpec {
  final String settingKey;
  final int defaultReps;
  final int minReps;
  final int maxReps;
  const RepSpec({
    required this.settingKey,
    required this.defaultReps,
    this.minReps = 5,
    this.maxReps = 50,
  });
}

class Exercise {
  final String id;
  final String name;
  final String duration;
  final String description;
  final String cue;
  final String? videoUrl;
  final int sets;
  final TimerSpec? timer;
  final RepSpec? reps;

  const Exercise({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.cue,
    this.videoUrl,
    this.sets = 1,
    this.timer,
    this.reps,
  });

  List<String> get atomicIds {
    if (sets <= 1) return [id];
    return List.generate(sets, (i) => '$id:${i + 1}');
  }

  /// Where to send the user when they tap the video button. If the exercise
  /// has a curated `videoUrl`, use that; otherwise return a YouTube search
  /// URL keyed off the exercise name so they always have a way to look it up.
  String get effectiveVideoUrl {
    final explicit = videoUrl;
    if (explicit != null) return explicit;
    final query = Uri.encodeComponent('$name exercise');
    return 'https://www.youtube.com/results?search_query=$query';
  }

  /// Parses the duration string for a time period — "60 sec", "30 sec each
  /// side", "5 min", "5 reps × 5 sec hold", "40–45 sec each side". Returns
  /// null for purely rep-based exercises like "10 reps". For ranges (e.g.
  /// 40–45 sec) returns the lower bound; for "X reps × Y sec hold" returns Y.
  int? get parsedDurationSeconds {
    // For ranges like "40–45 sec each side" we want the lower bound (40), so
    // capture the first number of an optional `n[–-]m` pair before sec/min.
    final secMatch =
        RegExp(r'(\d+)(?:\s*[–\-]\s*\d+)?\s*sec').firstMatch(duration);
    if (secMatch != null) return int.parse(secMatch.group(1)!);
    final minMatch =
        RegExp(r'(\d+)(?:\s*[–\-]\s*\d+)?\s*min').firstMatch(duration);
    if (minMatch != null) return int.parse(minMatch.group(1)!) * 60;
    return null;
  }
}

class ExerciseBlock {
  final String id;
  final String title;
  final String duration;
  final List<Exercise> exercises;

  const ExerciseBlock({
    required this.id,
    required this.title,
    required this.duration,
    required this.exercises,
  });
}

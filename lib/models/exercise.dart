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

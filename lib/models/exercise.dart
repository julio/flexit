class Exercise {
  final String id;
  final String name;
  final String duration;
  final String description;
  final String cue;
  final String? videoUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.cue,
    this.videoUrl,
  });
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

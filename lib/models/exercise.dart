class Exercise {
  final String id;
  final String name;
  final String duration;
  final String description;
  final String cue;
  final String? videoUrl;
  final int sets;

  const Exercise({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.cue,
    this.videoUrl,
    this.sets = 1,
  });

  List<String> get atomicIds {
    if (sets <= 1) return [id];
    return List.generate(sets, (i) => '$id:${i + 1}');
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

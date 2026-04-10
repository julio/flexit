class Session {
  final String date; // YYYY-MM-DD
  final String completedAt; // ISO timestamp
  final String type; // 'daily' or 'weekend'

  const Session({
    required this.date,
    required this.completedAt,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'completedAt': completedAt,
        'type': type,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        date: json['date'] as String,
        completedAt: json['completedAt'] as String,
        type: json['type'] as String,
      );
}

class Session {
  final String date; // YYYY-MM-DD
  final String completedAt; // ISO timestamp
  final String type; // 'daily' or 'weekend'
  final String? startedAt; // ISO timestamp, when the user tapped Start

  const Session({
    required this.date,
    required this.completedAt,
    required this.type,
    this.startedAt,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'completedAt': completedAt,
        'type': type,
        if (startedAt != null) 'startedAt': startedAt,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        date: json['date'] as String,
        completedAt: json['completedAt'] as String,
        type: json['type'] as String,
        startedAt: json['startedAt'] as String?,
      );
}

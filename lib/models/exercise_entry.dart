class ExerciseEntry {
  final String id;
  final DateTime dateTime;
  final String name;
  final int minutes;
  final int calories;

  const ExerciseEntry({
    required this.id,
    required this.dateTime,
    required this.name,
    required this.minutes,
    required this.calories,
  });

  bool isOn(DateTime day) {
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final other = DateTime(day.year, day.month, day.day);
    return d == other;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'name': name,
        'minutes': minutes,
        'calories': calories,
      };

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ??
            DateTime.now(),
        name: json['name'] as String? ?? 'Exercise',
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
      );
}

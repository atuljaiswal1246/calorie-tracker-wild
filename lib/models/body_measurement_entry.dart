class BodyMeasurementEntry {
  final String id;
  final DateTime date;
  final double? waist;
  final double? chest;
  final double? hips;
  final double? arm;
  final double? thigh;

  const BodyMeasurementEntry({
    required this.id,
    required this.date,
    this.waist,
    this.chest,
    this.hips,
    this.arm,
    this.thigh,
  });

  bool isOn(DateTime day) {
    final d = DateTime(date.year, date.month, date.day);
    final other = DateTime(day.year, day.month, day.day);
    return d == other;
  }

  /// First vs latest total "volume used" — for sparkline simplicity.
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        if (waist != null) 'waist': waist,
        if (chest != null) 'chest': chest,
        if (hips != null) 'hips': hips,
        if (arm != null) 'arm': arm,
        if (thigh != null) 'thigh': thigh,
      };

  factory BodyMeasurementEntry.fromJson(Map<String, dynamic> json) =>
      BodyMeasurementEntry(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        waist: (json['waist'] as num?)?.toDouble(),
        chest: (json['chest'] as num?)?.toDouble(),
        hips: (json['hips'] as num?)?.toDouble(),
        arm: (json['arm'] as num?)?.toDouble(),
        thigh: (json['thigh'] as num?)?.toDouble(),
      );

  static const labels = {
    'waist': 'Waist',
    'chest': 'Chest',
    'hips': 'Hips',
    'arm': 'Arm',
    'thigh': 'Thigh',
  };

  static const icons = {
    'waist': '📏',
    'chest': '👕',
    'hips': '🩳',
    'arm': '💪',
    'thigh': '🦵',
  };
}

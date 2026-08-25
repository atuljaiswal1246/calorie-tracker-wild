class FoodItem {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Food',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
      );
}

class FoodEntry {
  final String id;
  final DateTime dateTime;
  final String mealType;
  final List<FoodItem> items;
  final String imagePath;

  const FoodEntry({
    required this.id,
    required this.dateTime,
    required this.mealType,
    required this.items,
    required this.imagePath,
  });

  int get totalCalories =>
      items.fold(0, (sum, item) => sum + item.calories);

  double get totalProtein =>
      items.fold(0.0, (sum, item) => sum + item.protein);

  double get totalCarbs => items.fold(0.0, (sum, item) => sum + item.carbs);

  double get totalFat => items.fold(0.0, (sum, item) => sum + item.fat);

  double get totalFiber => items.fold(0.0, (sum, item) => sum + item.fiber);

  double get totalSugar => items.fold(0.0, (sum, item) => sum + item.sugar);

  double get totalSodium => items.fold(0.0, (sum, item) => sum + item.sodium);

  bool isOn(DateTime day) {
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final other = DateTime(day.year, day.month, day.day);
    return d == other;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'mealType': mealType,
        'imagePath': imagePath,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ??
            DateTime.now(),
        mealType: json['mealType'] as String? ?? 'snack',
        imagePath: json['imagePath'] as String? ?? '',
        items: ((json['items'] as List?) ?? [])
            .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

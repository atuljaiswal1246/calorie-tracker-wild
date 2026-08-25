class FoodItem {
  final String name;
  final int _calories;
  final double _protein;
  final double _carbs;
  final double _fat;
  final double _fiber;
  final double _sugar;
  final double _sodium;
  double quantity;

  FoodItem({
    required this.name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    this.quantity = 1,
  })  : _calories = calories,
        _protein = protein,
        _carbs = carbs,
        _fat = fat,
        _fiber = fiber,
        _sugar = sugar,
        _sodium = sodium;

  int get calories => (_calories * quantity).round();
  double get protein => _protein * quantity;
  double get carbs => _carbs * quantity;
  double get fat => _fat * quantity;
  double get fiber => _fiber * quantity;
  double get sugar => _sugar * quantity;
  double get sodium => _sodium * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': _calories,
        'protein': _protein,
        'carbs': _carbs,
        'fat': _fat,
        'fiber': _fiber,
        'sugar': _sugar,
        'sodium': _sodium,
        'quantity': quantity,
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
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
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

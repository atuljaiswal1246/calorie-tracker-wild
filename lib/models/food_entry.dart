class FoodItem {
  final String name;
  final double servingSizeGrams;
  final int _calories;
  final double _protein;
  final double _carbs;
  final double _fat;
  final double _fiber;
  final double _sugar;
  final double _sodium;
  final double _calcium;
  final double _iron;
  final double _vitaminC;
  double quantity;

  // Database comparison fields (populated when matched from local DB)
  final String? dbMatchedName;
  final String? dbSource;
  final double dbCaloriesPer100g;
  final double dbProteinPer100g;
  final double dbCarbsPer100g;
  final double dbFatPer100g;
  final double dbFiberPer100g;
  final double dbSugarPer100g;
  final double dbSodiumPer100g;

  FoodItem({
    required this.name,
    this.servingSizeGrams = 0,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    double calcium = 0,
    double iron = 0,
    double vitaminC = 0,
    this.quantity = 1,
    this.dbMatchedName,
    this.dbSource,
    this.dbCaloriesPer100g = 0,
    this.dbProteinPer100g = 0,
    this.dbCarbsPer100g = 0,
    this.dbFatPer100g = 0,
    this.dbFiberPer100g = 0,
    this.dbSugarPer100g = 0,
    this.dbSodiumPer100g = 0,
  })  : _calories = calories,
        _protein = protein,
        _carbs = carbs,
        _fat = fat,
        _fiber = fiber,
        _sugar = sugar,
        _sodium = sodium,
        _calcium = calcium,
        _iron = iron,
        _vitaminC = vitaminC;

  int get _atwaterCalories => (_protein * 4 + _carbs * 4 + _fat * 9).round();
  int get calories => (_protein > 0 || _carbs > 0 || _fat > 0)
      ? (_atwaterCalories * quantity).round()
      : (_calories * quantity).round();
  double get protein => _protein * quantity;
  double get carbs => _carbs * quantity;
  double get fat => _fat * quantity;
  double get fiber => _fiber * quantity;
  double get sugar => _sugar * quantity;
  double get sodium => _sodium * quantity;
  double get calcium => _calcium * quantity;
  double get iron => _iron * quantity;
  double get vitaminC => _vitaminC * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'servingSizeGrams': servingSizeGrams,
        'calories': _calories,
        'protein': _protein,
        'carbs': _carbs,
        'fat': _fat,
        'fiber': _fiber,
        'sugar': _sugar,
        'sodium': _sodium,
        'calcium': _calcium,
        'iron': _iron,
        'vitaminC': _vitaminC,
        'quantity': quantity,
        if (dbMatchedName != null) 'dbMatchedName': dbMatchedName,
        if (dbSource != null) 'dbSource': dbSource,
        'dbCaloriesPer100g': dbCaloriesPer100g,
        'dbProteinPer100g': dbProteinPer100g,
        'dbCarbsPer100g': dbCarbsPer100g,
        'dbFatPer100g': dbFatPer100g,
        'dbFiberPer100g': dbFiberPer100g,
        'dbSugarPer100g': dbSugarPer100g,
        'dbSodiumPer100g': dbSodiumPer100g,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Food',
        servingSizeGrams: (json['servingSizeGrams'] as num?)?.toDouble() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
        calcium: (json['calcium'] as num?)?.toDouble() ?? 0,
        iron: (json['iron'] as num?)?.toDouble() ?? 0,
        vitaminC: (json['vitaminC'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        dbMatchedName: json['dbMatchedName'] as String?,
        dbSource: json['dbSource'] as String?,
        dbCaloriesPer100g: (json['dbCaloriesPer100g'] as num?)?.toDouble() ?? 0,
        dbProteinPer100g: (json['dbProteinPer100g'] as num?)?.toDouble() ?? 0,
        dbCarbsPer100g: (json['dbCarbsPer100g'] as num?)?.toDouble() ?? 0,
        dbFatPer100g: (json['dbFatPer100g'] as num?)?.toDouble() ?? 0,
        dbFiberPer100g: (json['dbFiberPer100g'] as num?)?.toDouble() ?? 0,
        dbSugarPer100g: (json['dbSugarPer100g'] as num?)?.toDouble() ?? 0,
        dbSodiumPer100g: (json['dbSodiumPer100g'] as num?)?.toDouble() ?? 0,
      );
}

class FoodEntry {
  final String id;
  final DateTime dateTime;
  final String mealType;
  final List<FoodItem> items;
  final String imagePath;

  FoodEntry({
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

class MealPlan {
  final String id;
  final String name;
  final List<FoodItem> items;
  final DateTime createdAt;

  MealPlan({
    required this.id,
    required this.name,
    required this.items,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0, (s, i) => s + i.protein);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbs);
  double get totalFat => items.fold(0, (s, i) => s + i.fat);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Meal Plan',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        items: ((json['items'] as List?) ?? [])
            .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Ingredient {
  final String name;
  final double servingSizeGrams;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const Ingredient({
    required this.name,
    this.servingSizeGrams = 0,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'servingSizeGrams': servingSizeGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        servingSizeGrams: (json['servingSizeGrams'] as num?)?.toDouble() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
      );
}

class FoodItem {
  final String name;
  double servingSizeGrams;
  double quantity;
  final List<Ingredient> ingredients;

  // Base nutrition values (per original servingSizeGrams)
  int _calories;
  double _protein;
  double _carbs;
  double _fat;
  double _fiber;
  double _sugar;
  double _sodium;

  // User edits (null = use calculated value)
  int? _editedCalories;
  double? _editedProtein;
  double? _editedCarbs;
  double? _editedFat;

  FoodItem({
    required this.name,
    this.servingSizeGrams = 0,
    this.quantity = 1,
    this.ingredients = const [],
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
  })  : _calories = calories,
        _protein = protein,
        _carbs = carbs,
        _fat = fat,
        _fiber = fiber,
        _sugar = sugar,
        _sodium = sodium;

  // Base values (what AI returned)
  int get baseCalories => _calories;
  double get baseProtein => _protein;
  double get baseCarbs => _carbs;
  double get baseFat => _fat;
  double get baseFiber => _fiber;
  double get baseSugar => _sugar;
  double get baseSodium => _sodium;

  // Setters for base values
  set baseCalories(int v) => _calories = v;
  set baseProtein(double v) => _protein = v;
  set baseCarbs(double v) => _carbs = v;
  set baseFat(double v) => _fat = v;
  set baseFiber(double v) => _fiber = v;
  set baseSugar(double v) => _sugar = v;
  set baseSodium(double v) => _sodium = v;

  // Edited values (user override)
  bool get hasEdits =>
      _editedCalories != null ||
      _editedProtein != null ||
      _editedCarbs != null ||
      _editedFat != null;

  int? get editedCalories => _editedCalories;
  double? get editedProtein => _editedProtein;
  double? get editedCarbs => _editedCarbs;
  double? get editedFat => _editedFat;

  set editedCalories(int? v) => _editedCalories = v;
  set editedProtein(double? v) => _editedProtein = v;
  set editedCarbs(double? v) => _editedCarbs = v;
  set editedFat(double? v) => _editedFat = v;

  // Effective values (edited takes priority, otherwise scaled by quantity)
  int get calories =>
      _editedCalories ?? (_calories * quantity).round();
  double get protein =>
      _editedProtein ?? (_protein * quantity);
  double get carbs =>
      _editedCarbs ?? (_carbs * quantity);
  double get fat =>
      _editedFat ?? (_fat * quantity);
  double get fiber => (_fiber * quantity);
  double get sugar => (_sugar * quantity);
  double get sodium => (_sodium * quantity);

  // Recalculate edited values when quantity changes
  // (keeps the user's grams-based override proportionally)
  void rescaleEdits(double oldQty, double newQty) {
    if (oldQty <= 0 || newQty <= 0) return;
    final ratio = newQty / oldQty;
    if (_editedCalories != null) {
      _editedCalories = (_editedCalories! * ratio).round();
    }
    if (_editedProtein != null) {
      _editedProtein = _editedProtein! * ratio;
    }
    if (_editedCarbs != null) {
      _editedCarbs = _editedCarbs! * ratio;
    }
    if (_editedFat != null) {
      _editedFat = _editedFat! * ratio;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'servingSizeGrams': servingSizeGrams,
        'quantity': quantity,
        'calories': _calories,
        'protein': _protein,
        'carbs': _carbs,
        'fat': _fat,
        'fiber': _fiber,
        'sugar': _sugar,
        'sodium': _sodium,
        'editedCalories': _editedCalories,
        'editedProtein': _editedProtein,
        'editedCarbs': _editedCarbs,
        'editedFat': _editedFat,
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((e) => e.toJson()).toList(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Food',
        servingSizeGrams:
            (json['servingSizeGrams'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        ingredients: ((json['ingredients'] as List?) ?? [])
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
      )
        .._editedCalories = json['editedCalories'] as int?
        .._editedProtein = (json['editedProtein'] as num?)?.toDouble()
        .._editedCarbs = (json['editedCarbs'] as num?)?.toDouble()
        .._editedFat = (json['editedFat'] as num?)?.toDouble();
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

import 'dart:convert';

import 'package:flutter/services.dart';

class FoodDBItem {
  final String name;
  final String nameHindi;
  final String category;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double calcium;
  final double iron;
  final double vitaminC;
  final String source;

  FoodDBItem({
    required this.name,
    this.nameHindi = '',
    this.category = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.vitaminC = 0,
    this.source = '',
  });

  factory FoodDBItem.fromJson(Map<String, dynamic> json) {
    return FoodDBItem(
      name: json['name'] as String? ?? '',
      nameHindi: json['nameHindi'] as String? ?? '',
      category: json['category'] as String? ?? '',
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
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'nameHindi': nameHindi,
        'category': category,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'source': source,
      };
}

class FoodSearchService {
  static List<FoodDBItem>? _allFoods;

  static Future<List<FoodDBItem>> _loadFoods() async {
    if (_allFoods != null) return _allFoods!;
    final jsonStr = await rootBundle.loadString('assets/merged_foods.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    _allFoods = jsonList.map((j) => FoodDBItem.fromJson(j as Map<String, dynamic>)).toList();
    return _allFoods!;
  }

  /// Exact full-name lookup (used by quick picks to log with exact macros).
  static Future<FoodDBItem?> byFullName(String name) async {
    final foods = await _loadFoods();
    final lower = name.toLowerCase();
    for (final f in foods) {
      if (f.name.toLowerCase() == lower) return f;
    }
    return null;
  }

  static Future<List<FoodDBItem>> search(String query, {int limit = 20}) async {
    final foods = await _loadFoods();
    if (query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();

    final scored = <(FoodDBItem, double)>[];
    for (final food in foods) {
      final nameLower = food.name.toLowerCase();
      final hindiLower = food.nameHindi.toLowerCase();

      double score = 0;

      if (nameLower == q || hindiLower == q) {
        score = 100;
      } else if (nameLower.startsWith(q) || hindiLower.startsWith(q)) {
        score = 80;
      } else if (nameLower.contains(' $q') || nameLower.contains('$q ') ||
          hindiLower.contains(' $q') || hindiLower.contains('$q ')) {
        score = 60;
      } else if (nameLower.contains(q) || hindiLower.contains(q)) {
        score = 40;
      } else if (_fuzzyMatch(nameLower, q)) {
        score = 20;
      }

      if (score > 0) {
        if (food.source == 'ICMR-NIN' || food.source == 'Indian Food Nutrition API') {
          score += 5;
        }
        scored.add((food, score));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$1.name.compareTo(b.$1.name);
    });

    return scored.take(limit).map((s) => s.$1).toList();
  }

  static bool _fuzzyMatch(String text, String query) {
    var qi = 0;
    for (var ti = 0; ti < text.length && qi < query.length; ti++) {
      if (text[ti] == query[qi]) qi++;
    }
    return qi == query.length;
  }

  static Future<List<String>> getCategories() async {
    final foods = await _loadFoods();
    final cats = foods.map((f) => f.category).where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return cats;
  }

  static Future<List<FoodDBItem>> getByCategory(String category) async {
    final foods = await _loadFoods();
    return foods.where((f) => f.category == category).toList();
  }
}

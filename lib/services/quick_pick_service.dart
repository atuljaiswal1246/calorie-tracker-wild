import 'dart:convert';

import 'package:flutter/services.dart';

import 'food_search_service.dart';

class QuickPick {
  final String label;
  final String dbName;

  const QuickPick({required this.label, required this.dbName});

  factory QuickPick.fromJson(Map<String, dynamic> json) => QuickPick(
        label: json['label'] as String? ?? '',
        dbName: json['dbName'] as String? ?? '',
      );
}

/// Curated Indian household dishes for one-tap logging — the dbName is an
/// exact key in `assets/merged_foods.json` so macros are accurate without
/// an AI call.
class QuickPickService {
  static List<QuickPick>? _picks;

  static Future<List<QuickPick>> load() async {
    if (_picks != null) return _picks!;
    final jsonStr = await rootBundle.loadString('assets/quick_picks.json');
    final list = jsonDecode(jsonStr) as List;
    _picks = list
        .map((e) => QuickPick.fromJson(e as Map<String, dynamic>))
        .toList();
    return _picks!;
  }

  /// Exact-name lookup of the full nutrition entry (per 100 g basis).
  static Future<FoodDBItem?> byName(String dbName) =>
      FoodSearchService.byFullName(dbName);
}

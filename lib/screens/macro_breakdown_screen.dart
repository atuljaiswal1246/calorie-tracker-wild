import 'dart:io';

import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum MacroType { calories, protein, carbs, fat, fiber, sugar, sodium }

class MacroBreakdownScreen extends StatelessWidget {
  final MacroType macroType;
  final List<FoodEntry> entries;
  final double total;
  final double target;
  final Color color;

  MacroBreakdownScreen({
    super.key,
    required this.macroType,
    required this.entries,
    required this.total,
    required this.target,
    required this.color,
  });

  String get _title {
    switch (macroType) {
      case MacroType.calories:
        return 'Calories';
      case MacroType.protein:
        return 'Protein';
      case MacroType.carbs:
        return 'Carbs';
      case MacroType.fat:
        return 'Fat';
      case MacroType.fiber:
        return 'Fiber';
      case MacroType.sugar:
        return 'Sugar';
      case MacroType.sodium:
        return 'Sodium';
    }
  }

  String get _unit {
    switch (macroType) {
      case MacroType.calories:
        return 'kcal';
      default:
        return 'g';
    }
  }

  String get _emptyEmoji {
    switch (macroType) {
      case MacroType.calories:
        return '🔥';
      case MacroType.protein:
        return '🥩';
      case MacroType.carbs:
        return '🍞';
      case MacroType.fat:
        return '🥑';
      case MacroType.fiber:
        return '🥦';
      case MacroType.sugar:
        return '🍬';
      case MacroType.sodium:
        return '🧂';
    }
  }

  double _value(FoodItem item) {
    switch (macroType) {
      case MacroType.calories:
        return item.calories.toDouble();
      case MacroType.protein:
        return item.protein;
      case MacroType.carbs:
        return item.carbs;
      case MacroType.fat:
        return item.fat;
      case MacroType.fiber:
        return item.fiber;
      case MacroType.sugar:
        return item.sugar;
      case MacroType.sodium:
        return item.sodium;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group items by name, sum values, track count and most recent entry
    final Map<String, _GroupedItem> grouped = {};
    for (final entry in entries) {
      for (final item in entry.items) {
        final val = _value(item);
        if (val <= 0) continue;
        final key = item.name.toLowerCase();
        if (grouped.containsKey(key)) {
          grouped[key] = grouped[key]!.add(val, entry);
        } else {
          grouped[key] = _GroupedItem(name: item.name, totalValue: val, count: 1, latestEntry: entry);
        }
      }
    }

    final groupedItems = grouped.values.toList()
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    return Scaffold(
      backgroundColor: Color(0xFFFAF9F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$_title Breakdown',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: groupedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _emptyEmoji,
                    style: TextStyle(fontSize: 48),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No $_title logged yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Summary bar
                Container(
                  padding: EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryStat(
                        '${total.toStringAsFixed(0)}',
                        'Logged',
                        Colors.white,
                      ),
                      _summaryStat(
                        '${target.toStringAsFixed(0)}$_unit',
                        'Target',
                        Colors.white70,
                      ),
                      _summaryStat(
                        '${(target - total).toStringAsFixed(0)}$_unit',
                        'Remaining',
                        target > total ? Color(0xFF66BB6A) : const Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // ---- Micronutrient gaps ----
                Padding(
                  padding: EdgeInsets.only(left: AppSpace.xs, bottom: 10),
                  child: Text(
                    'Micronutrient gaps',
                    style: TextStyle(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _microRow('Iron', '🩸', _sumIron(), 18, 'mg',
                          limit: false),
                      Divider(height: 1, color: Color(0xFFF0EDE8)),
                      _microRow('Calcium', '🦴', _sumCalcium(), 1000, 'mg',
                          limit: false),
                      Divider(height: 1, color: Color(0xFFF0EDE8)),
                      _microRow('Vitamin C', '🍊', _sumVitaminC(), 75, 'mg',
                          limit: false),
                      Divider(height: 1, color: Color(0xFFF0EDE8)),
                      _microRow('Fiber', '🌾', _sumFiber(), 30, 'g',
                          limit: false),
                      Divider(height: 1, color: Color(0xFFF0EDE8)),
                      _microRow('Sugar', '🍬', _sumSugar(), 36, 'g',
                          limit: true),
                      Divider(height: 1, color: Color(0xFFF0EDE8)),
                      _microRow('Sodium', '🧂', _sumSodium(), 2300, 'mg',
                          limit: true),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Per-item breakdown
                ...groupedItems.map((g) {
                  final val = g.totalValue;
                  final pct = total == 0 ? 0.0 : (val / total);
                  final entry = g.latestEntry;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          if (entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: Image.file(
                                File(entry.imagePath),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Icon(Icons.restaurant, color: color, size: 20),
                            ),
                          SizedBox(width: 12),

                          // Name + count + bar
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    if (g.count > 1)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'x${g.count}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: color.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),

                          // Value + percentage
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _unit == 'kcal' ? '${val.toStringAsFixed(0)}$_unit' : '${val.toStringAsFixed(1)}$_unit',
                                style: TextStyle(
                                  fontSize: AppType.bodyStrong,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  double _sumIron() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.iron));
  double _sumCalcium() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.calcium));
  double _sumVitaminC() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.vitaminC));
  double _sumFiber() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.fiber));
  double _sumSugar() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.sugar));
  double _sumSodium() => entries
      .fold(0.0, (s, e) => s + e.items.fold(0.0, (a, i) => a + i.sodium));

  /// One micronutrient row. `limit` = nutrients you should stay UNDER
  /// (sugar/sodium); otherwise a gap = we want to reach the target.
  Widget _microRow(String label, String emoji, double value, double target,
      String unit, {required bool limit}) {
    const green = Color(0xFF66BB6A);
    const red = Color(0xFFEF5350);
    final hasData = value > 0;
    final met = limit ? value <= target : value >= target;
    final color = hasData ? (met ? green : red) : Colors.grey;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppType.body,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hasData
                    ? (value / target).clamp(0.0, 1.0).toDouble()
                    : 0,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              hasData
                  ? '$unit ${value.toStringAsFixed(value < 10 ? 1 : 0)}  '
                      '/ $target'
                  : 'No data',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasData ? color : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _GroupedItem {
  final String name;
  double totalValue;
  int count;
  FoodEntry latestEntry;

  _GroupedItem({
    required this.name,
    required this.totalValue,
    required this.count,
    required this.latestEntry,
  });

  _GroupedItem add(double value, FoodEntry entry) {
    totalValue += value;
    count++;
    if (entry.dateTime.isAfter(latestEntry.dateTime)) {
      latestEntry = entry;
    }
    return this;
  }
}

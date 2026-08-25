import 'dart:io';

import 'package:flutter/material.dart';

import '../models/food_entry.dart';

enum MacroType { calories, protein, carbs, fat, fiber, sugar, sodium }

class MacroBreakdownScreen extends StatelessWidget {
  final MacroType macroType;
  final List<FoodEntry> entries;
  final double total;
  final double target;
  final Color color;

  const MacroBreakdownScreen({
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
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$_title Breakdown',
          style: const TextStyle(
            color: Colors.black,
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
                    _unit == 'kcal' ? '🔥' : '🍽️',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Summary bar
                Container(
                  padding: const EdgeInsets.all(16),
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
                        target > total ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Per-item breakdown
                ...groupedItems.map((g) {
                  final val = g.totalValue;
                  final pct = total == 0 ? 0.0 : (val / total);
                  final entry = g.latestEntry;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          if (entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.restaurant, color: color, size: 20),
                            ),
                          const SizedBox(width: 12),

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
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (g.count > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                const SizedBox(height: 6),
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
                          const SizedBox(width: 12),

                          // Value + percentage
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _unit == 'kcal' ? '${val.toStringAsFixed(0)}$_unit' : '${val.toStringAsFixed(1)}$_unit',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
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
        const SizedBox(height: 2),
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

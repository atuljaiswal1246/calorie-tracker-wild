import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';

class MealDetailScreen extends StatelessWidget {
  final FoodEntry entry;

  const MealDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a, MMM d').format(entry.dateTime);
    final mealLabel = entry.mealType[0].toUpperCase() + entry.mealType.substring(1);

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
          mealLabel,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image
            if (entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync())
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(entry.imagePath),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items
            ...entry.items.map((item) => _itemCard(item)),

            const SizedBox(height: 24),

            // Totals
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _totalStat('🔥', '${entry.totalCalories}', 'kcal', Colors.white),
                        _totalStat('🥩', '${entry.totalProtein.toStringAsFixed(1)}g', 'protein', Colors.white),
                        _totalStat('🌾', '${entry.totalCarbs.toStringAsFixed(1)}g', 'carbs', Colors.white),
                        _totalStat('🧈', '${entry.totalFat.toStringAsFixed(1)}g', 'fat', Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(FoodItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  '${item.calories} kcal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _macroTag('Protein', '${item.protein.toStringAsFixed(1)}g', const Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                _macroTag('Carbs', '${item.carbs.toStringAsFixed(1)}g', const Color(0xFFFFA94D)),
                const SizedBox(width: 8),
                _macroTag('Fat', '${item.fat.toStringAsFixed(1)}g', const Color(0xFF4DABF7)),
              ],
            ),
            if (item.fiber > 0 || item.sugar > 0 || item.sodium > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.fiber > 0) ...[
                    _macroTag('Fiber', '${item.fiber.toStringAsFixed(1)}g', const Color(0xFF8D6E63)),
                    const SizedBox(width: 8),
                  ],
                  if (item.sugar > 0) ...[
                    _macroTag('Sugar', '${item.sugar.toStringAsFixed(1)}g', const Color(0xFFE91E63)),
                    const SizedBox(width: 8),
                  ],
                  if (item.sodium > 0)
                    _macroTag('Sodium', '${item.sodium.toStringAsFixed(0)}mg', const Color(0xFF78909C)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _totalStat(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
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

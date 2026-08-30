import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HighProteinMealsScreen extends StatelessWidget {
  const HighProteinMealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadowLight,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'High Protein Meals',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Indian meals ranked by protein content',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Non-veg'),
            const SizedBox(height: 12),
            ..._nonVegMeals.map((m) => _mealCard(m)),
            const SizedBox(height: 24),

            _sectionTitle('Vegetarian'),
            const SizedBox(height: 12),
            ..._vegMeals.map((m) => _mealCard(m)),
            const SizedBox(height: 24),

            _sectionTitle('Quick snacks'),
            const SizedBox(height: 12),
            ..._snacks.map((m) => _mealCard(m)),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
    );
  }

  static Widget _mealCard(_Meal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.protein.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${meal.protein}g',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.protein,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.description,
            style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _macroPill('${meal.calories} kcal', AppColors.ink),
              const SizedBox(width: 6),
              _macroPill('C ${meal.carbs}g', AppColors.carbs),
              const SizedBox(width: 6),
              _macroPill('F ${meal.fat}g', AppColors.fat),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _macroPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Meal {
  final String emoji;
  final String name;
  final String description;
  final int protein;
  final int calories;
  final int carbs;
  final int fat;

  const _Meal({
    required this.emoji,
    required this.name,
    required this.description,
    required this.protein,
    required this.calories,
    required this.carbs,
    required this.fat,
  });
}

const _nonVegMeals = [
  _Meal(
    emoji: '🍗',
    name: 'Chicken Curry + 2 Roti',
    description: 'Home-style chicken curry. High protein, moderate fat.',
    protein: 35, calories: 450, carbs: 35, fat: 18,
  ),
  _Meal(
    emoji: '🐟',
    name: 'Fish Curry + Rice',
    description: 'Bengali-style mustard fish. Rich in omega-3.',
    protein: 30, calories: 400, carbs: 40, fat: 12,
  ),
  _Meal(
    emoji: '🥚',
    name: 'Egg Bhurji + Roti',
    description: 'Scrambled eggs with onions, tomatoes, spices. Ready in 10 min.',
    protein: 18, calories: 300, carbs: 25, fat: 15,
  ),
  _Meal(
    emoji: '🍗',
    name: 'Tandoori Chicken',
    description: 'Marinated chicken grilled in tandoor. Low oil, high protein.',
    protein: 40, calories: 350, carbs: 5, fat: 15,
  ),
  _Meal(
    emoji: '🍖',
    name: 'Mutton Curry',
    description: 'Rich mutton curry. Higher fat but very filling.',
    protein: 32, calories: 500, carbs: 15, fat: 30,
  ),
];

const _vegMeals = [
  _Meal(
    emoji: '🫘',
    name: 'Rajma + Rice',
    description: 'Kidney beans curry with rice. Classic comfort food.',
    protein: 15, calories: 350, carbs: 60, fat: 5,
  ),
  _Meal(
    emoji: '🧀',
    name: 'Paneer Bhurji + Roti',
    description: 'Spiced crumbled paneer. Quick dinner option.',
    protein: 22, calories: 380, carbs: 30, fat: 20,
  ),
  _Meal(
    emoji: '🍛',
    name: 'Chole + 2 Roti',
    description: 'Chickpea curry. High fibre, good protein.',
    protein: 15, calories: 380, carbs: 55, fat: 8,
  ),
  _Meal(
    emoji: '🥘',
    name: 'Sambar + Rice',
    description: 'Lentil-based vegetable stew. Balanced macros.',
    protein: 12, calories: 300, carbs: 50, fat: 4,
  ),
  _Meal(
    emoji: '🫘',
    name: 'Dal Makhani + Roti',
    description: 'Creamy black lentil dal. Higher fat due to butter/cream.',
    protein: 14, calories: 400, carbs: 45, fat: 16,
  ),
];

const _snacks = [
  _Meal(
    emoji: '🥜',
    name: 'Bhuna Chana',
    description: 'Roasted chickpeas. Keep a small pack for hunger pangs.',
    protein: 20, calories: 250, carbs: 35, fat: 5,
  ),
  _Meal(
    emoji: '🧆',
    name: 'Sprouts Chaat',
    description: 'Moong sprouts with lemon, onion, chaat masala.',
    protein: 9, calories: 150, carbs: 20, fat: 2,
  ),
  _Meal(
    emoji: '🥛',
    name: 'Greek Yogurt + Nuts',
    description: 'Thick curd with almonds and walnuts.',
    protein: 15, calories: 220, carbs: 10, fat: 12,
  ),
  _Meal(
    emoji: '🥚',
    name: '2 Boiled Eggs',
    description: 'Simplest protein snack. Zero prep.',
    protein: 12, calories: 156, carbs: 1, fat: 11,
  ),
  _Meal(
    emoji: '🧀',
    name: 'Paneer Tikka',
    description: 'Grilled paneer cubes. Low carb, high protein.',
    protein: 18, calories: 200, carbs: 5, fat: 12,
  ),
];

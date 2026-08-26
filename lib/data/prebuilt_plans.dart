class PlanMealItem {
  final String name;
  final String serving;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const PlanMealItem({
    required this.name,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class PlanMeal {
  final String title; // breakfast | lunch | dinner | snack
  final List<PlanMealItem> items;

  const PlanMeal({required this.title, required this.items});

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0, (s, i) => s + i.protein);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbs);
  double get totalFat => items.fold(0, (s, i) => s + i.fat);
}

class PlanDay {
  final int day;
  final List<PlanMeal> meals;

  const PlanDay({required this.day, required this.meals});

  int get totalCalories => meals.fold(0, (s, m) => s + m.totalCalories);
}

class PrebuiltPlan {
  final String id;
  final String title;
  final String tagline;
  final String emoji;
  final String focus; // e.g. 'Vegetarian'
  final int approxKcal;
  final String accentHex;
  final List<PlanDay> days;

  const PrebuiltPlan({
    required this.id,
    required this.title,
    required this.tagline,
    required this.emoji,
    required this.focus,
    required this.approxKcal,
    required this.accentHex,
    required this.days,
  });

  int get totalCalories => days.fold(0, (s, d) => s + d.totalCalories);
}

const prebuiltPlans = <PrebuiltPlan>[
  PrebuiltPlan(
    id: 'weight_loss_veg',
    title: 'Weight Loss',
    tagline: 'Simple vegetarian menu that stays under budget',
    emoji: '🥗',
    focus: 'Veg · ~1300 kcal',
    approxKcal: 1300,
    accentHex: '#34C759',
    days: [
      PlanDay(day: 1, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Vegetable Upma', serving: '1 bowl (200g)', calories: 250, protein: 6, carbs: 40, fat: 8),
          PlanMealItem(name: 'Black Coffee / Green Tea', serving: '1 cup', calories: 0, protein: 0, carbs: 0, fat: 0),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Dal + Rice', serving: '1 katori dal + 1 bowl rice', calories: 320, protein: 12, carbs: 58, fat: 5),
          PlanMealItem(name: 'Salad (cucumber + tomato)', serving: '1 small bowl', calories: 25, protein: 1, carbs: 5, fat: 0),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Roasted Chana', serving: '1 handful (30g)', calories: 105, protein: 6, carbs: 17, fat: 2),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: '2 Roti + Mix Veg Sabzi', serving: '2 roti + 1 katori', calories: 270, protein: 8, carbs: 45, fat: 8),
        ]),
      ]),
      PlanDay(day: 2, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Methi Poha', serving: '1 bowl (200g)', calories: 230, protein: 5, carbs: 38, fat: 7),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Chana Masala + Rice', serving: '1 katori + 1 bowl', calories: 350, protein: 14, carbs: 55, fat: 8),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Apple', serving: '1 medium', calories: 95, protein: 0, carbs: 25, fat: 0),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Moong Dal Khichdi', serving: '1 bowl', calories: 280, protein: 10, carbs: 45, fat: 7),
          PlanMealItem(name: 'Curd', serving: '1 katori', calories: 60, protein: 3, carbs: 5, fat: 3),
        ]),
      ]),
      PlanDay(day: 3, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Masala Oats', serving: '1 bowl (200g)', calories: 200, protein: 6, carbs: 35, fat: 5),
          PlanMealItem(name: 'Boiled Egg', serving: '1', calories: 70, protein: 6, carbs: 0, fat: 5),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Rajma + Rice', serving: '1 katori + 1 bowl', calories: 350, protein: 13, carbs: 58, fat: 6),
          PlanMealItem(name: 'Salad', serving: '1 small bowl', calories: 25, protein: 1, carbs: 5, fat: 0),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Buttermilk (Chaas)', serving: '1 glass', calories: 40, protein: 2, carbs: 5, fat: 2),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Palak Paneer + 2 Roti', serving: '1 katori + 2 roti', calories: 330, protein: 14, carbs: 38, fat: 14),
        ]),
      ]),
      PlanDay(day: 4, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Idli + Sambar (2 pcs)', serving: '2 + 1 katori', calories: 250, protein: 7, carbs: 42, fat: 6),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Mixed Veg + Rice', serving: '1 katori + 1 bowl', calories: 320, protein: 9, carbs: 52, fat: 9),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Guava', serving: '1 medium', calories: 70, protein: 1, carbs: 17, fat: 0),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Sprout Salad + 1 Roti', serving: '1 bowl + 1 roti', calories: 240, protein: 11, carbs: 34, fat: 4),
        ]),
      ]),
      PlanDay(day: 5, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Vermicelli / Sevai Upma', serving: '1 bowl', calories: 240, protein: 5, carbs: 42, fat: 6),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Soya Chunk Curry + Rice', serving: '1 katori + 1 bowl', calories: 340, protein: 16, carbs: 50, fat: 8),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Roasted Makhana', serving: '1 handful', calories: 90, protein: 3, carbs: 15, fat: 2),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Peas Pulao (1 bowl) + Curd', serving: '1 bowl + 1 katori', calories: 310, protein: 9, carbs: 50, fat: 9),
        ]),
      ]),
      PlanDay(day: 6, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Pesarattu (Green Gram Dosa)', serving: '2 pieces', calories: 260, protein: 12, carbs: 28, fat: 10),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Kadhi + Rice', serving: '1 katori + 1 bowl', calories: 320, protein: 9, carbs: 55, fat: 7),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Corn on the Cob', serving: '1 small', calories: 90, protein: 3, carbs: 19, fat: 1),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Bhaingan Bharta + 2 Roti', serving: '1 katori + 2 roti', calories: 280, protein: 7, carbs: 42, fat: 9),
        ]),
      ]),
      PlanDay(day: 7, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Vegetable Daliya', serving: '1 bowl', calories: 230, protein: 8, carbs: 38, fat: 5),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Chole + 2 Roti', serving: '1 katori + 2 roti', calories: 330, protein: 12, carbs: 48, fat: 9),
          PlanMealItem(name: 'Onion Salad', serving: '1 small bowl', calories: 20, protein: 0, carbs: 5, fat: 0),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Papaya', serving: '1 small bowl', calories: 65, protein: 1, carbs: 16, fat: 0),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Veg Soup + 1 Roti', serving: '1 bowl + 1 roti', calories: 240, protein: 8, carbs: 35, fat: 6),
        ]),
      ]),
    ],
  ),
  PrebuiltPlan(
    id: 'high_protein',
    title: 'High Protein',
    tagline: 'Build muscle — protein at every meal',
    emoji: '💪',
    focus: 'Non-veg + paneer · ~1750 kcal',
    approxKcal: 1750,
    accentHex: '#FF9500',
    days: [
      PlanDay(day: 1, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Paneer Bhurji + 2 Toast', serving: '1 katori + 2 slices', calories: 350, protein: 20, carbs: 30, fat: 16),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Chicken Curry + Rice', serving: '1 katori + 1.5 bowl', calories: 480, protein: 30, carbs: 50, fat: 15),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Unsalted Peanuts', serving: '1 handful (30g)', calories: 170, protein: 7, carbs: 5, fat: 15),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Egg Bhurji + 2 Roti', serving: '2 eggs + 2 roti', calories: 380, protein: 20, carbs: 35, fat: 16),
        ]),
      ]),
      PlanDay(day: 2, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Milk Oats + Peanut Butter', serving: '1 bowl + 1 tbsp', calories: 380, protein: 15, carbs: 48, fat: 14),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Rajma Chawal + Curd', serving: '1 katori + 1 bowl + 1 katori', calories: 430, protein: 16, carbs: 60, fat: 10),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Banana + Curd', serving: '1 + 1 katori', calories: 180, protein: 5, carbs: 32, fat: 4),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Tandoori Chicken / Paneer Tikka', serving: '150g', calories: 330, protein: 30, carbs: 8, fat: 20),
          PlanMealItem(name: 'Grilled Veggies', serving: '1 bowl', calories: 100, protein: 3, carbs: 15, fat: 3),
        ]),
      ]),
      PlanDay(day: 3, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: '2 Boiled Eggs + 1 Roti', serving: '2 + 1', calories: 300, protein: 14, carbs: 20, fat: 18),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Fish Curry + Rice', serving: '1 katori + 1.5 bowl', calories: 460, protein: 28, carbs: 52, fat: 12),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Chocolate Protein Shake (skim milk)', serving: '1 glass', calories: 160, protein: 20, carbs: 15, fat: 2),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Kadhai Paneer + 2 Roti', serving: '1 katori + 2', calories: 420, protein: 22, carbs: 38, fat: 20),
        ]),
      ]),
      PlanDay(day: 4, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Omelette (2 eggs) + 2 Toast', serving: '2 + 2 slices', calories: 340, protein: 16, carbs: 30, fat: 18),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Soya Chunk Curry + Rice', serving: '1 katori + 1 bowl', calories: 420, protein: 25, carbs: 48, fat: 12),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Trail Mix / Almonds', serving: '20g', calories: 120, protein: 4, carbs: 4, fat: 10),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Grilled Chicken + Mashed Veg', serving: '150g + 1 bowl', calories: 400, protein: 35, carbs: 25, fat: 16),
        ]),
      ]),
      PlanDay(day: 5, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Moong Dal Chilla (2) + Curd', serving: '2 + 1 katori', calories: 330, protein: 16, carbs: 32, fat: 14),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Egg Curry + Rice', serving: '2 eggs + 1.5 bowl', calories: 450, protein: 20, carbs: 55, fat: 15),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Milk + Dates', serving: '1 glass + 3 dates', calories: 190, protein: 8, carbs: 28, fat: 6),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Dal Tadka + 2 Roti + Salad', serving: '1 katori + 2 + bowl', calories: 380, protein: 15, carbs: 48, fat: 12),
        ]),
      ]),
      PlanDay(day: 6, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Greek Yogurt + Honey + Nuts', serving: '1 bowl', calories: 300, protein: 15, carbs: 30, fat: 12),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Paneer + Rice (1.5 bowl)', serving: '1 katori + 1.5 bowl', calories: 480, protein: 20, carbs: 52, fat: 18),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Boiled Egg + Salted Soda', serving: '1', calories: 90, protein: 6, carbs: 2, fat: 6),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Chicken Kebabs + Salad', serving: '3 pcs + 1 bowl', calories: 380, protein: 32, carbs: 15, fat: 20),
        ]),
      ]),
      PlanDay(day: 7, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Bread Omelette Sandwich', serving: '2 sandwich', calories: 400, protein: 18, carbs: 40, fat: 18),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Biryani (Chicken) + Raita', serving: '1.5 bowl + 1 katori', calories: 480, protein: 25, carbs: 58, fat: 14),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Protein Bar', serving: '1 bar (40g)', calories: 170, protein: 15, carbs: 18, fat: 5),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Missi Roti (2) + Aloo Sabzi', serving: '2 + 1 katori', calories: 360, protein: 14, carbs: 50, fat: 11),
        ]),
      ]),
    ],
  ),
  PrebuiltPlan(
    id: 'balanced_2400',
    title: 'Balanced Maintain',
    tagline: 'Everyday Indian menu to maintain weight',
    emoji: '⚖️',
    focus: 'Mixed · ~2200 kcal',
    approxKcal: 2200,
    accentHex: '#007AFF',
    days: [
      PlanDay(day: 1, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Aloo Paratha + Curd', serving: '2 + 1 katori', calories: 450, protein: 12, carbs: 60, fat: 20),
          PlanMealItem(name: 'Milk (full fat)', serving: '1 glass', calories: 150, protein: 8, carbs: 12, fat: 8),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Dal + Rice + Ghee', serving: '1 katori + 1 bowl + 1 tsp', calories: 420, protein: 14, carbs: 65, fat: 10),
          PlanMealItem(name: 'Mixed Veg Sabzi', serving: '1 katori', calories: 120, protein: 4, carbs: 15, fat: 6),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Samosa + Chai', serving: '1 + 1 cup', calories: 280, protein: 4, carbs: 32, fat: 15),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Rajma + Rice', serving: '1 katori + 1 bowl', calories: 450, protein: 15, carbs: 62, fat: 12),
        ]),
      ]),
      PlanDay(day: 2, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Namkeen Poha + Chai', serving: '1 bowl + 1 cup', calories: 380, protein: 8, carbs: 55, fat: 13),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Butter Chicken + 2 Roti', serving: '1 katori + 2', calories: 520, protein: 28, carbs: 42, fat: 22),
          PlanMealItem(name: 'Salad', serving: '1 bowl', calories: 30, protein: 1, carbs: 6, fat: 0),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Fruit Bowl (Payash)', serving: '1 bowl', calories: 180, protein: 2, carbs: 45, fat: 1),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Masala Khichdi + Curd', serving: '1.5 bowl + 1 katori', calories: 420, protein: 12, carbs: 65, fat: 12),
        ]),
      ]),
      PlanDay(day: 3, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Bread Pakoda + Chai (occasional!)', serving: '2 + 1 cup', calories: 450, protein: 10, carbs: 55, fat: 22),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Fish Curry + Rice', serving: '1 katori + 1.5 bowl', calories: 480, protein: 26, carbs: 58, fat: 14),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Banana Smoothie', serving: '1 glass', calories: 220, protein: 6, carbs: 42, fat: 5),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Veg Pulao + Raita', serving: '1.5 bowl + 1 katori', calories: 430, protein: 10, carbs: 65, fat: 13),
        ]),
      ]),
      PlanDay(day: 4, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Chole Bhature (2 bhature)', serving: '1 katori + 2', calories: 550, protein: 14, carbs: 72, fat: 22),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Palak Paneer + 2 Roti', serving: '1 katori + 2', calories: 460, protein: 18, carbs: 45, fat: 22),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Tea + Rusk', serving: '2 rusks', calories: 90, protein: 2, carbs: 15, fat: 3),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Egg Fried Rice', serving: '1.5 bowl', calories: 420, protein: 18, carbs: 55, fat: 12),
        ]),
      ]),
      PlanDay(day: 5, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Vegetable Burger Sandwich', serving: '2 slices', calories: 320, protein: 10, carbs: 45, fat: 10),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Dal Makhani + Rice', serving: '1 katori + 1 bowl', calories: 460, protein: 14, carbs: 62, fat: 16),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Mango (seasonal)', serving: '1 medium', calories: 200, protein: 2, carbs: 50, fat: 1),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Mixed Veg Curry + 2 Roti', serving: '1 katori + 2', calories: 360, protein: 10, carbs: 50, fat: 12),
        ]),
      ]),
      PlanDay(day: 6, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'South Indian: 2 Idli + Sambar + Chutney', serving: '2 + 1 katori', calories: 380, protein: 10, carbs: 60, fat: 10),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Chicken Curry + 2 Roti', serving: '1 katori + 2', calories: 500, protein: 30, carbs: 42, fat: 20),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Mathri + Chai', serving: '2 + 1 cup', calories: 250, protein: 4, carbs: 30, fat: 13),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Prawn Curry + Rice', serving: '1 katori + 1 bowl', calories: 440, protein: 24, carbs: 55, fat: 10),
        ]),
      ]),
      PlanDay(day: 7, meals: [
        PlanMeal(title: 'breakfast', items: [
          PlanMealItem(name: 'Dosa (2) + Sambar', serving: '2 + 1 katori', calories: 450, protein: 12, carbs: 70, fat: 12),
        ]),
        PlanMeal(title: 'lunch', items: [
          PlanMealItem(name: 'Paneer Butter Masala + Rice', serving: '1 katori + 1 bowl', calories: 560, protein: 20, carbs: 55, fat: 26),
        ]),
        PlanMeal(title: 'snack', items: [
          PlanMealItem(name: 'Samosa + Chai', serving: '1 + 1 cup', calories: 280, protein: 4, carbs: 32, fat: 15),
        ]),
        PlanMeal(title: 'dinner', items: [
          PlanMealItem(name: 'Veg Hakka Noodles', serving: '1.5 bowl', calories: 400, protein: 10, carbs: 60, fat: 12),
        ]),
      ]),
    ],
  ),
];

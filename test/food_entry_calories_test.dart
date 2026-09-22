import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/models/food_entry.dart';

void main() {
  group('FoodItem.calories Atwater consistency', () {
    test('uses Atwater when macros are present', () {
      final item = FoodItem(
        name: 'Test',
        calories: 400,
        protein: 20,
        carbs: 30,
        fat: 25,
      );
      expect(item.calories, 425);
    });

    test('scales Atwater with quantity', () {
      final item = FoodItem(
        name: 'Test',
        calories: 400,
        protein: 20,
        carbs: 30,
        fat: 25,
        quantity: 2,
      );
      expect(item.calories, 850);
    });

    test('falls back to stored calories when no macros', () {
      final item = FoodItem(
        name: 'Test',
        calories: 400,
        protein: 0,
        carbs: 0,
        fat: 0,
      );
      expect(item.calories, 400);
    });
  });

  group('FoodItem.withPortion', () {
    test('rescales calories and macros to the new grams', () {
      final item = FoodItem(
        name: 'Chana Masala',
        servingSizeGrams: 200,
        calories: 312,
        protein: 15,
        carbs: 45,
        fat: 8,
        fiber: 10,
        sugar: 5,
        sodium: 600,
      );
      final half = item.withPortion(100);
      expect(half.servingSizeGrams, 100);
      expect(half.protein, closeTo(7.5, 0.001));
      expect(half.carbs, closeTo(22.5, 0.001));
      expect(half.fat, closeTo(4.0, 0.001));
      expect(half.fiber, closeTo(5.0, 0.001));
      expect(half.sugar, closeTo(2.5, 0.001));
      expect(half.sodium, closeTo(300, 0.001));
      // Atwater from the scaled macros.
      expect(half.calories, (7.5 * 4 + 22.5 * 4 + 4.0 * 9).round());
    });

    test('preserves the number of servings (quantity)', () {
      final item = FoodItem(
        name: 'Dal',
        servingSizeGrams: 150,
        calories: 180,
        protein: 9,
        carbs: 22,
        fat: 6,
        quantity: 2,
      );
      final doubled = item.withPortion(300);
      expect(doubled.servingSizeGrams, 300);
      expect(doubled.quantity, 2);
      // Base macros doubled; getter multiplies by quantity again.
      expect(doubled.calories, (9 * 2 * 4 + 22 * 2 * 4 + 6 * 2 * 9) * 2);
    });

    test('returns the item unchanged when grams are unknown', () {
      final item = FoodItem(
        name: 'Mystery',
        servingSizeGrams: 0,
        calories: 100,
        protein: 5,
        carbs: 10,
        fat: 2,
      );
      expect(identical(item.withPortion(200), item), isTrue);
      expect(item.withPortion(0).servingSizeGrams, 0);
    });
  });
}

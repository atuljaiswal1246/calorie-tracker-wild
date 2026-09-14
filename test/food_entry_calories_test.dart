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
}

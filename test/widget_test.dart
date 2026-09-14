import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/models/food_entry.dart';

Profile make({
  String sex = 'female',
  int age = 28,
  double weight = 60,
  double height = 162,
  String activity = 'moderate',
  String workout = 'none',
  String goal = 'maintain',
  String pace = 'recommended',
  double? target,
}) =>
    Profile(
      name: 'T',
      age: age,
      sex: sex,
      weightKg: weight,
      heightCm: height,
      activityLevel: activity,
      workoutFreq: workout,
      goal: goal,
      pace: pace,
      targetWeightKg: target,
    );

void main() {
  test('BMR uses Mifflin-St Jeor', () {
    final p = make();
    final bmr = 10 * 60 + 6.25 * 162 - 5 * 28 - 161;
    expect(p.bmr, closeTo(bmr, 0.001));
  });

  test('Activity multiplier: workouts only 0-2=1.2, 3-5=1.55, 6+=1.725', () {
    expect(make(workout: 'none').activityMultiplier, 1.2);
    expect(make(workout: '0to2').activityMultiplier, 1.2);
    expect(make(workout: '3to5').activityMultiplier, 1.55);
    expect(make(workout: '6plus').activityMultiplier, 1.725);
    expect(make(workout: '6plus').activityMultiplier,
        greaterThan(make().activityMultiplier));
  });

  test('Maintain = floor(current-weight TDEE)', () {
    final p = make();
    expect(p.calorieGoal, (p.currentBmr * p.activityMultiplier).floor());
  });

  test('Lose: moderate = floor(burn - 551.25 - 0.25), floored at 1200', () {
    final p = make(goal: 'lose');
    final burn = p.currentBmr * p.activityMultiplier;
    final raw = (burn - 551.25 - 0.25).floor();
    expect(p.calorieGoal, raw < 1200 ? 1200 : raw);
  });

  test('Lose: slow 0.1, moderate 0.5, fast 0.9 kg/week', () {
    expect(make(goal: 'lose', pace: 'slow').weeklyRateKg, 0.1);
    expect(make(goal: 'lose', pace: 'recommended').weeklyRateKg, 0.5);
    expect(make(goal: 'lose', pace: 'fast').weeklyRateKg, 0.9);
  });

  test('Gain: moderate = floor(burn + 551.25 - 0.25)', () {
    final p = make(goal: 'gain');
    final burn = p.currentBmr * p.activityMultiplier;
    expect(p.calorieGoal, (burn + 551.25 - 0.25).floor());
  });

  test('Calorie floor is 1200 women / 1500 men', () {
    final smallF = Profile(
      name: 'x', age: 30, sex: 'female', weightKg: 45, heightCm: 150,
      activityLevel: 'sedentary', goal: 'lose', pace: 'fast',
    );
    expect(smallF.calorieGoal, greaterThanOrEqualTo(1200));
    final smallM = Profile(
      name: 'x', age: 30, sex: 'male', weightKg: 50, heightCm: 155,
      activityLevel: 'sedentary', goal: 'lose', pace: 'fast',
    );
    expect(smallM.calorieGoal, greaterThanOrEqualTo(1500));
  });

  test('Workout frequency boosts activity multiplier', () {
    expect(make(workout: '5plus').activityMultiplier,
        greaterThan(make().activityMultiplier));
  });

  test('Macros are % of calories: 29/39/32 moderate, 28.5/40.5/31 slow', () {
    // moderate (1200 cal): 87P / 52F / 96C
    final mod = make(goal: 'lose');
    expect(mod.proteinGrams, (mod.calorieGoal * 0.29 / 4).round());
    expect(mod.fatGrams, (mod.calorieGoal * 0.39 / 9).round());
    // slow (1508 cal): 107P / 68F / 117C
    final slow = make(goal: 'lose', pace: 'slow');
    expect(slow.proteinGrams, (slow.calorieGoal * 0.285 / 4).round());
    expect(slow.fatGrams, (slow.calorieGoal * 0.405 / 9).round());
  });

  test('Trust match: 68kg 34F 160cm desk, lose 10kg -> all paces match apps', () {
    Profile makeP(String pace) => Profile(
          name: 'x',
          age: 34,
          sex: 'female',
          weightKg: 68,
          heightCm: 160,
          activityLevel: 'sedentary',
          workoutFreq: 'none',
          goal: 'lose',
          pace: pace,
          targetWeightKg: 58,
        );
    // Slow: 1508 kcal, 0.1 kg/week, 10 kg in ~23 months (100 weeks)
    final slow = makeP('slow');
    expect(slow.calorieGoal, 1508);
    expect(slow.weeklyRateKg, 0.1);
    expect(slow.weeksToGoal, 100);
    expect(slow.proteinGrams, 107);
    expect(slow.fatGrams, 68);
    expect(slow.carbsGrams, 117);
    expect(slow.proteinGrams * 4 + slow.carbsGrams * 4 + slow.fatGrams * 9,
        slow.calorieGoal);
    // Moderate & Fast: both hit the 1200 floor, so the plan is identical.
    // The projection is now derived from the actual goal (~0.38 kg/wk, 27 wks)
    // rather than the nominal pace it cannot deliver.
    final mod = makeP('recommended');
    expect(mod.calorieGoal, 1200);
    expect(mod.weeklyRateKg, 0.5); // nominal pace constant (unchanged)
    expect(mod.weeksToGoal, 27);
    final fast = makeP('fast');
    expect(fast.calorieGoal, 1200);
    expect(fast.weeklyRateKg, 0.9);
    expect(fast.weeksToGoal, 27);
    // Macros at basis weight: 87P / 52F / 96C
    expect(mod.proteinGrams, 87);
    expect(mod.fatGrams, 52);
    expect(mod.carbsGrams, 96);
    expect(mod.proteinGrams * 4 + mod.carbsGrams * 4 + mod.fatGrams * 9,
        mod.calorieGoal);
  });

  test('Trust match: 62kg 34M 168cm 3-5x/wk, gain 5kg -> all paces match', () {
    Profile makeP(String pace) => Profile(
          name: 'x',
          age: 34,
          sex: 'male',
          weightKg: 62,
          heightCm: 168,
          activityLevel: 'sedentary',
          workoutFreq: '3to5',
          goal: 'gain',
          pace: pace,
          targetWeightKg: 67,
        );
    // Slow: 2442 kcal, ~0.1 kg/week (derived), 5 kg in 51 weeks
    final slow = makeP('slow');
    expect(slow.calorieGoal, 2442);
    expect(slow.weeklyRateKg, 0.1);
    expect(slow.weeksToGoal, 51);
    expect(slow.proteinGrams, 177);
    expect(slow.fatGrams, 106);
    expect(slow.carbsGrams, 195);
    // Moderate: 2883 kcal, 0.5 kg/week, 10 weeks (2 months)
    final mod = makeP('recommended');
    expect(mod.calorieGoal, 2883);
    expect(mod.weeklyRateKg, 0.5);
    expect(mod.weeksToGoal, 10);
    // Fast: 3324 kcal, 0.9 kg/week, 6 weeks (1 month)
    final fast = makeP('fast');
    expect(fast.calorieGoal, 3324);
    expect(fast.weeklyRateKg, 0.9);
    expect(fast.weeksToGoal, 6);
    expect(fast.proteinGrams, 241);
    expect(fast.fatGrams, 144);
    expect(fast.carbsGrams, 266);
    // Macros sum to calories for all paces (within rounding tolerance)
    for (final p in [slow, mod, fast]) {
      final sum = p.proteinGrams * 4 + p.carbsGrams * 4 + p.fatGrams * 9;
      expect((sum - p.calorieGoal).abs(), lessThanOrEqualTo(3),
          reason: 'sum for ${p.pace}');
    }
  });

  test('Trust match: 52kg 25F 158cm 6+x/wk, lose 6kg', () {
    Profile makeP(String pace) => Profile(
          name: 'x',
          age: 25,
          sex: 'female',
          weightKg: 52,
          heightCm: 158,
          activityLevel: 'sedentary',
          workoutFreq: '6plus',
          goal: 'lose',
          pace: pace,
          targetWeightKg: 46,
        );
    expect(makeP('slow').calorieGoal, 1996); // 14 months
    expect(makeP('recommended').calorieGoal, 1555); // 3 months
    expect(makeP('fast').calorieGoal, 1200); // 1 month
    expect(makeP('recommended').proteinGrams, 113);
    expect(makeP('recommended').fatGrams, 67);
    expect(makeP('recommended').carbsGrams, 125);
    expect(makeP('fast').proteinGrams, 87);
  });

  test('Trust match: 88kg 40M 178cm 0-2x/wk, lose 12kg', () {
    Profile makeP(String pace) => Profile(
          name: 'x',
          age: 40,
          sex: 'male',
          weightKg: 88,
          heightCm: 178,
          activityLevel: 'sedentary',
          workoutFreq: '0to2',
          goal: 'lose',
          pace: pace,
          targetWeightKg: 76,
        );
    expect(makeP('slow').calorieGoal, 2046); // 28 months
    expect(makeP('recommended').calorieGoal, 1605); // 5 months
    expect(makeP('fast').calorieGoal, 1500); // 3 months (male floor)
    expect(makeP('recommended').proteinGrams, 116); // theirs 117 (±1)
    expect(makeP('recommended').fatGrams, 70); // theirs 69 (±1)
    expect(makeP('recommended').carbsGrams, 128); // theirs 129 (±1)
  });

  test('Trust match: 70kg 35F 165cm 0-2x/wk, gain 4kg', () {
    Profile makeP(String pace) => Profile(
          name: 'x',
          age: 35,
          sex: 'female',
          weightKg: 70,
          heightCm: 165,
          activityLevel: 'sedentary',
          workoutFreq: '0to2',
          goal: 'gain',
          pace: pace,
          targetWeightKg: 74,
        );
    expect(makeP('slow').calorieGoal, 1784); // 9 months
    expect(makeP('recommended').calorieGoal, 2225); // 2 months
    expect(makeP('fast').calorieGoal, 2666); // 30 days
    expect(makeP('slow').proteinGrams, 129); // theirs 127 (±2)
    expect(makeP('slow').fatGrams, 77); // theirs 80 (±3)
    expect(makeP('slow').carbsGrams, 144); // theirs 139 (±5)
    expect(makeP('fast').proteinGrams, 193); // theirs 191 (±2)
    expect(makeP('fast').fatGrams, 116); // theirs 118 (±2)
    expect(makeP('fast').carbsGrams, 213); // theirs 210 (±3)
  });

  test('Macros sum to calorie goal (within tolerance)', () {
    for (final goal in ['lose', 'gain', 'maintain']) {
      final p = make(goal: goal);
      final sum = p.proteinGrams * 4 + p.carbsGrams * 4 + p.fatGrams * 9;
      expect((sum - p.calorieGoal).abs(), lessThanOrEqualTo(12));
    }
  });

  test('Profile serializes all fields', () {
    final p = make(goal: 'lose', pace: 'fast', workout: '3to4', target: 55);
    final rt = Profile.fromJson(p.toJson());
    expect(rt.goal, 'lose');
    expect(rt.pace, 'fast');
    expect(rt.workoutFreq, '3to4');
    expect(rt.targetWeightKg, 55);
    expect(rt.calorieGoal, p.calorieGoal);
  });

  test('MealPlan JSON round-trip preserves items and totals', () {
    final plan = MealPlan(
      id: 'plan1',
      name: 'Lunch',
      items: [
        FoodItem(name: 'Dal', calories: 250, protein: 12, carbs: 30, fat: 8),
        FoodItem(name: 'Rice', calories: 200, protein: 4, carbs: 44, fat: 1),
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final rt = MealPlan.fromJson(plan.toJson());
    expect(rt.id, 'plan1');
    expect(rt.name, 'Lunch');
    expect(rt.items.length, 2);
    expect(rt.items[0].name, 'Dal');
    expect(rt.totalCalories, 450);
    expect(rt.totalProtein, 16);
    expect(rt.totalCarbs, 74);
    expect(rt.totalFat, 9);
  });

  test('FoodItem JSON round-trip keeps serving size and DB fields', () {
    final item = FoodItem(
      name: 'Roti',
      servingSizeGrams: 40,
      calories: 120,
      protein: 4,
      carbs: 25,
      fat: 1,
      fiber: 2,
      sugar: 0,
      sodium: 200,
      quantity: 1,
      dbMatchedName: 'Chapatis',
      dbSource: 'ICMR',
      dbCaloriesPer100g: 300,
    );
    final rt = FoodItem.fromJson(item.toJson());
    expect(rt.servingSizeGrams, 40);
    expect(rt.quantity, 1);
    expect(rt.dbMatchedName, 'Chapatis');
    expect(rt.dbSource, 'ICMR');
    expect(rt.dbCaloriesPer100g, 300);
    expect(rt.calories, 120);
  });

  test('FoodItem quantity scales calories', () {
    final item = FoodItem(
      name: 'Rice',
      calories: 200,
      protein: 4,
      carbs: 44,
      fat: 1,
      quantity: 2,
    );
    expect(item.calories, 400);
  });
}

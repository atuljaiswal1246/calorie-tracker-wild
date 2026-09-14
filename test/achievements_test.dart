import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/exercise_entry.dart';
import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/gamification_state.dart';
import 'package:calorie_tracker/services/achievements_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;
  late AchievementsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    service = AchievementsService(storage);
  });

  FoodItem item(String name) =>
      FoodItem(name: name, calories: 100, protein: 5, carbs: 10, fat: 3);

  FoodEntry meal({String image = '', DateTime? at, FoodItem? food}) => FoodEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: at ?? DateTime.now(),
        mealType: 'lunch',
        items: [food ?? item('Dal')],
        imagePath: image,
      );

  Achievement byId(String id) => service.getAll().firstWhere((a) => a.id == id);

  test('exposes the dynamic catalogue with categories', () {
    final all = service.getAll();
    expect(all.length, greaterThanOrEqualTo(35));
    expect(all.map((a) => a.category).toSet().length, greaterThanOrEqualTo(8));
    expect(service.totalCount, all.length);
  });

  test('a first meal unlocks First Bite', () async {
    expect(byId('meals_1').unlocked, isFalse);
    await storage.addEntry(meal());
    expect(byId('meals_1').unlocked, isTrue);
  });

  test('meal counts drive progress toward targets', () async {
    for (var i = 0; i < 3; i++) {
      await storage.addEntry(meal());
    }
    final a = byId('meals_10');
    expect(a.unlocked, isFalse);
    expect(a.progress, closeTo(0.3, 0.001));
  });

  test('hitting the water goal unlocks the hydration badge', () async {
    await storage.addWater(storage.waterGoalMl);
    expect(byId('water_1').unlocked, isTrue);
  });

  test('weight and exercise logging unlock their badges', () async {
    await storage.addWeightEntry(70);
    await storage.addExercise(ExerciseEntry(
      id: 'e',
      dateTime: DateTime.now(),
      name: 'Run',
      minutes: 20,
      calories: 100,
    ));
    expect(byId('weight_1').unlocked, isTrue);
    expect(byId('exercise_1').unlocked, isTrue);
  });

  test('the gamification streak unlocks streak badges', () async {
    final state = GamificationState();
    state.streak.longest = 7;
    await storage.saveGamification(state);
    expect(byId('streak_3').unlocked, isTrue);
    expect(byId('streak_7').unlocked, isTrue);
    expect(byId('streak_14').unlocked, isFalse);
  });

  test('level and coins milestones read the gamification state', () async {
    final state = GamificationState();
    state.calPoints = 21000; // → level 21
    state.nutriCoins = 1200;
    await storage.saveGamification(state);
    expect(byId('level_20').unlocked, isTrue);
    expect(byId('coins_1000').unlocked, isTrue);
  });

  test('secret achievements stay hidden until earned', () async {
    expect(byId('night_owl').title, 'Secret');
    expect(byId('night_owl').emoji, '❓');
    final now = DateTime.now();
    await storage.addEntry(
        meal(at: DateTime(now.year, now.month, now.day, 3)));
    final a = byId('night_owl');
    expect(a.unlocked, isTrue);
    expect(a.title, 'Night Owl');
  });

  test('checkAndUpdate persists unlocks and is idempotent', () async {
    await storage.addEntry(meal());
    final first = service.checkAndUpdate();
    expect(first.map((a) => a.id), contains('meals_1'));
    expect(service.checkAndUpdate(), isEmpty);
  });
}

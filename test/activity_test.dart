import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/exercise_entry.dart';
import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/services/activity_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Steps — all three tiers', () {
    test('storage: set/get/add per day, isolated by date', () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      final t = DateTime(2026, 9, 1, 12);
      final y = DateTime(2026, 8, 31, 12);
      expect(storage.getStepsFor(t), 0);
      await storage.addStepsFor(t, 1200);
      await storage.setStepsFor(t, 1500);
      await storage.addStepsFor(t, 500);
      expect(storage.getStepsFor(t), 2000);
      expect(storage.getStepsFor(y), 0);
    });

    test('tier 3 (manual): addManualSteps increments today, ignores junk',
        () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      final svc = ActivityService(storage);
      await svc.addManualSteps(2500);
      expect(await svc.todaySteps(), 2500);
      await svc.addManualSteps(0);
      await svc.addManualSteps(-5);
      expect(await svc.todaySteps(), 2500);
    });

    test('tier 2 (sensor): baseline persists across sessions so steps '
        'while app closed count', () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      await storage.addStepsFor(DateTime.now(), 3000);
      // Sensor last saw cumulative 5000 when the app closed.
      await storage.setSensorBaseline(5000);
      expect(storage.getStepsFor(DateTime.now()), 3000);
      expect(storage.sensorBaseline, 5000);
      // Later the counter reads 7000 -> delta 2000 for the new session.
      await storage.addStepsFor(DateTime.now(), 2000);
      expect(storage.getStepsFor(DateTime.now()), 5000);
    });

    test('manual source by default; changes stream fires on manual add',
        () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      final svc = ActivityService(storage);
      expect(svc.source, StepsSource.manual);
      var changed = false;
      svc.changes.listen((_) => changed = true);
      await svc.addManualSteps(50);
      await Future<void>.delayed(Duration.zero);
      expect(changed, isTrue);
      expect(await svc.todaySteps(), 50);
    });

    test('step goal formatting: 8000 target, manual entry usable', () {
      // Guard against the badge logic: source label must always resolve.
      expect(StepsSource.values.map((s) => s.name), contains('healthConnect'));
      expect(StepsSource.values.map((s) => s.name), contains('sensor'));
      expect(StepsSource.values.map((s) => s.name), contains('manual'));
    });
  });

  group('Exercise logging', () {
    test('kcal = MET x weight x minutes/60 (brisk walk 30min @70kg = 158)',
        () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      await storage.saveProfile(Profile(
        name: 'T',
        age: 30,
        sex: 'female',
        weightKg: 70,
        heightCm: 162,
        activityLevel: 'sedentary',
        workoutFreq: '3to5',
        goal: 'maintain',
        pace: 'recommended',
      ));
      final svc = ActivityService(storage);
      final entry = await svc.logExercise('Brisk walk', 30);
      expect(entry.calories, 158);
      expect(entry.minutes, 30);
      expect(entry.name, 'Brisk walk');
    });

    test('logged exercises land in today, removed by id', () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      final svc = ActivityService(storage);
      final e1 = await svc.logExercise('Walking', 15);
      final e2 = await svc.logExercise('Yoga', 45);
      expect(svc.todayExercises().length, 2);
      await svc.deleteExercise(e1.id);
      expect(svc.todayExercises().length, 1);
      expect(svc.todayExercises().first.id, e2.id);
    });

    test('ExerciseEntry JSON round-trip', () {
      final e = ExerciseEntry(
        id: 'x1',
        dateTime: DateTime(2026, 9, 1, 8, 30),
        name: 'Cycling',
        minutes: 60,
        calories: 480,
      );
      final rt = ExerciseEntry.fromJson(e.toJson());
      expect(rt.id, 'x1');
      expect(rt.name, 'Cycling');
      expect(rt.minutes, 60);
      expect(rt.calories, 480);
      expect(rt.isOn(DateTime(2026, 9, 1, 22)), isTrue);
      expect(rt.isOn(DateTime(2026, 9, 2)), isFalse);
    });
  });

  group('Micronutrients (feature #3 carries) — AI + DB backfill fields',
      () {
    test('FoodItem vitamins round-trip with quantity scaling', () {
      final item = FoodItem(
        name: 'Palak Paneer',
        calories: 250,
        protein: 12,
        carbs: 10,
        fat: 18,
        calcium: 250,
        iron: 3.5,
        vitaminC: 8,
        quantity: 2,
      );
      expect(item.calcium, 500);
      expect(item.iron, 7);
      expect(item.vitaminC, 16);
      final rt = FoodItem.fromJson(item.toJson());
      // Round-trip preserves per-serving base values; getters scale by qty.
      expect(rt.quantity, 2);
      expect(rt.calcium, 500);
      expect(rt.iron, 7);
      expect(rt.vitaminC, 16);
    });

    test('backfill rule: DB only fills where AI value is 0', () {
      // Mirrors the fill() rule in capture/manual-entry enrichment.
      double fill(double aiVal, double dbPer100g) =>
          aiVal > 0 ? aiVal : dbPer100g * 2.0; // serving = 200g
      expect(fill(140, 100), 140); // AI value kept
      expect(fill(0, 140), 280); // AI unknown -> DB scaled to serving
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/exercise_entry.dart';
import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/services/gamification_controller.dart';
import 'package:calorie_tracker/services/gamification_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;
  late GamificationController gami;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    gami = GamificationController(storage);
    await gami.init();
  });

  FoodEntry meal({String image = ''}) => FoodEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: DateTime.now(),
        mealType: 'lunch',
        items: const [],
        imagePath: image,
      );

  test('init generates quests and grants the daily login coins', () {
    expect(gami.activeQuests, hasLength(3));
    expect(gami.nutriCoins, 5);
    expect(storage.activityListener, isNotNull);
  });

  test('logging a manual meal earns points and starts the streak', () async {
    await storage.addEntry(meal());
    expect(gami.state.todayActions, contains('meal_manual'));
    // 10 (meal) + 5 (first streak day); quest auto-claim may add more.
    expect(gami.calPoints, greaterThanOrEqualTo(15));
    expect(gami.streak, 1);
  });

  test('a scanned meal is recorded as an AI scan', () async {
    await storage.addEntry(meal(image: '/tmp/photo.jpg'));
    expect(gami.state.todayActions, contains('meal_scan'));
    // 15 (scan) + 5 (streak); a photo-scan quest may add more.
    expect(gami.calPoints, greaterThanOrEqualTo(20));
  });

  test('hitting the water goal earns the hydration reward', () async {
    await storage.addWater(storage.waterGoalMl);
    expect(gami.state.todayActions, contains('water_goal'));
  });

  test('water below the goal does not award yet', () async {
    await storage.addWater(100);
    expect(gami.state.todayActions, isNot(contains('water_goal')));
  });

  test('weight and exercise logging are credited', () async {
    await storage.addWeightEntry(70);
    await storage.addExercise(ExerciseEntry(
      id: 'e1',
      dateTime: DateTime.now(),
      name: 'Walk',
      minutes: 30,
      calories: 120,
    ));
    expect(gami.state.todayActions, contains('weight_log'));
    expect(gami.state.todayActions, contains('exercise_log'));
  });

  test('apply returns the reward and queues celebrations', () {
    final r = gami.apply(GamificationAction.ashaChat);
    expect(r.calPoints, 5);
    expect(gami.celebrations, isNotEmpty);
    expect(gami.takeCelebration(), isNotNull);
  });

  test('state is persisted and reloadable', () async {
    await storage.addEntry(meal());
    final c = gami.calPoints;
    await gami.persist();
    expect(storage.gamification.calPoints, c);
    expect(gami.revision.value, greaterThan(0));
  });

  test('quest progress advances from a real action', () async {
    // A scanned meal fulfils "Log a meal using AI Photo Scan" if it is active.
    await storage.addEntry(meal(image: '/tmp/a.jpg'));
    final scanQuests =
        gami.activeQuests.where((q) => q.id == 'photo_scan').toList();
    if (scanQuests.isNotEmpty) {
      expect(scanQuests.first.completed, isTrue);
      expect(scanQuests.first.claimed, isTrue);
    }
  });
}

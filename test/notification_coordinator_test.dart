import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/exercise_entry.dart';
import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/notification_state.dart';
import 'package:calorie_tracker/services/notification_coordinator.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  test('lastActivity is null with no data', () {
    expect(NotificationCoordinator.lastActivity(storage), isNull);
  });

  test('lastActivity returns the most recent action across trackers', () async {
    final older = DateTime(2026, 9, 1, 9);
    final newer = DateTime(2026, 9, 5, 18);
    await storage.addEntry(FoodEntry(
      id: 'a',
      dateTime: older,
      mealType: 'lunch',
      items: const [],
      imagePath: '',
    ));
    await storage.addExercise(ExerciseEntry(
      id: 'e',
      dateTime: newer,
      name: 'Walk',
      minutes: 20,
      calories: 90,
    ));
    expect(NotificationCoordinator.lastActivity(storage), newer);
  });

  test('notification state round-trips through storage', () async {
    final state = NotificationState();
    state.preferredHour = 19;
    state.sentAt.add(DateTime(2026, 9, 7, 19).toIso8601String());
    await storage.saveNotificationState(state.toJson());

    final restored =
        NotificationState.fromJson(storage.notificationStateRaw!);
    expect(restored.preferredHour, 19);
    expect(restored.sentAt, hasLength(1));
  });
}

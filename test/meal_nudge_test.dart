import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/services/meal_nudge.dart';
import 'package:calorie_tracker/services/notification_coordinator.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:calorie_tracker/services/widget_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _meal(String id, DateTime at, String type, int kcal) => FoodEntry(
      id: id,
      dateTime: at,
      mealType: type,
      imagePath: '',
      items: [
        // macros are zero so the explicit kcal is used (kcal-from-macros
        // would otherwise override it)
        FoodItem(name: 'x', calories: kcal, protein: 0, carbs: 0, fat: 0),
      ],
    );

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService(await SharedPreferences.getInstance());
  await s.saveProfile(Profile(
    name: 'Atul',
    age: 30,
    sex: 'male',
    weightKg: 75,
    heightCm: 175,
    activityLevel: 'moderate',
    workoutFreq: '3to5',
    goal: 'lose',
    pace: 'recommended',
    targetWeightKg: 70,
  ));
  return s;
}

/// Three days of 2:30pm lunches so the user's lunchtime is learned.
Future<void> _seedLunches(StorageService s) async {
  for (var d = 0; d < 3; d++) {
    await s.addEntry(_meal('l$d', DateTime(2026, 9, 10 + d, 14, 30), 'lunch', 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns a nudge when a meal is due and unlogged', () async {
    final s = await _storage();
    await _seedLunches(s);
    final now = DateTime(2026, 9, 16, 14, 0);
    final nudge = decideMealNudge(s, now);
    expect(nudge, isNotNull);
    expect(nudge!.meal, 'lunch');
    expect(nudge.title, 'Lunch?');
    expect(nudge.body, contains('2:30pm'),
        reason: 'copy must agree with what the widget shows');
    expect(nudge.sendAtMinute, 14 * 60);
  });

  test('returns null when that meal is already logged today', () async {
    final s = await _storage();
    await _seedLunches(s);
    await s.addEntry(_meal('today', DateTime(2026, 9, 16, 13, 0), 'lunch', 300));
    expect(decideMealNudge(s, DateTime(2026, 9, 16, 14, 0)), isNull);
  });

  test('returns null when everything is logged (done)', () async {
    final s = await _storage();
    final day = DateTime(2026, 9, 16);
    for (final (i, m) in ['breakfast', 'lunch', 'dinner'].indexed) {
      await s.addEntry(
          _meal('m$i', DateTime(day.year, day.month, day.day, 8 + i * 4), m, 200));
    }
    expect(decideMealNudge(s, DateTime(2026, 9, 16, 14, 0)), isNull);
  });

  test('returns null when over budget', () async {
    final s = await _storage();
    await s.addEntry(_meal('big', DateTime(2026, 9, 16, 12), 'lunch', 5000));
    expect(decideMealNudge(s, DateTime(2026, 9, 16, 14, 0)), isNull);
  });

  test('returns null outside 08:00-20:00', () async {
    final s = await _storage();
    await _seedLunches(s);
    // 07:30 would otherwise be breakfast-due (fallback 8am window).
    expect(decideMealNudge(s, DateTime(2026, 9, 16, 7, 30)), isNull);
    expect(decideMealNudge(s, DateTime(2026, 9, 16, 22, 0)), isNull);
  });

  test('returns null the second time for the same meal on the same day',
      () async {
    final s = await _storage();
    await _seedLunches(s);
    final now = DateTime(2026, 9, 16, 14, 0);
    final first = decideMealNudge(s, now);
    expect(first, isNotNull);
    await s.saveMealNudgeSent(mealNudgeSentKey(now, first!.meal));
    expect(decideMealNudge(s, now), isNull,
        reason: 'at most once per meal per day');
    // A new day resets the dedupe.
    expect(decideMealNudge(s, DateTime(2026, 9, 17, 14, 0)), isNotNull);
  });

  test('meal nudge schedules ~30 minutes ahead, not tomorrow at the meal hour',
      () async {
    final s = await _storage();
    await _seedLunches(s);
    // Lunches learned at 2:30pm; 13:30 is inside the due window.
    final now = DateTime(2026, 9, 16, 13, 30);
    final nudge = decideMealNudge(s, now);
    expect(nudge, isNotNull);

    final minutesNow = now.hour * 60 + now.minute;
    final states = CalWidgetStates.build(s, now);
    final stateForNow = CalWidgetStates.pick(states, minutesNow);
    expect(stateForNow.mood, WidgetMood.due);

    final inMinutes = NotificationCoordinator.mealNudgeInMinutes(
      endMinute: stateForNow.endMinute,
      minutesNow: minutesNow,
    );
    expect(inMinutes, 30);

    final target = now.add(Duration(minutes: inMinutes));
    // ~30 minutes ahead, same day: 14:00 today, not tomorrow.
    expect(target, DateTime(2026, 9, 16, 14, 0));
    expect(target.day, now.day,
        reason: 'the nudge must fire while the meal is still pending today');
  });

  test('meal nudge never fires past the end of the due window', () async {
    final s = await _storage();
    await _seedLunches(s);
    // Due window for the learned 2:30pm lunch ends at 16:30 (14:30 + 120).
    final now = DateTime(2026, 9, 16, 16, 15);
    expect(decideMealNudge(s, now), isNotNull);
    final minutesNow = now.hour * 60 + now.minute;
    final states = CalWidgetStates.build(s, now);
    final stateForNow = CalWidgetStates.pick(states, minutesNow);
    final inMinutes = NotificationCoordinator.mealNudgeInMinutes(
      endMinute: stateForNow.endMinute,
      minutesNow: minutesNow,
    );
    expect(inMinutes, 15);
    expect(now.add(Duration(minutes: inMinutes)),
        DateTime(2026, 9, 16, 16, 30));
  });
}

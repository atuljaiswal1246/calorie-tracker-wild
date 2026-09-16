import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/profile.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('windows are learned from the user\'s own lunchtime, not a fixed one',
      () async {
    final s = await _storage();
    // Three days of late lunches (2:30pm) — the widget must say 2:30pm.
    final base = DateTime(2026, 9, 10);
    for (var d = 0; d < 3; d++) {
      await s.addEntry(_meal('l$d', DateTime(2026, 9, 10 + d, 14, 30), 'lunch', 300));
    }
    // Breakfast is already in today, so lunch is the pending meal.
    await s.addEntry(_meal('b', DateTime(2026, 9, 16, 8), 'breakfast', 300));
    final states = CalWidgetStates.build(s, DateTime(2026, 9, 16, 9));
    final due = states.firstWhere((x) => x.mood == WidgetMood.due);
    expect(due.context, contains('2:30pm'),
        reason: 'the widget must learn this user\'s own lunchtime');
    expect(due.learnedTime, isTrue);
    expect(due.hero, 'Lunch?');
    expect(due.pill, '+ Log lunch');
    final calm = states.firstWhere((x) => x.mood == WidgetMood.calm);
    expect(calm.endMinute, 13 * 60 + 30);
  });

  test('falls back to sensible times until there is history', () async {
    final s = await _storage();
    final states = CalWidgetStates.build(s, DateTime(2026, 9, 16, 6));
    final due = states.firstWhere((x) => x.mood == WidgetMood.due);
    expect(due.hero, 'Breakfast?');
    expect(due.learnedTime, isFalse,
        reason: 'without history we must not claim to know their time');
    expect(due.context, 'Takes about five seconds.');
  });

  test('logging every meal leaves one relaxed state for the rest of the day',
      () async {
    final s = await _storage();
    final day = DateTime(2026, 9, 16);
    for (final (i, m) in ['breakfast', 'lunch', 'dinner'].indexed) {
      await s.addEntry(_meal('m$i', DateTime(day.year, day.month, day.day, 8 + i * 4), m, 200));
    }
    final states = CalWidgetStates.build(s, DateTime(2026, 9, 16, 20));
    expect(states, hasLength(1));
    expect(states.single.mood, WidgetMood.done);
    expect(states.single.pill, isNull, reason: 'a closed day goes quiet');
  });

  test('going over budget overrides everything', () async {
    final s = await _storage();
    await s.addEntry(
        _meal('big', DateTime(2026, 9, 16, 12), 'lunch', 5000));
    final states = CalWidgetStates.build(s, DateTime(2026, 9, 16, 14));
    expect(states.single.mood, WidgetMood.over);
    expect(states.single.hero, contains('Over by'));
    expect(states.single.pill, isNull);
  });

  test('pick() chooses the window covering the minute', () async {
    final s = await _storage();
    final states = CalWidgetStates.build(s, DateTime(2026, 9, 16, 6));
    final morning = CalWidgetStates.pick(states, 6 * 60);
    final afternoon = CalWidgetStates.pick(states, 13 * 60);
    final night = CalWidgetStates.pick(states, 22 * 60);
    expect(morning.mood, WidgetMood.calm);
    expect(afternoon.mood, WidgetMood.due);
    expect(night.mood, WidgetMood.lastCall);
  });
}


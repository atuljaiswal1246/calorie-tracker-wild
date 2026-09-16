import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:calorie_tracker/services/widget_service.dart';
import 'package:calorie_tracker/services/widget_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _meal(String id, DateTime at, String type, int kcal) => FoodEntry(
      id: id,
      dateTime: at,
      mealType: type,
      imagePath: '',
      items: [FoodItem(name: 'x', calories: kcal, protein: 0, carbs: 0, fat: 0)],
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

  test('windows tile the day: no gaps, no overlaps, every minute covered',
      () async {
    final s = await _storage();
    // A few days of history so the learned times are in play, including a late
    // lunch and no breakfast at all.
    for (var d = 0; d < 4; d++) {
      await s.addEntry(_meal('l$d', DateTime(2026, 9, 10 + d, 14, 30), 'lunch', 400));
      await s.addEntry(_meal('d$d', DateTime(2026, 9, 10 + d, 21, 15), 'dinner', 500));
    }

    for (final hour in [5, 8, 12, 14, 17, 20, 22, 23]) {
      final now = DateTime(2026, 9, 16, hour, 30);
      final states = CalWidgetStates.build(s, now);
      expect(states, isNotEmpty);

      // sorted and non-overlapping
      for (var i = 1; i < states.length; i++) {
        expect(states[i].startMinute, greaterThanOrEqualTo(states[i - 1].endMinute),
            reason: 'windows must not overlap at $hour:30');
      }

      // every minute of the day resolves to a state whose window contains it
      for (var m = 0; m < 1440; m += 7) {
        final picked = CalWidgetStates.pick(states, m);
        final contains = m >= picked.startMinute && m < picked.endMinute;
        final isLast = picked == states.last && m >= states.last.startMinute;
        expect(contains || isLast, isTrue,
            reason: 'minute $m at $hour:30 fell outside every window');
      }
    }
  });

  test('the water widget callback logs a glass through the normal rules',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await storage.addWater(250);

    // What the widget's one-tap button runs in the background.
    await widgetInteractivityCallback(Uri.parse('calmatters://water?ml=250'));

    expect(storage.waterMlForDay(DateTime.now()), 500,
        reason: 'the widget must add to the same daily total as the app');
  });

  test('the callback defaults to one glass and ignores unrelated URIs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    await widgetInteractivityCallback(Uri.parse('calmatters://water'));
    expect(storage.waterMlForDay(DateTime.now()), WidgetService.glassMl);

    await widgetInteractivityCallback(Uri.parse('calmatters://somethingelse'));
    expect(storage.waterMlForDay(DateTime.now()), WidgetService.glassMl,
        reason: 'an unrelated deep link must not change anything');
  });

  test('day key is the local date, which is what resets the widget', () async {
    expect(WidgetService.dayKey(DateTime(2026, 9, 6, 23, 59)), '2026-09-06');
    expect(WidgetService.dayKey(DateTime(2026, 10, 1, 0, 0)), '2026-10-01');
  });
}

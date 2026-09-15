import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _entry(String id) => FoodEntry(
      id: id,
      dateTime: DateTime.now(),
      mealType: 'lunch',
      imagePath: '',
      items: [
        FoodItem(
          name: 'Dal Tadka',
          calories: 180,
          protein: 9,
          carbs: 22,
          fat: 6,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteEntry removes the meal', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    await storage.addEntry(_entry('a'));
    await storage.addEntry(_entry('b'));

    await storage.deleteEntry('a');

    expect(storage.entries.map((e) => e.id), ['b']);
  });

  test('restoreEntry puts a deleted meal back without re-awarding credit',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());

    var activityCalls = 0;
    storage.activityListener = (_) => activityCalls++;

    final entry = _entry('a');
    await storage.addEntry(entry);
    expect(activityCalls, 1, reason: 'logging the meal earns credit');

    await storage.deleteEntry('a');
    expect(storage.entries, isEmpty);

    await storage.restoreEntry(entry);
    expect(storage.entries.map((e) => e.id), ['a']);
    expect(activityCalls, 1,
        reason: 'undo must not award a second logging credit');
  });

  test('restoreEntry ignores an entry that is already present', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final entry = _entry('a');
    await storage.addEntry(entry);

    await storage.restoreEntry(entry);

    expect(storage.entries.length, 1);
  });
}

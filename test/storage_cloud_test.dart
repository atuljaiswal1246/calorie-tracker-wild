import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncUserDataFromCloud is a no-op when signed out (never throws)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    // No userId set -> must return early instead of touching Firestore.
    await storage.syncUserDataFromCloud();
    expect(storage.waterEntries, isEmpty);
    expect(storage.weightEntries, isEmpty);
    expect(storage.exercises, isEmpty);
  });

  test('local logging still works with no cloud user', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    await storage.addWater(250);
    await storage.addWeightEntry(70);
    expect(storage.waterMlForDay(DateTime.now()), 250);
    expect(storage.weightEntries.length, 1);
  });
}

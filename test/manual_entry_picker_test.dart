import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/screens/manual_entry_screen.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picker mode: ManualEntryScreen(picker: true) must return the chosen
/// FoodItem(s) via Navigator.pop WITHOUT writing to storage — this is how the
/// capture results add a food the AI missed (e.g. the 5th thali item).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: child,
      );

  Future<StorageService> freshStorage() async {
    SharedPreferences.setMockInitialValues({});
    return StorageService.init();
  }

  testWidgets('picker mode title reads "Add to meal"', (tester) async {
    final s = await freshStorage();
    await tester.pumpWidget(wrap(ManualEntryScreen(storage: s, picker: true)));
    await tester.pumpAndSettle();
    expect(find.text('Add to meal'), findsOneWidget);
    expect(find.text('Add food manually'), findsNothing);
  });

  testWidgets('picker mode returns the manually entered item without logging',
      (tester) async {
    final s = await freshStorage();
    final entryCountBefore = s.entries.length;

    List<FoodItem>? popped;
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<List<FoodItem>>(
              MaterialPageRoute(
                builder: (_) => ManualEntryScreen(
                  storage: s,
                  picker: true,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Default view shows the manual-entry shortcut.
    await tester.tap(find.text('Enter food manually'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Fill the custom food form. Note: the screen's search field is TextField
    // index 0; the sheet's fields are Food name (1), Calories (2), etc.
    await tester.enterText(find.byType(TextField).at(1), 'Sambar');
    await tester.enterText(find.byType(TextField).at(2), '120');
    await tester.tap(find.text('Log this food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(popped, isNotNull);
    expect(popped!.length, 1);
    expect(popped!.first.name, 'Sambar');
    expect(popped!.first.calories, 120);
    // Nothing was written to storage: same entry count, no recent foods.
    expect(s.entries.length, entryCountBefore);
    expect(s.recentFoods, isEmpty);
  });

  testWidgets('normal mode (not picker) still logs to storage',
      (tester) async {
    final s = await freshStorage();

    await tester.pumpWidget(wrap(ManualEntryScreen(storage: s, picker: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter food manually'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(1), 'Idli');
    await tester.enterText(find.byType(TextField).at(2), '150');
    await tester.tap(find.text('Log this food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(s.entries, isNotEmpty);
    expect(s.entries.first.items.first.name, 'Idli');
  });
}
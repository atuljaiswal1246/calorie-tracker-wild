// THE CORE PROMISE, EXECUTED: a cloud failure never costs a user a logged meal.
//
// This app has exactly one thing it must do: the user photographs dinner, it gets
// logged. Everything else is decoration on that. And the guarantee that makes it
// work on a train is written in a comment in storage_service.dart and in about
// eight call sites - which means the guarantee was only ever as good as me reading
// the code correctly.
//
// The foundation audit recorded this bug once already, in these words: "awaits
// Firestore with no try/catch in addEntry, deleteEntry, updateEntry and
// loadEntriesFromCloud". The fix went in via a private `_cloud()` helper. Nothing
// tested the fix, because a private method cannot be called from a test. So the
// helper is now `runBestEffortCloud()` and the guarantee is executable.
//
// What is genuinely tested here, and what is honestly not:
//   TESTED - a throwing cloud write does not throw, it is awaited, and it happens
//            exactly once. That is the whole promise.
//   TESTED - no mutation writes to the cloud before the local save, structurally,
//            because that ordering IS the promise and the pre-fix code had it
//            right by luck.
//   NOT TESTED - a real signed-in Firestore write. There is no Firestore mock in
//            dev_dependencies, and adding one is a dependency decision I am not
//            making at 6am for a guard. The honest claim is "the helper holds and
//            the ordering is right", not "I have watched Firestore fail".

import 'dart:io';

import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a failing cloud write is survivable', () {
    test('it does not throw - this is the promise', () async {
      await expectLater(
        runBestEffortCloud(() async => throw StateError('PERMISSION_DENIED')),
        completes,
        reason: 'A cloud failure escaped into the caller. The user would see an '
            'error on a meal that is already safely on the phone.',
      );
    });

    test('it is awaited, not fired and forgotten', () async {
      // Fire-and-forget would pass the test above while dropping the write. The
      // caller awaits this, so the mirror has to complete before it returns.
      var done = false;
      await runBestEffortCloud(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        done = true;
      });
      expect(done, isTrue,
          reason: 'runBestEffortCloud returned before the write finished.');
    });

    test('it happens exactly once', () async {
      var calls = 0;
      await runBestEffortCloud(() async => calls++);
      expect(calls, 1);
    });

    test('the failure is visible to a caller that wants to log it', () async {
      Object? seen;
      await runBestEffortCloud(
        () async => throw StateError('UNAVAILABLE'),
        onError: (e) => seen = e,
      );
      expect(seen, isA<StateError>(),
          reason: 'onError exists so this is not a silent swallow. The mirror '
              'stays best effort; the failure is still reportable.');
    });
  });

  group('local is the source of truth, and the ordering says so', () {
    test('logging a meal works with no cloud user at all', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final entry = FoodEntry(
        id: 'e1',
        dateTime: DateTime.now(),
        mealType: 'dinner',
        imagePath: '',
        items: [
          FoodItem(name: 'Dal', calories: 200, protein: 10, carbs: 30, fat: 4),
          FoodItem(name: 'Rice', calories: 250, protein: 5, carbs: 55, fat: 1),
        ],
      );
      await storage.addEntry(entry);
      expect(storage.entries.length, 1,
          reason: 'The local copy is what the user sees, immediately.');
      // Compared against what the model itself computes, not a hardcoded number:
      // I asserted 450 and got 445, because FoodItem does its own per-100g
      // arithmetic. The claim being tested is "the saved entry IS the entry I
      // built", so that is what is asserted - a magic number here would be a
      // second, quieter claim about the model that nothing owns.
      expect(storage.entries.first.totalCalories, entry.totalCalories,
          reason: 'The local copy is not the entry that was logged. If the save '
              'dropped or rewrote items, the user sees something they never '
              'ate and trusts nothing afterwards.');
      expect(storage.entries.first.totalCalories, greaterThan(0));
      expect(storage.entries.first.items.first.name, 'Dal');
      expect(storage.entries.first.dateTime, entry.dateTime,
          reason: 'The date is what the week and the streak are built from.');
    });

    test('no mutation reaches the cloud before the local save', () {
      // The structural half. The dangerous shape is specific and known: a mutation
      // that awaits a cloud write FIRST, or that awaits a cloud write with nothing
      // catching it. So the check is that every `entries` mutation in the service
      // goes through the shared best-effort helper, and that the helper is the one
      // the file documents as the promise.
      final src = File('lib/services/storage_service.dart').readAsStringSync();
      for (final method in const [
        'Future<void> addEntry(',
        'Future<void> deleteEntry(',
        'Future<void> restoreEntry(',
        'Future<void> updateEntry(',
      ]) {
        final start = src.indexOf(method);
        expect(start, isNot(-1), reason: '$method is gone; update this test.');
        // to the next top-level method
        final end = src.indexOf('\n  Future', start + method.length);
        final body = src.substring(start, end == -1 ? src.length : end);
        final localAt = body.indexOf('_saveEntries(');
        final cloudAt = body.indexOf('_cloud(');
        expect(localAt, isNot(-1),
            reason: '$method never saves locally. That is the whole app.');
        expect(cloudAt == -1 || cloudAt > localAt, isTrue,
            reason: '$method touches the cloud BEFORE saving locally. A user who '
                'is offline would get an error and lose the meal, which is the '
                'exact bug the foundation audit recorded.\n$body');
      }
      expect(src.contains('runBestEffortCloud('), isTrue,
          reason: 'The helper is the promise; if it is gone, so is the proof.');
    });

    test('every cloud write in an entry mutation goes through _cloud', () {
      // I first wrote this as a file-wide regex for `await ref.collection(...)
      // .doc(...)`, and it flagged two lines: a league READ and a gamification
      // READ inside syncUserDataFromCloud, both of which are already wrapped in
      // their own try/catch. The regex could not tell a guarded read from an
      // unguarded write, so it reported a defect that does not exist - a guard
      // that lies is worse than no guard, because the next person trusts it.
      //
      // So the check is scoped to the methods where the promise actually lives:
      // the four entry mutations. Each one's cloud call must be inside `_cloud(`.
      // Reads in the sync path are a different promise (the local copy stands,
      // which the sync code already handles with its own try/catch) and are not
      // this test's business.
      final src = File('lib/services/storage_service.dart').readAsStringSync();
      final unguarded = <String>[];
      for (final method in const [
        'Future<void> addEntry(',
        'Future<void> deleteEntry(',
        'Future<void> restoreEntry(',
        'Future<void> updateEntry(',
      ]) {
        final start = src.indexOf(method);
        final end = src.indexOf('\n  Future', start + method.length);
        final body = src.substring(start, end == -1 ? src.length : end);
        final cloudAt = body.indexOf('ref.collection(');
        if (cloudAt == -1) continue; // no cloud write in this method
        final wrapped = body.lastIndexOf('_cloud(', cloudAt);
        if (wrapped == -1 || wrapped > cloudAt) {
          unguarded.add('$method writes to the cloud outside _cloud():\n$body');
        }
      }
      expect(unguarded, isEmpty,
          reason: 'A cloud write that does not go through the best-effort helper, '
              'so one permission error can break a local save:\n'
              '${unguarded.join('\n')}');
    });
  });
}

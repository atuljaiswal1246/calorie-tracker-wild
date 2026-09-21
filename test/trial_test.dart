import 'package:calorie_tracker/services/storage_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return StorageService(await SharedPreferences.getInstance());
  }

  test('a new account starts inside the trial', () async {
    final s = await fresh();
    expect(s.accessLevel(), AccessLevel.trial);
    expect(s.trialStartedAt, isNull);
    expect(s.trialDaysLeft, StorageService.trialDays);
  });

  test('the trial starts once and never restarts', () async {
    final s = await fresh();
    await withClock(Clock.fixed(DateTime(2026, 9, 1, 9)), () async {
      await s.ensureTrialStarted();
    });
    expect(s.trialStartedAt, DateTime(2026, 9, 1, 9));

    // A later call must not move the date.
    await withClock(Clock.fixed(DateTime(2026, 9, 4, 9)), () async {
      await s.ensureTrialStarted();
    });
    expect(s.trialStartedAt, DateTime(2026, 9, 1, 9));
  });

  test('access stays full through day 7 and locks on day 8', () async {
    final s = await fresh();
    await withClock(Clock.fixed(DateTime(2026, 9, 1, 12)), () async {
      await s.ensureTrialStarted();
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 7, 12)), () async {
      expect(s.accessLevel(), AccessLevel.trial);
      expect(s.isLimited(), isFalse);
      expect(s.trialDaysLeft, 1);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 8, 13)), () async {
      expect(s.accessLevel(), AccessLevel.limited);
      expect(s.isLimited(), isTrue);
      expect(s.trialDaysLeft, 0);
    });
  });

  test('paying restores full access after the trial', () async {
    final s = await fresh();
    await withClock(Clock.fixed(DateTime(2026, 9, 1, 12)), () async {
      await s.ensureTrialStarted();
    });
    await withClock(Clock.fixed(DateTime(2026, 9, 20, 12)), () async {
      expect(s.isLimited(), isTrue);
      await s.savePaid(true);
      expect(s.accessLevel(), AccessLevel.full);
    });
  });

  test('the test override forces the states and clears', () async {
    final s = await fresh();
    await s.debugForceTrialExpired();
    expect(s.accessLevel(), AccessLevel.limited);

    await s.debugForceTrialActive();
    expect(s.accessLevel(), AccessLevel.trial);

    await s.debugClearTrialForce();
    expect(s.accessLevel(), AccessLevel.trial);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/models/gamification_state.dart';
import 'package:calorie_tracker/services/gamification_service.dart';

void main() {
  // Mutable clock so day rollover / cooldowns are deterministic.
  late DateTime now;
  late GamificationService svc;

  setUp(() {
    now = DateTime(2026, 9, 7, 12, 0); // a Monday
    svc = GamificationService(GamificationState(), clock: () => now);
  });

  DateTime at(int day, [int hour = 12, int minute = 0, int second = 0]) =>
      DateTime(2026, 9, day, hour, minute, second);

  group('Cal Points', () {
    test('awards action points and accumulates lifetime points', () {
      final r = svc.recordAction(GamificationAction.mealManual, at: at(7));
      expect(r.calPoints, 10);
      // Lifetime points include the 5-point daily streak bonus.
      expect(svc.state.calPoints, 15);
      expect(svc.state.todayPoints, 15);
    });

    test('meal scan is worth more than a manual meal', () {
      final r = svc.recordAction(GamificationAction.mealScan, at: at(7));
      expect(r.calPoints, 15);
    });

    test('enforces the per-action daily limit', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7, 8));
      svc.recordAction(GamificationAction.mealManual, at: at(7, 10));
      svc.recordAction(GamificationAction.mealManual, at: at(7, 12));
      final fourth = svc.recordAction(GamificationAction.mealManual, at: at(7, 14));
      expect(fourth.calPoints, 0);
      expect(fourth.reason, 'daily_limit');
      expect(svc.state.todayActions.where((k) => k == 'meal_manual').length, 3);
    });

    test('rejects a repeat of the same action within 60 seconds', () {
      svc.recordAction(GamificationAction.waterGoal, at: at(7, 12, 0));
      // water has a 1/day limit, so use a fresh action for the cooldown check.
      final first = svc.recordAction(GamificationAction.ashaChat, at: at(7, 12, 0));
      expect(first.calPoints, 5);
      final again = svc.recordAction(GamificationAction.ashaChat, at: at(7, 12, 0, 30));
      expect(again.reason, 'cooldown');
      expect(again.calPoints, 0);
    });

    test('never exceeds the 200/day cap', () {
      svc.state.todayPoints = 195;
      svc.state.logDay = GamificationService.dayKey(at(7));
      final r = svc.recordAction(GamificationAction.mealManual, at: at(7, 9));
      expect(r.calPoints, 5);
      expect(svc.state.todayPoints, 200);
      final next = svc.recordAction(GamificationAction.weightLog, at: at(7, 11));
      expect(next.calPoints, 0);
      expect(svc.state.todayPoints, 200);
    });

    test('daily points reset on a new day', () {
      svc.recordAction(GamificationAction.mealScan, at: at(7));
      expect(svc.state.todayPoints, greaterThan(0));
      svc.recordAction(GamificationAction.mealScan, at: at(8));
      expect(svc.state.todayPoints, 20);
    });
  });

  group('Levels', () {
    test('thresholds map to the plan table', () {
      expect(GamificationService.levelForPoints(0), 1);
      expect(GamificationService.levelForPoints(99), 1);
      expect(GamificationService.levelForPoints(100), 2);
      expect(GamificationService.levelForPoints(600), 4);
      expect(GamificationService.levelForPoints(6000), 10);
      expect(GamificationService.levelForPoints(7400), 11);
      expect(GamificationService.levelForPoints(20000), 20);
      expect(GamificationService.levelForPoints(25000), 21);
    });

    test('titles are stable', () {
      expect(GamificationService.titleForLevel(1), 'Sprout');
      expect(GamificationService.titleForLevel(4), 'Green Thumb');
      expect(GamificationService.titleForLevel(10), 'Nutrition Sage');
      expect(GamificationService.titleForLevel(11), 'Elite');
      expect(GamificationService.titleForLevel(21), 'Legend');
    });

    test('reports a level-up and progress toward the next level', () {
      svc.state.calPoints = 95;
      final r = svc.recordAction(GamificationAction.mealManual, at: at(7));
      expect(r.leveledUp, isTrue);
      expect(r.level, 2);
      expect(svc.level, 2);
      expect(svc.levelProgress, closeTo(10 / 200, 0.001));
      expect(svc.pointsToNextLevel, 190);
    });
  });

  group('Streaks', () {
    test('first qualifying action starts the streak at 1', () {
      final r = svc.recordAction(GamificationAction.mealManual, at: at(7));
      expect(r.streakAdvanced, isTrue);
      expect(r.streak, 1);
      expect(r.streakBonus, GamificationAction.streakDay.points);
    });

    test('consecutive days advance the streak', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7));
      final d2 = svc.recordAction(GamificationAction.waterGoal, at: at(8));
      expect(d2.streak, 2);
    });

    test('a second action on the same day does not double-advance', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7, 8));
      final r = svc.recordAction(GamificationAction.exerciseLog, at: at(7, 18));
      expect(r.streakAdvanced, isFalse);
      expect(r.streak, 1);
    });

    test('a missed day is covered by a freeze', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7));
      svc.recordAction(GamificationAction.mealManual, at: at(8));
      expect(svc.state.streak.freezeCount, StreakState.startingFreezes);
      // Skip day 9, log on day 10 -> one missed day, one freeze consumed.
      final r = svc.recordAction(GamificationAction.mealManual, at: at(10));
      expect(r.streak, 3);
      expect(svc.state.streak.freezeCount, 0);
    });

    test('a long gap without freezes resets the streak', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7));
      svc.state.streak.freezeCount = 0;
      final r = svc.recordAction(GamificationAction.mealManual, at: at(12));
      expect(r.streak, 1);
      expect(svc.state.streak.longest, 1);
    });

    test('longest streak is remembered', () {
      svc.recordAction(GamificationAction.mealManual, at: at(7));
      svc.recordAction(GamificationAction.mealManual, at: at(8));
      svc.recordAction(GamificationAction.mealManual, at: at(9));
      svc.state.streak.freezeCount = 0;
      svc.recordAction(GamificationAction.mealManual, at: at(20));
      expect(svc.state.streak.current, 1);
      expect(svc.state.streak.longest, 3);
    });

    test('hitting 7 days grants the milestone reward and a freeze', () {
      final before = svc.state.nutriCoins;
      for (var day = 7; day < 14; day++) {
        final r = svc.recordAction(GamificationAction.mealManual, at: at(day));
        if (day == 13) {
          expect(r.milestone, 7);
        }
      }
      expect(svc.state.streak.current, 7);
      // 7× meal (10) + 7× streak (5) + milestone 25 = 130.
      expect(svc.state.calPoints, 130);
      expect(svc.state.nutriCoins - before, 50);
      expect(svc.state.streak.freezeCount, greaterThan(0));
    });

    test('weight and water count as qualifying actions', () {
      final r = svc.recordAction(GamificationAction.weightLog, at: at(7));
      expect(r.streakAdvanced, isTrue);
    });
  });

  group('NutriCoins', () {
    test('daily login pays out once per day', () {
      expect(svc.recordDailyLogin(at: at(7)), 5);
      expect(svc.recordDailyLogin(at: at(7, 20)), 0);
      expect(svc.recordDailyLogin(at: at(8)), 5);
      expect(svc.state.nutriCoins, 10);
    });

    test('completing all three quests pays the bonus', () {
      svc.recordAction(GamificationAction.questComplete, at: at(7, 9));
      svc.recordAction(GamificationAction.questComplete, at: at(7, 12));
      final third = svc.recordAction(GamificationAction.questComplete, at: at(7, 15));
      expect(svc.state.todayQuests, 3);
      expect(svc.state.todayActions.contains('quest_bonus'), isTrue);
      expect(third.nutriCoins, 30); // 10 quest + 20 bonus
    });

    test('spendCoins refuses when the balance is too low', () {
      svc.state.nutriCoins = 50;
      expect(svc.spendCoins(100), isFalse);
      expect(svc.state.nutriCoins, 50);
      expect(svc.spendCoins(50), isTrue);
      expect(svc.state.nutriCoins, 0);
    });

    test('freezes respect the bank cap', () {
      svc.state.streak.freezeCount = 0;
      expect(svc.addFreezes(5), StreakState.maxFreezeBank);
      expect(svc.addFreezes(1), 0);
    });
  });

  group('Weekly league points', () {
    test('sums Monday–Sunday only', () {
      now = DateTime(2026, 9, 7, 12); // Monday
      svc.recordAction(GamificationAction.mealManual, at: at(7)); // 10
      svc.recordAction(GamificationAction.mealManual, at: at(9)); // 10
      svc.recordAction(GamificationAction.mealManual, at: at(13)); // 10
      svc.recordAction(GamificationAction.mealManual, at: at(14, 9)); // next week
      expect(svc.pointsThisWeek(at: now), 45);
    });
  });

  group('JSON', () {
    test('round-trips through toJson/fromJson', () {
      svc.recordAction(GamificationAction.mealScan, at: at(7));
      svc.recordAction(GamificationAction.waterGoal, at: at(8));
      svc.recordDailyLogin(at: at(8));
      final json = svc.state.toJson();
      final restored = GamificationState.fromJson(json);
      expect(restored.calPoints, svc.state.calPoints);
      expect(restored.nutriCoins, svc.state.nutriCoins);
      expect(restored.streak.current, svc.state.streak.current);
      expect(restored.streak.longest, svc.state.streak.longest);
      expect(restored.streak.freezeCount, svc.state.streak.freezeCount);
      expect(restored.logDay, svc.state.logDay);
      expect(restored.todayPoints, svc.state.todayPoints);
      expect(restored.pointsByDay, svc.state.pointsByDay);
      expect(restored.lastLoginDay, svc.state.lastLoginDay);
    });
  });
}

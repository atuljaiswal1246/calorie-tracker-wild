import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/models/gamification_state.dart';
import 'package:calorie_tracker/models/quest.dart';
import 'package:calorie_tracker/services/gamification_service.dart';
import 'package:calorie_tracker/services/quest_service.dart';

void main() {
  late GamificationService gami;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 9, 7, 12); // Monday
    gami = GamificationService(GamificationState(), clock: () => now);
  });

  QuestService serviceWith(List<String> ids) => QuestService(
        gami,
        quests: [
          for (final id in ids)
            ActiveQuest(template: QuestService.templateById(id)!),
        ],
      );

  group('generation', () {
    test('produces three quests including at least one easy one', () {
      final qs = QuestService(gami, rng: Random(1));
      final list = qs.generate(at: now);
      expect(list.length, 3);
      expect(list.where((q) => q.template.easy), isNotEmpty);
      expect(qs.isForDay(now), isTrue);
      expect(qs.needsGeneration(now), isFalse);
    });

    test('excludes yesterday\'s quests', () {
      final qs = QuestService(gami, rng: Random(7));
      final list = qs.generate(at: now, excludeIds: {'photo_scan'});
      expect(list.any((q) => q.id == 'photo_scan'), isFalse);
    });

    test('never includes more than one nutrition-quality quest', () {
      final priority = {
        for (final t in QuestService.pool)
          if (t.nutritionQuality) t.metric: 100,
      };
      for (var seed = 0; seed < 25; seed++) {
        final qs = QuestService(gami, rng: Random(seed));
        final list = qs.generate(at: now, priority: priority);
        final nutrition = list.where((q) => q.template.nutritionQuality);
        expect(nutrition.length, lessThanOrEqualTo(1));
      }
    });

    test('weights selection toward the weakest area', () {
      var picked = 0;
      for (var seed = 0; seed < 40; seed++) {
        final qs = QuestService(gami, rng: Random(seed));
        final list = qs.generate(at: now, priority: {QuestMetric.exercise: 20});
        if (list.any((q) => q.template.metric == QuestMetric.exercise)) {
          picked++;
        }
      }
      // Heavily weighted metric should show up in a clear majority of sets.
      expect(picked, greaterThan(20));
    });

    test('regenerates on a new day', () {
      final qs = QuestService(gami, rng: Random(3));
      qs.generate(at: now);
      expect(qs.needsGeneration(DateTime(2026, 9, 8)), isTrue);
    });
  });

  group('progress', () {
    test('multi-target quests complete only at their target', () {
      final qs = serviceWith(['all_three_meals']);
      final quest = qs.quests.first;
      expect(qs.report(QuestMetric.mealsLogged), isEmpty);
      expect(qs.report(QuestMetric.mealsLogged), isEmpty);
      final done = qs.report(QuestMetric.mealsLogged);
      expect(done, hasLength(1));
      expect(quest.completed, isTrue);
      expect(quest.current, 3);
      expect(qs.completedCount, 1);
    });

    test('ignores unrelated metrics', () {
      final qs = serviceWith(['water_goal']);
      expect(qs.report(QuestMetric.exercise), isEmpty);
      expect(qs.quests.first.current, 0);
    });
  });

  group('rewards', () {
    test('claim pays the template points plus NutriCoins', () {
      final qs = serviceWith(['photo_scan']); // 15 pts
      qs.report(QuestMetric.mealScan);
      final r = qs.claim(qs.quests.first, at: now);
      expect(r.calPoints, 15);
      expect(r.nutriCoins, 10);
      // Quest completion itself must not touch calories or streak metrics.
      expect(gami.state.todayQuests, 1);
    });

    test('claiming twice pays once', () {
      final qs = serviceWith(['water_goal']);
      qs.report(QuestMetric.waterGoal);
      qs.claim(qs.quests.first, at: now);
      final again = qs.claim(qs.quests.first, at: now);
      expect(again.calPoints, 0);
      expect(again.reason, 'already_claimed');
    });

    test('claiming an incomplete quest does nothing', () {
      final qs = serviceWith(['protein_goal']);
      final r = qs.claim(qs.quests.first, at: now);
      expect(r.calPoints, 0);
      expect(r.reason, 'not_completed');
    });

    test('completing all three quests triggers the engine bonus', () {
      final qs = serviceWith(['photo_scan', 'water_goal', 'morning_weight']);
      qs.report(QuestMetric.mealScan);
      qs.report(QuestMetric.waterGoal);
      qs.report(QuestMetric.weightLog);
      final total = qs.claimAll(at: now);
      expect(gami.state.todayQuests, 3);
      expect(qs.allCompleted, isTrue);
      // 15 + 10 + 5 quest points + 25 completionist bonus.
      expect(total.calPoints, 55);
      // 3×10 quest coins + 20 completionist bonus.
      expect(total.nutriCoins, 50);
    });
  });

  group('persistence', () {
    test('round-trips through toJson/fromJson', () {
      final qs = serviceWith(['all_three_meals']);
      qs.report(QuestMetric.mealsLogged);
      qs.day = GamificationService.dayKey(now);
      final restored =
          QuestService.fromJson(gami, qs.toJson());
      expect(restored.day, qs.day);
      expect(restored.quests, hasLength(1));
      expect(restored.quests.first.id, 'all_three_meals');
      expect(restored.quests.first.current, 1);
    });

    test('drops unknown quest ids without throwing', () {
      final restored = QuestService.fromJson(gami, {
        'day': '2026-09-07',
        'quests': [
          {'id': 'does_not_exist', 'current': 2},
          {'id': 'water_goal', 'current': 1, 'completed': true, 'claimed': false},
        ],
      });
      expect(restored.quests, hasLength(1));
      expect(restored.quests.first.id, 'water_goal');
      expect(restored.quests.first.completed, isTrue);
    });
  });
}

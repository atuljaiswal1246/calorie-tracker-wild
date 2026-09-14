/// App-level gamification controller.
///
/// Owns the single [GamificationService] + [QuestService] for the running app,
/// listens for real user activity (meals, water, weight, exercise, Asha chats),
/// feeds it through the engine, advances quests, and persists everything.
///
/// Screens read live values from here and rebuild on [revision]. The controller
/// is deliberately forgiving: it never throws into a logging path, and if it is
/// absent the app behaves exactly as before.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/gamification_state.dart';
import '../models/quest.dart';
import 'gamification_service.dart';
import 'quest_service.dart';
import 'storage_service.dart';

/// A small reward moment for the UI to surface (module 4 turns these into
/// toasts / confetti / full-screen celebrations).
class CelebrationEvent {
  final String kind; // points | streak | milestone | level | quest
  final String message;
  final int amount;

  const CelebrationEvent(this.kind, this.message, {this.amount = 0});
}

class GamificationController {
  /// The running app's controller (set by [init]); screens read this.
  static GamificationController? instance;

  final StorageService storage;

  late GamificationState state;
  late GamificationService service;
  late QuestService quests;

  /// Bumped whenever anything changes so the UI can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Unconsumed celebration moments, oldest first.
  final List<CelebrationEvent> celebrations = [];

  GamificationController(this.storage);

  Future<void> init({DateTime? at}) async {
    instance = this;
    final now = at ?? DateTime.now();
    state = storage.gamification;
    service = GamificationService(state);

    final raw = storage.getQuestBoardRaw();
    quests = raw == null
        ? QuestService(service)
        : QuestService.fromJson(service, raw);

    service.recordDailyLogin(at: now);
    if (quests.needsGeneration(now)) {
      quests.generate(at: now, excludeIds: quests.previousIds.toSet());
    }

    storage.activityListener = _onActivity;
    await persist();
    _bump();
  }

  Future<void> persist() async {
    await storage.saveGamification(state);
    await storage.saveQuestBoard(quests.toJson());
  }

  void _bump() => revision.value = revision.value + 1;

  // ── Live values for the UI ────────────────────────────────────────────
  int get calPoints => state.calPoints;
  int get nutriCoins => state.nutriCoins;
  int get level => service.level;
  String get levelTitle => service.levelTitle;
  double get levelProgress => service.levelProgress;
  int get pointsToNextLevel => service.pointsToNextLevel;
  int get streak => state.streak.current;
  int get longestStreak => state.streak.longest;
  int get freezes => state.streak.freezeCount;
  int get todayPoints => state.todayPoints;
  int get weeklyPoints => service.pointsThisWeek();
  List<ActiveQuest> get activeQuests => quests.quests;
  int get questsCompleted => quests.completedCount;

  CelebrationEvent? takeCelebration() =>
      celebrations.isEmpty ? null : celebrations.removeAt(0);

  // ── Activity hooks ────────────────────────────────────────────────────

  void _onActivity(StorageActivity activity) {
    final now = DateTime.now();
    switch (activity) {
      case StorageActivity.mealLogged:
        apply(GamificationAction.mealManual,
            metrics: {QuestMetric.mealsLogged: 1}, now: now);
        break;
      case StorageActivity.mealScanned:
        apply(GamificationAction.mealScan,
            metrics: {QuestMetric.mealScan: 1, QuestMetric.mealsLogged: 1},
            now: now);
        break;
      case StorageActivity.waterLogged:
        apply(GamificationAction.waterGoal,
            metrics: {QuestMetric.waterGoal: 1}, now: now);
        break;
      case StorageActivity.weightLogged:
        apply(GamificationAction.weightLog,
            metrics: {QuestMetric.weightLog: 1}, now: now);
        break;
      case StorageActivity.exerciseLogged:
        apply(GamificationAction.exerciseLog,
            metrics: {QuestMetric.exercise: 1}, now: now);
        break;
    }
  }

  /// Called by the Asha chat screen after a conversation turn.
  void recordAshaChat() => apply(GamificationAction.ashaChat,
      metrics: {QuestMetric.ashaChat: 1});

  /// Record [action], advance any matching quests, auto-claim completed
  /// quests, queue celebrations and persist. Returns the action's reward.
  RewardResult apply(
    GamificationAction action, {
    Map<QuestMetric, int> metrics = const {},
    DateTime? now,
  }) {
    final when = now ?? DateTime.now();
    final result = service.recordAction(action, at: when);

    if (result.calPoints > 0) {
      celebrations.add(CelebrationEvent(
          'points', '+${result.calPoints} Cal Points', amount: result.calPoints));
    }
    if (result.milestone != null) {
      celebrations.add(CelebrationEvent('milestone',
          '${result.milestone}-day streak!', amount: result.milestone!));
    } else if (result.streakAdvanced) {
      celebrations.add(const CelebrationEvent('streak', 'Streak extended'));
    }
    if (result.leveledUp) {
      celebrations.add(CelebrationEvent(
          'level', 'Level ${result.level} · ${service.levelTitle}',
          amount: result.level));
    }

    metrics.forEach((metric, amount) {
      for (final q in quests.report(metric, amount: amount)) {
        celebrations.add(CelebrationEvent(
            'quest', q.template.title, amount: q.calPoints));
      }
    });

    final claimed = quests.claimAll(at: when);
    if (claimed.calPoints > 0) {
      celebrations.add(CelebrationEvent('points',
          '+${claimed.calPoints} Cal Points from quests',
          amount: claimed.calPoints));
    }

    final levelBefore = result.level;
    final reward = RewardResult(
      calPoints: result.calPoints,
      bonusCalPoints: result.bonusCalPoints + claimed.calPoints,
      nutriCoins: result.nutriCoins + claimed.nutriCoins,
      streakBonus: result.streakBonus,
      milestone: result.milestone,
      streakAdvanced: result.streakAdvanced,
      streak: result.streak,
      leveledUp: result.leveledUp,
      level: levelBefore,
      reason: result.reason,
    );

    // Fire-and-forget persistence — never block the logging path.
    unawaited(persist());
    _bump();
    return reward;
  }

  /// Regenerate today's quests on demand (e.g. after midnight).
  void refreshQuests({DateTime? at}) {
    final when = at ?? DateTime.now();
    quests.generate(at: when, excludeIds: quests.previousIds.toSet());
    unawaited(persist());
    _bump();
  }
}

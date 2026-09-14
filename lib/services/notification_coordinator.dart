/// Glue between the notification engine and the app.
///
/// Called on app open: it derives the user's engagement state from their latest
/// activity, learns the session hour, selects a state-appropriate message and
/// schedules it around the user's usual time — respecting the fatigue
/// guardrails. Persists the engine state afterwards.
library;

import '../models/notification_state.dart';
import 'analytics_service.dart';
import 'experiment_service.dart';
import 'notification_engine.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class NotificationCoordinator {
  /// The most recent qualifying action across all trackers.
  static DateTime? lastActivity(StorageService storage) {
    final candidates = <DateTime>[
      ...storage.entries.map((e) => e.dateTime),
      ...storage.waterEntries.map((e) => e.date),
      ...storage.weightEntries.map((e) => e.date),
      ...storage.exercises.map((e) => e.dateTime),
    ];
    final streakDate = storage.gamification.streak.lastActionDate;
    if (streakDate != null) candidates.add(streakDate);
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Re-evaluate state and schedule at most one nudge. Safe to call often.
  static Future<void> refresh(StorageService storage, {DateTime? at}) async {
    final when = at ?? DateTime.now();
    final state = NotificationState.fromJson(
        storage.notificationStateRaw ?? const <String, dynamic>{});
    final engine = NotificationEngine(state);

    engine.updateState(lastActivity(storage), at: when);
    engine.recordSessionOpen(when);

    final name = storage.profile?.name.split(' ').first ?? 'there';
    final streak = storage.gamification.streak.current;
    final tone = ExperimentService.notifToneVariant();
    AnalyticsService.log('experiment_exposure', {
      'experiment': ExperimentService.notifTone,
      'variant': tone,
    });
    final message =
        engine.select(name: name, streak: streak, tone: tone, at: when);

    if (message != null) {
      await NotificationService.scheduleEngineNudge(
        preferredHour: state.preferredHour,
        title: message.title,
        body: message.body,
      );
      engine.recordSent(message, at: when);
    }

    await storage.saveNotificationState(state.toJson());
  }
}

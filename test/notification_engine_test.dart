import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/models/notification_state.dart';
import 'package:calorie_tracker/services/notification_engine.dart';

void main() {
  late DateTime now;
  late NotificationEngine engine;

  setUp(() {
    now = DateTime(2026, 9, 7, 12);
    engine = NotificationEngine(NotificationState(), clock: () => now,
        rng: Random(1));
  });

  group('state classification', () {
    test('maps recency to the four states', () {
      UserState at(Duration gap) =>
          NotificationEngine.classify(now.subtract(gap), now: now);
      expect(at(const Duration(hours: 2)), UserState.active);
      expect(at(const Duration(hours: 30)), UserState.wobbling);
      expect(at(const Duration(hours: 60)), UserState.atRisk);
      expect(at(const Duration(days: 8)), UserState.dormant);
      expect(NotificationEngine.classify(null, now: now), UserState.dormant);
    });

    test('updateState records a state change', () {
      final changed = engine.updateState(now.subtract(const Duration(hours: 30)));
      expect(changed, isTrue);
      expect(engine.state.state, UserState.wobbling);
      expect(engine.state.lastStateChange, now);
      expect(engine.updateState(now.subtract(const Duration(hours: 31))), isFalse);
    });
  });

  group('guardrails', () {
    test('is silent 22:00–07:00', () {
      expect(engine.canSend(DateTime(2026, 9, 7, 23)), isFalse);
      expect(engine.canSend(DateTime(2026, 9, 7, 6)), isFalse);
      expect(engine.canSend(DateTime(2026, 9, 7, 12)), isTrue);
    });

    test('caps at 3 per day', () {
      for (var i = 0; i < 3; i++) {
        engine.recordSent(NotificationMessage(
            id: 't$i', state: UserState.active, title: '', body: ''));
      }
      expect(engine.canSend(now), isFalse);
    });

    test('caps at 15 per week', () {
      engine.state.sentAt = [
        for (var i = 0; i < 15; i++)
          now.subtract(Duration(days: 2, hours: i)).toIso8601String(),
      ];
      expect(engine.canSend(now), isFalse);
    });

    test('3 ignored notifications trigger a 7-day cooldown', () {
      engine.recordDismiss();
      engine.recordDismiss();
      expect(engine.canSend(now), isTrue);
      engine.recordDismiss();
      expect(engine.state.suppressUntil, isNotNull);
      expect(engine.canSend(now), isFalse);
      // Cooldown expires after 7 days.
      expect(engine.canSend(now.add(const Duration(days: 8))), isTrue);
    });

    test('opening the app resets the ignore streak', () {
      engine.recordDismiss();
      engine.recordDismiss();
      engine.recordOpen();
      engine.recordDismiss();
      expect(engine.state.suppressUntil, isNull);
    });

    test('the same template is not repeated within 48h', () {
      engine.state.state = UserState.active;
      engine.recordSent(NotificationMessage(
          id: 'active_points_today', state: UserState.active, title: '', body: ''));
      engine.recordSent(NotificationMessage(
          id: 'active_water', state: UserState.active, title: '', body: ''));
      final when = DateTime(2026, 9, 7, 18);
      final picked = engine.select(name: 'Atul', streak: 5, at: when);
      expect(picked, isNotNull);
      expect(picked!.id, isNot('active_points_today'));
      expect(picked.id, isNot('active_water'));
      // After 48h it is eligible again.
      engine.state.lastTemplateAt.clear();
      expect(engine.select(name: 'Atul', streak: 5,
          at: when.add(const Duration(hours: 49))), isNotNull);
    });
  });

  group('selection', () {
    test('returns a state-appropriate message with variables filled', () {
      engine.state.state = UserState.wobbling;
      final when = DateTime(2026, 9, 7, 20);
      final msg = engine.select(name: 'Atul', streak: 12, at: when);
      expect(msg, isNotNull);
      expect(msg!.state, UserState.wobbling);
      expect(msg.body, contains('Atul'));
      expect(msg.body, contains('12'));
    });

    test('respects per-template time windows', () {
      engine.state.state = UserState.wobbling;
      // 13:00 falls between the morning and afternoon windows → nothing.
      final msg = engine.select(name: 'A', streak: 3,
          at: DateTime(2026, 9, 7, 13));
      expect(msg, isNull);
    });

    test('draws from the requested tone pool, falling back when empty', () {
      engine.state.state = UserState.active;
      final when = DateTime(2026, 9, 7, 18);
      final playful =
          engine.select(name: 'A', streak: 5, tone: 'playful', at: when);
      expect(playful, isNotNull);
      expect(
          [
            'active_points_today',
            'active_league_saturday',
            'active_water',
          ],
          contains(playful!.id));
      // An unknown tone has no eligible templates, so it falls back.
      expect(engine.select(name: 'A', streak: 5, tone: 'zzz', at: when),
          isNotNull);
    });

    test('stops re-engaging a dormant user after two nudges', () {
      engine.state.state = UserState.dormant;
      final when = DateTime(2026, 9, 7, 12);
      for (final id in ['dormant_weekly', 'dormant_summary']) {
        engine.recordSent(NotificationMessage(
            id: id, state: UserState.dormant, title: '', body: ''));
      }
      expect(engine.select(name: 'A', streak: 0, at: when), isNull);
    });
  });

  group('timing', () {
    test('learns the modal session hour', () {
      expect(NotificationEngine.preferredHourFrom([]), -1);
      expect(NotificationEngine.preferredHourFrom([9, 9, 9, 20]),
          9);
      expect(NotificationEngine.preferredHourFrom([8, 8, 20, 20]), 8);
    });

    test('recordSessionOpen tracks opens and preferred hour', () {
      for (final h in [19, 19, 8]) {
        engine.recordSessionOpen(DateTime(2026, 9, 7, h));
      }
      expect(engine.state.preferredHour, 19);
    });
  });

  test('state round-trips through JSON', () {
    engine.updateState(now.subtract(const Duration(hours: 30)));
    engine.recordSessionOpen(DateTime(2026, 9, 7, 20));
    engine.recordSent(NotificationMessage(
        id: 'x', state: UserState.wobbling, title: '', body: ''));
    final restored = NotificationState.fromJson(engine.state.toJson());
    expect(restored.state, engine.state.state);
    expect(restored.preferredHour, 20);
    expect(restored.sentAt.length, 1);
    expect(restored.lastTemplateAt.containsKey('x'), isTrue);
  });
}

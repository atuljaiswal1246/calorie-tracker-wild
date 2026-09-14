/// State-based notification engine (plan §5).
///
/// Chooses a message from a template pool based on the user's engagement state,
/// the time of day, recent send history and the fatigue guardrails. Delivery
/// (FCM / local notifications) is the caller's job — this class is pure logic
/// over a [NotificationState], so it is fully unit-testable.
library;

import 'dart:math';

import '../models/notification_state.dart';

/// A ready-to-send notification.
class NotificationMessage {
  final String id;
  final UserState state;
  final String title;
  final String body;

  const NotificationMessage({
    required this.id,
    required this.state,
    required this.title,
    required this.body,
  });

  @override
  String toString() => 'NotificationMessage($id, ${state.key}, $title)';
}

class _Template {
  final String id;
  final UserState state;
  final int startHour;
  final int endHour; // exclusive; a window may wrap midnight
  final String Function(Map<String, String> v) title;
  final String Function(Map<String, String> v) body;

  const _Template({
    required this.id,
    required this.state,
    required this.title,
    required this.body,
    this.startHour = 7,
    this.endHour = 22,
  });
}

class NotificationEngine {
  final NotificationState state;
  final DateTime Function() _now;
  final Random _rng;

  NotificationEngine(this.state, {DateTime Function()? clock, Random? rng})
      : _now = clock ?? DateTime.now,
        _rng = rng ?? Random();

  // ── Guardrails (plan §5.4) ────────────────────────────────────────────
  static const int silentStartHour = 22; // inclusive
  static const int silentEndHour = 7; // exclusive
  static const int dailyCap = 3;
  static const int weeklyCap = 15;
  static const int ignoreCooldownDays = 7;
  static const int dismissStreakForCooldown = 3;
  static const int dormantReengagementCap = 2;

  // ── State thresholds (plan §5.1) ──────────────────────────────────────
  static const Duration wobblingAfter = Duration(hours: 24);
  static const Duration atRiskAfter = Duration(hours: 48);
  static const Duration dormantAfter = Duration(hours: 168);

  /// Classify the user by how long since their last qualifying action.
  static UserState classify(DateTime? lastActivity, {required DateTime now}) {
    if (lastActivity == null) return UserState.dormant;
    final gap = now.difference(lastActivity);
    if (gap >= dormantAfter) return UserState.dormant;
    if (gap >= atRiskAfter) return UserState.atRisk;
    if (gap >= wobblingAfter) return UserState.wobbling;
    return UserState.active;
  }

  /// Update the stored state from activity. Returns true if it changed.
  bool updateState(DateTime? lastActivity, {DateTime? at}) {
    final when = at ?? _now();
    final next = classify(lastActivity, now: when);
    if (next == state.state) return false;
    state.state = next;
    state.lastStateChange = when;
    if (next != UserState.dormant) state.reengagementSent = <String>[];
    return true;
  }

  /// Whether anything may be sent at [when] (silent hours + caps + cooldown).
  bool canSend(DateTime when) {
    final hour = when.hour;
    if (hour >= silentStartHour || hour < silentEndHour) return false;
    final until = state.suppressUntil;
    if (until != null && until.isAfter(when)) return false;
    if (_sentSince(when.subtract(const Duration(days: 1))) >= dailyCap) {
      return false;
    }
    if (_sentSince(when.subtract(const Duration(days: 7))) >= weeklyCap) {
      return false;
    }
    return true;
  }

  int _sentSince(DateTime from) => state.sentAt
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .where((t) => !t.isBefore(from) && !t.isAfter(_now().add(const Duration(minutes: 1))))
      .length;

  /// Pick a message for the current state and time, or null if none qualifies.
  NotificationMessage? select({
    required String name,
    required int streak,
    int? leaguePosition,
    DateTime? at,
  }) {
    final when = at ?? _now();
    if (!canSend(when)) return null;
    if (state.state == UserState.dormant &&
        state.reengagementSent.length >= dormantReengagementCap) {
      return null;
    }

    final vars = <String, String>{
      'name': name,
      'streak': '$streak',
      'milestone': '${_nextMilestone(streak)}',
      'position': '${leaguePosition ?? 0}',
    };

    final candidates = _templates
        .where((t) => t.state == state.state)
        .where((t) => _inWindow(t, when.hour))
        .where((t) => !_sentWithin(t.id, when, const Duration(hours: 48)))
        .toList();
    if (candidates.isEmpty) return null;

    final t = candidates[_rng.nextInt(candidates.length)];
    return NotificationMessage(
      id: t.id,
      state: t.state,
      title: t.title(vars),
      body: t.body(vars),
    );
  }

  bool _inWindow(_Template t, int hour) {
    if (t.startHour <= t.endHour) {
      return hour >= t.startHour && hour < t.endHour;
    }
    return hour >= t.startHour || hour < t.endHour; // wraps midnight
  }

  bool _sentWithin(String id, DateTime when, Duration window) {
    final iso = state.lastTemplateAt[id];
    if (iso == null) return false;
    final last = DateTime.tryParse(iso);
    if (last == null) return false;
    return when.difference(last).abs() < window;
  }

  static int _nextMilestone(int streak) {
    for (final m in const [7, 14, 30, 50, 100, 365]) {
      if (streak < m) return m;
    }
    return streak + 100;
  }

  /// Record that [message] was sent (updates caps, dedup and re-engagement).
  void recordSent(NotificationMessage message, {DateTime? at}) {
    final when = at ?? _now();
    final iso = when.toIso8601String();
    state.lastNotificationSent = when;
    state.lastTemplateAt[message.id] = iso;
    state.sentAt.add(iso);
    if (state.sentAt.length > 40) {
      state.sentAt = state.sentAt.sublist(state.sentAt.length - 40);
    }
    if (message.state == UserState.dormant &&
        !state.reengagementSent.contains(message.id)) {
      state.reengagementSent.add(message.id);
    }
  }

  /// The user dismissed a notification without opening the app.
  void recordDismiss({DateTime? at}) {
    final when = at ?? _now();
    state.consecutiveDismisses += 1;
    if (state.consecutiveDismisses >= dismissStreakForCooldown) {
      state.suppressUntil =
          when.add(const Duration(days: ignoreCooldownDays));
      state.consecutiveDismisses = 0;
    }
  }

  /// The user opened the app — clears the ignore streak.
  void recordOpen() {
    state.consecutiveDismisses = 0;
  }

  /// Record an app-open hour so timing can be personalised (plan §5.3).
  void recordSessionOpen(DateTime when) {
    state.sessionHours.add(when.hour);
    if (state.sessionHours.length > 20) {
      state.sessionHours =
          state.sessionHours.sublist(state.sessionHours.length - 20);
    }
    state.preferredHour = preferredHourFrom(state.sessionHours);
  }

  /// The modal session hour, or -1 when there is not enough data.
  static int preferredHourFrom(List<int> hours) {
    if (hours.isEmpty) return -1;
    final counts = <int, int>{};
    for (final h in hours) {
      counts[h] = (counts[h] ?? 0) + 1;
    }
    var best = -1;
    var bestCount = 0;
    counts.forEach((h, c) {
      // Ties resolve to the earlier hour for determinism.
      if (c > bestCount || (c == bestCount && (best == -1 || h < best))) {
        best = h;
        bestCount = c;
      }
    });
    return best;
  }

  /// A fresh state for [name], used when there is no history yet.
  static NotificationState fresh() => NotificationState();

  // ── Template catalogue (plan §5.2 + Appendix B) ───────────────────────
  static final List<_Template> _templates = [
    // Active
    _Template(
      id: 'active_streak_keep',
      state: UserState.active,
      startHour: 17,
      endHour: 20,
      title: (v) => 'Keep your streak alive 🔥',
      body: (v) =>
          'Your streak is at ${v['streak']} days! One scan keeps it alive.',
    ),
    _Template(
      id: 'active_points_today',
      state: UserState.active,
      startHour: 8,
      endHour: 21,
      title: (v) => 'Points on the board 💪',
      body: (v) => "You're building momentum — log your next meal in 15 seconds.",
    ),
    _Template(
      id: 'active_league_saturday',
      state: UserState.active,
      startHour: 18,
      endHour: 21,
      title: (v) => 'League ending soon 🏆',
      body: (v) =>
          "You're #${v['position']}. Can you clinch the top spots before Sunday?",
    ),
    _Template(
      id: 'active_quest_waiting',
      state: UserState.active,
      startHour: 19,
      endHour: 21,
      title: (v) => 'Quests still waiting 📋',
      body: (v) => 'A couple of quick quests are open. Finish them before midnight!',
    ),
    _Template(
      id: 'active_water',
      state: UserState.active,
      startHour: 15,
      endHour: 20,
      title: (v) => 'Hydration check 💧',
      body: (v) => "Still some water to go — you've got this.",
    ),

    // Wobbling
    _Template(
      id: 'wobble_morning',
      state: UserState.wobbling,
      startHour: 8,
      endHour: 11,
      title: (v) => 'Fresh start ✨',
      body: (v) =>
          "Missed yesterday? No worries — one quick log gets you back on track today.",
    ),
    _Template(
      id: 'wobble_afternoon',
      state: UserState.wobbling,
      startHour: 15,
      endHour: 17,
      title: (v) => 'Save your streak 🌙',
      body: (v) =>
          'Your streak can still be saved! Log any meal or water before midnight.',
    ),
    _Template(
      id: 'wobble_evening',
      state: UserState.wobbling,
      startHour: 19,
      endHour: 21,
      title: (v) => 'Gentle nudge 💚',
      body: (v) =>
          "Hey ${v['name']}, your ${v['streak']}-day streak is waiting for you.",
    ),

    // At risk
    _Template(
      id: 'atrisk_morning',
      state: UserState.atRisk,
      startHour: 9,
      endHour: 12,
      title: (v) => 'Every bit helps 💧',
      body: (v) =>
          "It's been a few days. Even logging water counts — no pressure.",
    ),
    _Template(
      id: 'atrisk_midday',
      state: UserState.atRisk,
      startHour: 10,
      endHour: 13,
      title: (v) => 'We miss you 🌱',
      body: (v) => 'Open Cal Matters whenever you are ready — no pressure at all.',
    ),

    // Dormant
    _Template(
      id: 'dormant_weekly',
      state: UserState.dormant,
      startHour: 9,
      endHour: 20,
      title: (v) => 'Your progress is waiting 🌿',
      body: (v) =>
          'Your Cal Points, streaks and coins are all still here whenever you return.',
    ),
    _Template(
      id: 'dormant_summary',
      state: UserState.dormant,
      startHour: 9,
      endHour: 20,
      title: (v) => 'Your nutrition insight is ready 📊',
      body: (v) =>
          "See how your week is going — one quick look, whenever it suits you.",
    ),
  ];
}

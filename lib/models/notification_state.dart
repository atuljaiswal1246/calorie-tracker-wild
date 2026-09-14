/// Notification state models (plan §5.1).
///
/// Every user is classified into one of four engagement states; the state
/// drives notification frequency, tone and content.
library;

enum UserState { active, wobbling, atRisk, dormant }

extension UserStateKey on UserState {
  String get key => switch (this) {
        UserState.active => 'active',
        UserState.wobbling => 'wobbling',
        UserState.atRisk => 'at_risk',
        UserState.dormant => 'dormant',
      };

  static UserState fromKey(String? key) => switch (key) {
        'wobbling' => UserState.wobbling,
        'at_risk' => UserState.atRisk,
        'dormant' => UserState.dormant,
        _ => UserState.active,
      };
}

/// Persisted per-user notification bookkeeping.
class NotificationState {
  UserState state;

  DateTime? lastStateChange;
  DateTime? lastNotificationSent;

  /// Consecutive dismissed notifications (ignored without opening).
  int consecutiveDismisses;

  /// While set, non-essential notifications are silenced (fatigue cooldown).
  DateTime? suppressUntil;

  /// Learned modal session hour (0-23) or -1 when unknown.
  int preferredHour;

  /// Recent app-open hours (wall-clock) used to learn [preferredHour].
  List<int> sessionHours;

  /// Last time each template was sent (id → ISO), for 48h duplicate prevention.
  Map<String, String> lastTemplateAt;

  /// Recent send timestamps (ISO), for the daily/weekly caps.
  List<String> sentAt;

  /// Re-engagement template ids already sent while dormant (hard cap of 2).
  List<String> reengagementSent;

  NotificationState({
    this.state = UserState.active,
    this.lastStateChange,
    this.lastNotificationSent,
    this.consecutiveDismisses = 0,
    this.suppressUntil,
    this.preferredHour = -1,
    List<int>? sessionHours,
    Map<String, String>? lastTemplateAt,
    List<String>? sentAt,
    List<String>? reengagementSent,
  })  : sessionHours = sessionHours ?? <int>[],
        lastTemplateAt = lastTemplateAt ?? <String, String>{},
        sentAt = sentAt ?? <String>[],
        reengagementSent = reengagementSent ?? <String>[];

  Map<String, dynamic> toJson() => {
        'state': state.key,
        'lastStateChange': lastStateChange?.toIso8601String(),
        'lastNotificationSent': lastNotificationSent?.toIso8601String(),
        'consecutiveDismisses': consecutiveDismisses,
        'suppressUntil': suppressUntil?.toIso8601String(),
        'preferredHour': preferredHour,
        'sessionHours': sessionHours,
        'lastTemplateAt': lastTemplateAt,
        'sentAt': sentAt,
        'reengagementSent': reengagementSent,
      };

  factory NotificationState.fromJson(Map<String, dynamic> json) =>
      NotificationState(
        state: UserStateKey.fromKey(json['state'] as String?),
        lastStateChange: json['lastStateChange'] == null
            ? null
            : DateTime.tryParse(json['lastStateChange'] as String),
        lastNotificationSent: json['lastNotificationSent'] == null
            ? null
            : DateTime.tryParse(json['lastNotificationSent'] as String),
        consecutiveDismisses:
            (json['consecutiveDismisses'] as num?)?.toInt() ?? 0,
        suppressUntil: json['suppressUntil'] == null
            ? null
            : DateTime.tryParse(json['suppressUntil'] as String),
        preferredHour: (json['preferredHour'] as num?)?.toInt() ?? -1,
        sessionHours: (json['sessionHours'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        lastTemplateAt: (json['lastTemplateAt'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as String)),
        sentAt:
            (json['sentAt'] as List?)?.map((e) => e as String).toList(),
        reengagementSent: (json['reengagementSent'] as List?)
            ?.map((e) => e as String)
            .toList(),
      );
}

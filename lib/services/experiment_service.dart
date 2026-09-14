/// Lightweight A/B variant assignment (plan §9 Phase 4).
///
/// Assigns each user a stable variant per experiment by hashing their uid, so a
/// user always sees the same variant without a backend. Exposure can be logged
/// through [AnalyticsService] to compare later.
library;

import 'storage_service.dart';

class ExperimentService {
  static StorageService? _storage;
  static const String streakDisplay = 'streak_display';
  static const String notifTone = 'notif_tone';

  static void init(StorageService storage) => _storage = storage;

  /// Deterministically pick a variant for [experiment] for the current user.
  static String variant(String experiment, List<String> variants) {
    if (variants.isEmpty) return '';
    final key = '${_storage?.userId ?? 'anon'}:$experiment';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return variants[hash % variants.length];
  }

  /// 'compact' shows "🔥 7"; 'verbose' shows "🔥 7 days".
  static String streakDisplayVariant() =>
      variant(streakDisplay, const ['compact', 'verbose']);

  static bool get verboseStreak => streakDisplayVariant() == 'verbose';

  /// Which notification tone pool to draw from (plan §9 Phase 4 A/B).
  static String notifToneVariant() =>
      variant(notifTone, const ['playful', 'supportive', 'gentle']);
}

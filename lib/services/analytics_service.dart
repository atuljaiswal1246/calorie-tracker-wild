/// Lightweight analytics seam (plan §9 Phase 4).
///
/// Records engagement events to a bounded local ring buffer so the loop can be
/// measured today, and gives a single place to forward events to Firebase
/// Analytics later (add `firebase_analytics` and call it from [log]).
///
/// Local-only on purpose: no new dependency or platform config is required to
/// keep the build green, and no data leaves the device.
library;

import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class AnalyticsService {
  static StorageService? _storage;
  static const int maxEvents = 200;

  static void init(StorageService storage) => _storage = storage;

  /// Record an event. Safe to call before [init] (no-op) and from anywhere.
  static void log(String event, [Map<String, Object?> params = const {}]) {
    final storage = _storage;
    if (storage == null) return;
    final events = storage.analyticsEventsRaw;
    events.add({
      'event': event,
      'params': params,
      'at': DateTime.now().toIso8601String(),
    });
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    // Fire-and-forget: analytics must never block or throw into a UI path.
    storage.saveAnalyticsEvents(events);
    if (kDebugMode) debugPrint('[analytics] $event $params');
  }

  static List<Map<String, dynamic>> recent() =>
      _storage?.analyticsEventsRaw ?? <Map<String, dynamic>>[];

  /// Event name → count, for a quick local dashboard.
  static Map<String, int> counts() {
    final out = <String, int>{};
    for (final e in recent()) {
      final name = e['event'] as String? ?? 'unknown';
      out[name] = (out[name] ?? 0) + 1;
    }
    return out;
  }

  static Future<void> clear() async {
    await _storage?.saveAnalyticsEvents(<Map<String, dynamic>>[]);
  }
}

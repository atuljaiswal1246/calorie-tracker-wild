/// Analytics seam (plan §9 Phase 4).
///
/// Every funnel event is recorded to a bounded local ring buffer (so it can be
/// inspected in debug) AND forwarded to Firebase Analytics, which is what gives
/// real numbers from testers and (later) production users.
///
/// Privacy: this is usage/device data only — no food photos, no health values,
/// no email. Google Analytics for Firebase is declared in the Play Data safety
/// form and in the hosted privacy policy. If collection is ever disabled,
/// nothing else in the app depends on it.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class AnalyticsService {
  static StorageService? _storage;
  static const int maxEvents = 200;

  static void init(StorageService storage) => _storage = storage;

  static DateTime? _sessionStart;

  /// Mark the start of this app session and log `app_open`.
  static void markSessionStart() {
    _sessionStart = DateTime.now();
    log('app_open');
  }

  /// Milliseconds since [markSessionStart] (-1 if not marked).
  static int get sinceStartMs => _sessionStart == null
      ? -1
      : DateTime.now().difference(_sessionStart!).inMilliseconds;

  /// Record an event. Safe to call before [init] (no-op) and from anywhere.
  static void log(String event, [Map<String, Object?> params = const {}]) {
    final storage = _storage;
    if (storage == null) return;

    // Local ring buffer (debug/inspection).
    final events = storage.analyticsEventsRaw;
    events.add({
      'event': event,
      'params': params,
      'at': DateTime.now().toIso8601String(),
    });
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    storage.saveAnalyticsEvents(events);

    _send(event, params);
    if (kDebugMode) debugPrint('[analytics] $event $params');
  }

  /// Fire-and-forget forward to Firebase Analytics. Never throws into a UI path
  /// and no-ops when Firebase isn't available (tests, or before init).
  static void _send(String event, Map<String, Object?> params) {
    if (Firebase.apps.isEmpty) return;
    try {
      FirebaseAnalytics.instance.logEvent(
        name: _cleanName(event),
        parameters: _cleanParams(params),
      );
    } catch (_) {
      // Analytics must never affect the app.
    }
  }

  /// Firebase event names: <=40 chars, letters/digits/underscore, must start
  /// with a letter.
  static String _cleanName(String raw) {
    var s = raw.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (s.isEmpty || !RegExp(r'^[A-Za-z]').hasMatch(s)) s = 'e_$s';
    return s.length <= 40 ? s : s.substring(0, 40);
  }

  /// Parameter values must be String/num; strings are capped at 100 chars.
  static Map<String, Object> _cleanParams(Map<String, Object?> raw) {
    final out = <String, Object>{};
    raw.forEach((k, v) {
      if (v == null) return;
      final key = _cleanName(k);
      if (v is num || v is bool) {
        out[key] = v;
      } else {
        final str = v.toString();
        out[key] = str.length <= 100 ? str : str.substring(0, 100);
      }
    });
    return out;
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

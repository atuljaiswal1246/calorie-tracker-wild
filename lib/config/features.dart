/// Feature flags for temporarily disabled features.
///
/// Flip a flag back to `true` to reconnect a feature. Code for disabled
/// features is kept dormant (never deleted) so re-enabling is one line.
class Features {
  Features._();

  /// In-app Asha AI chat + her hooks (quest, points, shop voices). Parked while
  /// the core food-logging loop is perfected; the weekly summary is unaffected.
  static const bool asha = false;
}

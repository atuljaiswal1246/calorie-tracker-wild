/// Feature flags for temporarily disabled features.
///
/// Flip a flag back to `true` to reconnect a feature. Code for disabled
/// features is kept dormant (never deleted) so re-enabling is one line.
class Features {
  Features._();

  /// In-app Asha AI chat + her hooks (quest, points, shop voices). Parked while
  /// the core food-logging loop is perfected; the weekly summary is unaffected.
  static const bool asha = false;

  /// "Sign in with Apple" (iOS only). PARKED: Xcode refuses to sign it —
  /// "Personal development teams ... do not support the Sign In with Apple
  /// capability" — so it needs the paid Apple Developer Program ($99/yr).
  ///
  /// Everything else is ready. To enable once enrolled:
  ///   1. developer.apple.com: tick Sign in with Apple on the App ID
  ///      com.neharohilla.calorietracker.
  ///   2. ios/Runner/Runner.entitlements already exists; add
  ///      `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to the three
  ///      Runner build configs in project.pbxproj.
  ///   3. Flip this flag to true and rebuild.
  /// Firebase's Apple provider is already enabled; the native flow needs no
  /// Services ID or client secret. Required on the App Store (4.8).
  static const bool appleSignIn = false;
}

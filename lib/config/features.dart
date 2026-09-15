/// Feature flags for temporarily disabled features.
///
/// Flip a flag back to `true` to reconnect a feature. Code for disabled
/// features is kept dormant (never deleted) so re-enabling is one line.
class Features {
  Features._();

  /// In-app Asha AI chat + her hooks (quest, points, shop voices). Parked while
  /// the core food-logging loop is perfected; the weekly summary is unaffected.
  static const bool asha = false;

  /// "Sign in with Apple" button. Design is approved (see
  /// design/mock_signup.html); it is hidden until wired, because Apple needs a
  /// Service ID + client secret configured in the Apple developer account.
  /// Required on the App Store (guideline 4.8) once Google sign-in is offered.
  static const bool appleSignIn = false;
}

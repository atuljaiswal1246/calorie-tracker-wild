import 'package:flutter/material.dart';

/// Shared color & design-token system for Cal Matters.
///
/// Every screen should import this file instead of defining local color
/// constants. Surfaces & text tokens are brightness-aware (light/dark);
/// macro/accent colors stay identical in both modes.
class AppColors {
  AppColors._();

  /// Flipped by main() / Settings. Screens read these at build time.
  static final ValueNotifier<bool> darkNotifier = ValueNotifier(false);

  /// The equipped shop theme ('default' | 'theme_midnight' | 'theme_forest').
  /// Set at startup and when the user equips a theme in the shop.
  static final ValueNotifier<String> themeNotifier = ValueNotifier('default');

  static String get themeId => themeNotifier.value;

  static bool get dark => darkNotifier.value;

  // ── Background & surface ──────────────────────────────────────────────
  static Color get bg => dark ? Color(0xFF0E0F11) : const Color(0xFFFAF9F7);
  static Color get card => dark ? Color(0xFF1B1C1E) : Colors.white;
  static Color get cardAlt =>
      dark ? Color(0xFF26272B) : const Color(0xFFF1F0EC);
  static Color get cardSelected =>
      dark ? Color(0xFF232428) : const Color(0xFFF4F4F1);
  static Color get cardHover =>
      dark ? Color(0xFF2A2B2F) : const Color(0xFFF0F0EC);

  // ── Ink / text ────────────────────────────────────────────────────────
  static Color get ink => dark ? Color(0xFFF2F2F4) : const Color(0xFF1C1C1E);
  static Color get muted =>
      dark ? Color(0xFF9A9AA2) : const Color(0xFF6E6E73);
  static Color get faint =>
      dark ? Color(0xFF6D6D75) : const Color(0xFF8A8A85);

  /// Filled surface for buttons/pills that carry white text. In light mode
  /// it's ink-black; in dark mode a soft gray (pure-white buttons glare).
  static Color get inkButton => switch (themeId) {
        'theme_forest' =>
          dark ? const Color(0xFF255A29) : const Color(0xFF2E7D32),
        'theme_midnight' =>
          dark ? const Color(0xFF3B3470) : const Color(0xFF4B3FBF),
        _ => dark ? const Color(0xFF3A3B40) : const Color(0xFF1C1C1E),
      };

  /// White pill/chip surface (light mode keeps crisp white; dark mode
  /// softens to a muted gray so it doesn't glare).
  static Color get whiteSurface =>
      dark ? const Color(0xFF46474D) : Colors.white;

  /// Chip/soft-blue fill (water buttons etc.); deep blue in dark mode.
  static Color get chipBlue =>
      dark ? const Color(0xFF1E2F4A) : const Color(0xFFEAF3FF);
  static Color get accentSoft => chipBlue;

  // ── Macro colors (same in both themes) ────────────────────────────────
  static const protein = Color(0xFFE53935);
  static const carbs = Color(0xFFFF9500);
  static const fat = Color(0xFF007AFF);
  /// Themed accent — blue by default, green (Forest) or indigo (Midnight).
  static Color get accent => switch (themeId) {
        'theme_forest' => const Color(0xFF2E7D32),
        'theme_midnight' => const Color(0xFF6C5CE7),
        _ => const Color(0xFF007AFF),
      };
  static const water = Color(0xFF007AFF);
  static const fiber = Color(0xFF8D6E63);
  static const sugar = Color(0xFFE91E63);
  static const sodium = Color(0xFF78909C);

  // ── Semantic (surface-adjacent tokens stay loud in dark too) ──────────
  static Color get line => dark ? const Color(0xFF3A3B40) : const Color(0xFFE5E5EA);
  static Color get divider => line;
  static Color get border => line;
  
  static const green = Color(0xFF34C759);
  static const missedRed = Color(0xFFFF3B30);
  static const warningOrange = Color(0xFFFFA726);
  static const accentOrange = Color(0xFFFF9500);
  static const gold = Color(0xFFFFD60A);

  // ── Misc surfaces ─────────────────────────────────────────────────────
  static Color get track =>
      dark ? Color(0xFF2E2F33) : const Color(0xFFECECE7);
  static Color get divider =>
      dark ? Color(0xFF2A2B2F) : const Color(0xFFECECE7);
  static Color get weekRing =>
      dark ? Color(0xFF333438) : const Color(0xFFE3E3DE);
  static Color get chipNeutral =>
      dark ? Color(0xFF26272B) : const Color(0xFFF1F0EC);
  static Color get undoRed =>
      dark ? Color(0xFF33201E) : const Color(0xFFFFF3F0);
  static Color get warningBg =>
      dark ? Color(0xFF33290F) : const Color(0xFFFFF3E0);

  // ── Error state ─────────────────────────────────────────────────────
  static Color get errorBg =>
      dark ? Color(0xFF38201E) : const Color(0xFFFFF0F0);
  static const errorRed = Color(0xFFD32F2F);

  // ── Shadows ───────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  static List<BoxShadow> get cardShadowLight => dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ]
      : [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ];
}

import 'package:flutter/material.dart';

/// Shared color & design-token system for Cal Matters.
///
/// Every screen should import this file instead of defining local color
/// constants. This keeps the palette consistent and makes global tweaks easy.
class AppColors {
  AppColors._();

  // ── Background & surface ──────────────────────────────────────────────
  static const bg = Color(0xFFFAF9F7); // warm-white page background
  static const card = Colors.white; // card / container fill
  static const cardAlt = Color(0xFFF1F0EC); // secondary surface (placeholders, inactive toggles)
  static const cardSelected = Color(0xFFF4F4F1); // selected day background
  static const cardHover = Color(0xFFF0F0EC); // nav item active bg

  // ── Ink / text ────────────────────────────────────────────────────────
  static const ink = Color(0xFF1C1C1E); // primary text
  static const muted = Color(0xFF6E6E73); // secondary text
  static const faint = Color(0xFF8A8A85); // inactive nav / disabled text

  // ── Macro colors ──────────────────────────────────────────────────────
  static const protein = Color(0xFFE53935); // coral / red
  static const carbs = Color(0xFFFF9500); // warm orange
  static const fat = Color(0xFF007AFF); // blue
  static const accent = Color(0xFF007AFF); // alias for fat (used in onboarding)
  static const water = Color(0xFF007AFF); // water progress bar (semantic, same hex as fat)
  static const fiber = Color(0xFF8D6E63); // brown
  static const sugar = Color(0xFFE91E63); // pink
  static const sodium = Color(0xFF78909C); // blue-grey

  // ── Semantic ──────────────────────────────────────────────────────────
  static const green = Color(0xFF34C759); // completed / on-target
  static const missedRed = Color(0xFFFF3B30); // missed / over / delete
  static const warningOrange = Color(0xFFFFA726); // 50–79 % progress
  static const accentOrange = Color(0xFFFF9500); // trial / upgrade CTA
  static const gold = Color(0xFFFFD60A); // achievements

  // ── Misc surfaces ─────────────────────────────────────────────────────
  static const track = Color(0xFFECECE7); // ring / progress-bar background
  static const divider = Color(0xFFECECE7); // divider line
  static const weekRing = Color(0xFFE3E3DE); // week-selector future-day ring
  static const chipBlue = Color(0xFFEAF3FF); // water button bg
  static const accentSoft = chipBlue; // alias for selected picker bg (onboarding)
  static const chipNeutral = Color(0xFFF1F0EC); // custom button bg
  static const undoRed = Color(0xFFFFF3F0); // undo / end-fast bg
  static const warningBg = Color(0xFFFFF3E0); // offline / trial banner bg

  // ── Error state ─────────────────────────────────────────────────────
  static const errorBg = Color(0xFFFFF0F0); // error banner background
  static const errorRed = Color(0xFFD32F2F); // error text / button

  // ── Shadows ───────────────────────────────────────────────────────────
  static const cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const cardShadowLight = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
}

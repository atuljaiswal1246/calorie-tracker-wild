// Design tokens for Cal Matters: type sizes, spacing, radii.
// Colours live in app_colors.dart - nothing colour-related belongs here.
// Values mirror the type / spacing / radii locked in UI_GUIDELINES.md.

/// Type scale. Rule: pick from these seven; do not invent a new size.
class AppType {
  AppType._();

  /// Pills, labels.
  static const double micro = 10;

  /// Captions.
  static const double small = 11.5;

  /// Body (default).
  static const double body = 13;

  /// Body emphasis.
  static const double bodyStrong = 15;

  /// Card titles.
  static const double title = 17;

  /// Screen titles.
  static const double headline = 22;

  /// Big numbers.
  static const double hero = 28;
}

/// Spacing scale. Rule: gaps come from this set.
class AppSpace {
  AppSpace._();

  /// Extra-small gap.
  static const double xs = 4;

  /// Small gap.
  static const double sm = 8;

  /// Medium gap.
  static const double md = 12;

  /// Large gap.
  static const double lg = 16;

  /// Extra-large gap.
  static const double xl = 24;
}

/// Corner radii. Rule: no new radii.
class AppRadius {
  AppRadius._();

  /// Pills / chips.
  static const double pill = 10;

  /// Cards.
  static const double card = 16;

  /// Sheets / major cards.
  static const double sheet = 24;

  /// Pill (stadium).
  static const double full = 999;

  /// Tiny indicators: progress bars, dots.
  static const double bar = 4;
}

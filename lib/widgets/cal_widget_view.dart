import 'package:flutter/material.dart';

import '../services/widget_state.dart';

/// The Cal Matters home-screen widget, drawn in Flutter.
///
/// Rendered off-screen to a PNG by `HomeWidget.renderFlutterWidget` and shown
/// on Android, so it matches the app's design exactly instead of being limited
/// to what RemoteViews can lay out.
///
/// It is built as a *trigger*: the meal is the hero, the streak is the stake,
/// calories are demoted, and there is exactly one action. The states and their
/// windows come from `CalWidgetStates.build`.
///
/// Deliberately avoids Material/Theme so it can render without an app shell.
class CalWidgetView extends StatelessWidget {
  final String hero;
  final String subline;
  final String? pill;
  final int remaining;
  final int streak;
  final bool streakAtRisk;
  final List<WidgetDay> week;
  final String mealLabel;
  final WidgetMood mood;
  final bool learnedTime;

  /// Follows the system theme: the widget sits on the OS home screen, whose
  /// context is the system, not the app's own dark toggle.
  final bool dark;

  final double width;
  final double height;

  const CalWidgetView({
    super.key,
    required this.hero,
    required this.subline,
    required this.pill,
    required this.remaining,
    required this.streak,
    required this.week,
    required this.mealLabel,
    required this.mood,
    this.streakAtRisk = false,
    this.learnedTime = false,
    this.dark = false,
    this.width = 340,
    this.height = 168,
  });

  factory CalWidgetView.fromState(CalWidgetState state,
          {bool dark = false}) =>
      CalWidgetView(
        hero: state.hero,
        subline: state.context,
        pill: state.pill,
        remaining: state.remaining,
        streak: state.streak,
        streakAtRisk: state.streakAtRisk,
        week: state.week,
        mealLabel: state.mealLabel,
        mood: state.mood,
        learnedTime: state.learnedTime,
        dark: dark,
      );

  Color get _card => dark ? const Color(0xFF1B1C1E) : const Color(0xFFFFFFFF);
  Color get _ink => dark ? const Color(0xFFF2F2F4) : const Color(0xFF1C1C1E);
  Color get _muted => dark ? const Color(0xFF9A9AA2) : const Color(0xFF6E6E73);
  Color get _track => dark ? const Color(0xFF2C2D31) : const Color(0xFFEFEFEA);

  static const _green = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red = Color(0xFFFF3B30);

  Color get _accent => switch (mood) {
        WidgetMood.over || WidgetMood.lastCall => _red,
        WidgetMood.done => _green,
        WidgetMood.due => _orange,
        WidgetMood.calm => _ink,
      };

  /// Text on the accent pill — the calm accent is light in dark mode.
  Color get _onAccent {
    final a = _accent;
    final luma = (a.r * 0.299 + a.g * 0.587 + a.b * 0.114);
    return luma > 0.6 ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  }

  Color _dayColor(WidgetDay d) => switch (d) {
        WidgetDay.future => _track,
        WidgetDay.empty => _red.withValues(alpha: 0.35),
        WidgetDay.logged => _orange,
        WidgetDay.onTarget => _green,
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- the trigger + the one action ----
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hero,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 10),
                  if (pill != null)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        pill!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _onAccent,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Nothing to log.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ---- the stake, and what's left (demoted) ----
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (streak > 0) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Flame(
                          color: streakAtRisk ? _red : _orange,
                          size: 15),
                      const SizedBox(width: 3),
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    streakAtRisk ? 'at risk' : 'days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: streakAtRisk ? _red : _muted,
                    ),
                  ),
                ] else
                  Text(
                    'Start your\nstreak',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '$remaining left',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < week.length; i++) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _dayColor(week[i]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (i < week.length - 1) const SizedBox(width: 3),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small flame, drawn rather than a font glyph so it renders anywhere.
class _Flame extends StatelessWidget {
  final Color color;
  final double size;
  const _Flame({required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlamePainter(color)),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final Color color;
  _FlamePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.95, h * 0.35, w * 0.85, h * 0.72, w * 0.5, h)
      ..cubicTo(w * 0.15, h * 0.72, w * 0.05, h * 0.35, w * 0.5, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = color);

    final inner = Path()
      ..moveTo(w * 0.5, h * 0.38)
      ..cubicTo(w * 0.72, h * 0.6, w * 0.68, h * 0.82, w * 0.5, h * 0.94)
      ..cubicTo(w * 0.32, h * 0.82, w * 0.28, h * 0.6, w * 0.5, h * 0.38)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.color != color;
}

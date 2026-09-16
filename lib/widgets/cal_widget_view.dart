import 'package:flutter/material.dart';

import '../services/widget_state.dart';

/// How a single day in the widget's week chain is doing.
enum WidgetDay { future, empty, logged, onTarget }

/// The Cal Matters home-screen widget, drawn in Flutter.
///
/// Rendered off-screen to a PNG by `HomeWidget.renderFlutterWidget` and shown
/// on Android, so the widget matches the app's design exactly instead of being
/// limited to what RemoteViews can lay out.
///
/// The look is data-driven: [CalWidgetView.fromState] takes one of the states
/// built by `CalCalWidgetStates.build` — the mood line, ring colour, streak and
/// button label all come from the user's own data and the time of day.
///
/// Deliberately avoids Material/Theme so it can render without an app shell.
class CalWidgetView extends StatelessWidget {
  /// The mood line: "Today · 12-day streak", "You usually log lunch around
  /// 1:30pm", "Dinner is the last call", "Logged — day's on track".
  final String line;

  /// Secondary line: "1,086 of 2,081 kcal" or "12-day streak · 640 left".
  final String caption;

  final int remaining;
  final int consumed;
  final int goal;
  final List<WidgetDay> week;
  final String mealLabel;
  final WidgetMood mood;

  /// Follows the system theme: the widget sits on the OS home screen, whose
  /// context is the system, not the app's own dark toggle.
  final bool dark;

  final double width;
  final double height;

  const CalWidgetView({
    super.key,
    required this.line,
    required this.caption,
    required this.remaining,
    required this.consumed,
    required this.goal,
    required this.week,
    required this.mealLabel,
    required this.mood,
    this.dark = false,
    this.width = 340,
    this.height = 168,
  });

  factory CalWidgetView.fromState(CalWidgetState state, {bool dark = false}) =>
      CalWidgetView(
        line: state.line,
        caption: state.caption,
        remaining: state.remaining,
        consumed: state.consumed,
        goal: state.goal,
        week: state.week,
        mealLabel: state.mealLabel,
        mood: state.mood,
        dark: dark,
      );

  Color get _card => dark ? const Color(0xFF1B1C1E) : const Color(0xFFFFFFFF);
  Color get _ink => dark ? const Color(0xFFF2F2F4) : const Color(0xFF1C1C1E);
  Color get _muted => dark ? const Color(0xFF9A9AA2) : const Color(0xFF6E6E73);
  Color get _track => dark ? const Color(0xFF2C2D31) : const Color(0xFFEFEFEA);
  Color get _pillInk => dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  static const _green = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red = Color(0xFFFF3B30);

  /// The mood owns the colour — this is what changes through the day.
  Color get _moodColor => switch (mood) {
        WidgetMood.over => _red,
        WidgetMood.done => _green,
        WidgetMood.due => _orange,
        WidgetMood.lastCall => _red,
        WidgetMood.calm => _ink,
      };

  Color _dayColor(WidgetDay d) => switch (d) {
        WidgetDay.future => _track,
        WidgetDay.empty => _red.withValues(alpha: 0.35),
        WidgetDay.logged => _orange,
        WidgetDay.onTarget => _green,
      };

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(26),
        ),
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _Ring(
                  progress: progress,
                  color: _moodColor,
                  track: _track,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$remaining',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'left',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Two lines only, whatever the state — no extra badges.
                  SizedBox(
                    height: 34,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _moodColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < week.length; i++) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _dayColor(week[i]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        if (i < week.length - 1) SizedBox(width: 4),
                      ],
                    ],
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _moodColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+ Log $mealLabel',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: mood == WidgetMood.calm ? _pillInk : _pillInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  _Ring({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(centre, radius, trackPaint);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -1.5708,
        6.28318 * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track;
}

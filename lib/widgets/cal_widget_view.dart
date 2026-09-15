import 'package:flutter/material.dart';

/// How a single day in the widget's week chain is doing.
enum WidgetDay { future, empty, logged, onTarget }

/// The Cal Matters home-screen widget, drawn in Flutter.
///
/// It is rendered off-screen to a PNG by `HomeWidget.renderFlutterWidget` and
/// shown on Android, which keeps the widget identical to the app's design
/// (rings, chain, type) instead of being limited to RemoteViews.
///
/// Deliberately avoids Material/Theme so it can render without an app shell.
class CalWidgetView extends StatelessWidget {
  final int remaining;
  final int consumed;
  final int goal;
  final List<WidgetDay> week;
  final String mealLabel;

  const CalWidgetView({
    super.key,
    required this.remaining,
    required this.consumed,
    required this.goal,
    required this.week,
    required this.mealLabel,
    this.width = 340,
    this.height = 168,
  });

  final double width;
  final double height;

  static const _card = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF6E6E73);
  static const _track = Color(0xFFEFEFEA);
  static const _green = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red = Color(0xFFFF3B30);

  Color _dayColor(WidgetDay d) => switch (d) {
        WidgetDay.future => _track,
        WidgetDay.empty => _red.withValues(alpha: 0.30),
        WidgetDay.logged => _orange,
        WidgetDay.onTarget => _green,
      };

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final over = remaining <= 0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _Ring(
                  progress: progress,
                  color: over ? _red : _ink,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$remaining',
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const Text(
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$consumed of $goal kcal',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 8),
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
                        if (i < week.length - 1) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+ Log $mealLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _card,
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
  _Ring({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _trackColor;
    canvas.drawCircle(centre, radius, track);

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

  static const _trackColor = Color(0xFFEFEFEA);

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress || old.color != color;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// The ring widget: calories taken, drawn as the app's own ring.
///
/// Job: status at a glance. It carries no meal prompt and no logging action —
/// those belong to the trigger widget. Colour carries the state:
/// black while on track, amber past halfway, green on target, red over.
///
/// Deliberately avoids Material/Theme so it can render without an app shell.
class CalRingWidgetView extends StatelessWidget {
  final int consumed;
  final int goal;
  final int remaining;
  final bool dark;
  final double width;
  final double height;

  const CalRingWidgetView({
    super.key,
    required this.consumed,
    required this.goal,
    required this.remaining,
    this.dark = false,
    this.width = 340,
    this.height = 168,
  });

  bool get over => remaining <= 0;
  double get progress => goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

  Color get _card => dark ? const Color(0xFF1B1C1E) : const Color(0xFFFFFFFF);
  Color get _ink => dark ? const Color(0xFFF2F2F4) : const Color(0xFF1C1C1E);
  Color get _muted => dark ? const Color(0xFF9A9AA2) : const Color(0xFF6E6E73);
  Color get _track => dark ? const Color(0xFF2C2D31) : const Color(0xFFEFEFEA);

  static const _green = Color(0xFF34C759);
  static const _orange = Color(0xFFFF9500);
  static const _red = Color(0xFFFF3B30);

  /// The ring's colour is the whole point of this widget.
  Color get _ringColor {
    if (over) return _red;
    if (progress == 0) return _track;
    if (progress >= 0.8) return _green;
    if (progress >= 0.5) return _orange;
    return _ink;
  }

  @override
  Widget build(BuildContext context) {
    final compact = width < 250;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.all(14),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ring(size: 104, numberSize: 26),
                  const SizedBox(height: 6),
                  Text(
                    '$remaining left',
                    style: TextStyle(
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  _ring(size: 132, numberSize: 34),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$remaining',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        Text(
                          over ? 'kcal over' : 'kcal left',
                          style: TextStyle(fontSize: AppType.small, color: _muted),
                        ),
                        const SizedBox(height: 8),
                        // Two rows rather than four: the key is a legend, not
                        // a list, and four rows overflowed the card.
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            _key(_ink, 'on track'),
                            _key(_orange, 'halfway'),
                            _key(_green, 'on target'),
                            _key(_red, 'over'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _key(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
          children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: AppType.micro, color: _muted)),
      ]);

  Widget _ring({required double size, required double numberSize}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: over ? 1.0 : progress,
            color: _ringColor,
            track: _track,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$consumed',
                      style: TextStyle(
                        fontSize: numberSize,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                Text(
                  'of $goal',
                  style: TextStyle(fontSize: AppType.micro, color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.10;
    final centre = (Offset.zero & size).center;
    final radius = (size.shortestSide - stroke) / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track;
}

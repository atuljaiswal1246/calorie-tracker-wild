import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

class DailyGoalRing extends StatelessWidget {
  final int completed;
  final int total;
  final double size;
  final VoidCallback? onTap;

  const DailyGoalRing({
    super.key,
    required this.completed,
    required this.total,
    this.size = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final isComplete = completed >= total && total > 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress,
                isComplete: isComplete,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isComplete)
                  const Icon(
                    Icons.check,
                    color: Color(0xFF58CC02),
                    size: 28,
                  )
                else
                  Text(
                    '$completed/$total',
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                if (!isComplete)
                  Text(
                    'DAILY GOAL',
                    style: TextStyle(
                      fontSize: size * 0.09,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isComplete;

  _RingPainter({
    required this.progress,
    required this.isComplete,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = isComplete ? const Color(0xFF58CC02) : const Color(0xFFFFC800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      final startAngle = -math.pi / 2; // Start at top
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isComplete != isComplete;
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PathConnectorPainter extends CustomPainter {
  final bool isCompleted;
  final bool isNextCompleted;

  PathConnectorPainter({
    required this.isCompleted,
    this.isNextCompleted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw dashed/dotted line
    if (isCompleted) {
      paint.color = const Color(0xFF58CC02); // Duolingo green
    } else {
      paint.color = AppColors.divider.withValues(alpha: 0.4);
    }

    final path = Path();
    final startY = 0.0;
    final endY = size.height;
    final midX = size.width / 2;
    final bow = size.width * 0.16;

    // Smooth curved path like Duolingo's winding track (gentle cubic bow).
    path.moveTo(midX, startY);
    path.cubicTo(midX - bow, startY, midX - bow, endY, midX, endY);

    if (isCompleted) {
      canvas.drawPath(path, paint);
    } else {
      // Draw dashed line for incomplete
      _drawDashedPath(canvas, path, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashWidth = 8.0;
    final dashSpace = 6.0;
    final metrics = path.computeMetrics();
    
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(PathConnectorPainter oldDelegate) {
    return oldDelegate.isCompleted != isCompleted;
  }
}

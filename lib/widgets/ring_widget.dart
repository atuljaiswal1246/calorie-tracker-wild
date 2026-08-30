import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular progress ring with a child widget in the center.
class RingWidget extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget child;

  const RingWidget({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    required this.strokeWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.rotate(
            angle: -3.14159 / 2,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.track,
              color: color,
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

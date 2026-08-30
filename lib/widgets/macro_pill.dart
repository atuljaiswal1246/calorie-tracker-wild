import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small pill showing an icon + value (e.g. "32g" protein).
class MacroPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final double iconSize;
  final double fontSize;

  const MacroPill({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.iconSize = 10,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

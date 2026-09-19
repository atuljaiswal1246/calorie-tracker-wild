import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'ring_widget.dart';

/// Small macro card (protein / carbs / fat / fiber / sugar / sodium).
class MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  final IconData icon;
  final String unit;
  final VoidCallback? onTap;

  MacroCard({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    required this.icon,
    this.unit = 'g',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: '$label: ${value.toStringAsFixed(0)} of ${target.toStringAsFixed(0)}$unit',
        button: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value.toStringAsFixed(0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(width: 2),
                  Text(
                    '/${target.toStringAsFixed(0)}$unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppType.micro,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              RingWidget(
                progress: progress,
                color: color,
                size: 52,
                strokeWidth: 5,
                child: Icon(icon, color: color, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

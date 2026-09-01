import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ring_widget.dart';

/// Big calories card with a large progress ring.
class CaloriesCard extends StatelessWidget {
  final int logged;
  final int goal;
  final VoidCallback? onTap;

  CaloriesCard({
    super.key,
    required this.logged,
    required this.goal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (logged / goal).clamp(0.0, 1.0);
    final over = logged > goal;

    Color accentColor;
    if (over) {
      accentColor = AppColors.missedRed;
    } else if (progress >= 0.8) {
      accentColor = AppColors.green;
    } else if (progress >= 0.5) {
      accentColor = AppColors.warningOrange;
    } else {
      accentColor = AppColors.ink;
    }

    return Semantics(
      label: '$logged of $goal calories',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$logged',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: -1.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '/$goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      over ? 'Calories over target' : 'Calories eaten',
                      style: TextStyle(
                        fontSize: 13,
                        color: over ? AppColors.missedRed : AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              RingWidget(
                progress: progress,
                color: accentColor,
                size: 104,
                strokeWidth: 11,
                child: Icon(
                  over ? Icons.warning_rounded : Icons.local_fire_department,
                  color: accentColor,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

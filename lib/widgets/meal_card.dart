import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/food_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'macro_pill.dart';
import 'thumbnail_widget.dart';

/// A card representing a single food entry (thumbnail + name + calories + macro pills).
class MealCard extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  MealCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.items.isEmpty
        ? 'Meal'
        : entry.items.first.name +
            (entry.items.length > 1 ? ' +${entry.items.length - 1}' : '');

    final hasProtein = entry.totalProtein > 0;
    final hasCarbs = entry.totalCarbs > 0;
    final hasFat = entry.totalFat > 0;

    return Semantics(
      label: '$name, ${entry.totalCalories.toStringAsFixed(0)} calories',
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              ThumbnailWidget(imagePath: entry.imagePath),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.bodyStrong,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    // Wrap, not Row: a long calorie count plus three macro
                    // pills overflowed the card by a few pixels on narrow
                    // phones (the pills now drop to a second line instead).
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Symbols.local_fire_department_rounded,
                                size: 15, color: AppColors.accentOrange),
                            SizedBox(width: 3),
                            Text(
                              '${entry.totalCalories}',
                              style: TextStyle(
                                fontSize: AppType.bodyStrong,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasProtein)
                          MacroPill(
                            icon: Icons.egg_alt,
                            color: AppColors.protein,
                            text: '${entry.totalProtein.toStringAsFixed(0)}g',
                          ),
                        if (hasCarbs)
                          MacroPill(
                            icon: Icons.grain,
                            color: AppColors.carbs,
                            text: '${entry.totalCarbs.toStringAsFixed(0)}g',
                          ),
                        if (hasFat)
                          MacroPill(
                            icon: Icons.water_drop,
                            color: AppColors.fat,
                            text: '${entry.totalFat.toStringAsFixed(0)}g',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 3),
              Text(
                _formatTime(entry.dateTime),
                style: TextStyle(
                  fontSize: AppType.small,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $period';
  }
}

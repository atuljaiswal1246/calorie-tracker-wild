import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'empty_illustration.dart';

/// Empty state shown when no meals have been logged.
class EmptyCard extends StatelessWidget {
  final VoidCallback? onScanTap;

  EmptyCard({super.key, this.onScanTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const EmptyIllustration(
            asset: 'assets/illustrations/empty_meals.jpg',
            size: 108,
          ),
          SizedBox(height: 14),
          Text(
            'No meals logged yet',
            style: TextStyle(
              fontSize: AppType.bodyStrong,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Scan your first meal to get started',
            style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
          ),
          if (onScanTap != null) ...[
            SizedBox(height: 16),
            Semantics(
              label: 'Scan a meal',
              button: true,
              child: InkWell(
                onTap: onScanTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.inkButton,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Scan a meal',
                        style: TextStyle(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

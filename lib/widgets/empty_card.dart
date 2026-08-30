import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Empty state shown when no meals have been logged.
class EmptyCard extends StatelessWidget {
  final VoidCallback? onScanTap;

  const EmptyCard({super.key, this.onScanTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 10),
          const Text(
            'No meals logged yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan your first meal to get started',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (onScanTap != null) ...[
            const SizedBox(height: 16),
            Semantics(
              label: 'Scan a meal',
              button: true,
              child: InkWell(
                onTap: onScanTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Scan a meal',
                        style: TextStyle(
                          fontSize: 13,
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

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pagination dots (used below the macro page view).
class PaginationDots extends StatelessWidget {
  final int count;
  final int current;

  const PaginationDots({
    super.key,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == current ? AppColors.ink : AppColors.weekRing,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

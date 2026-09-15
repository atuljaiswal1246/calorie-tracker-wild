import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows an asset image if it exists; otherwise a labeled placeholder naming
/// the expected file, so missing art is obvious and easy to drop in later.
///
/// When you supply a real image, add its path to `pubspec.yaml` assets — this
/// widget will pick it up automatically with no code change.
class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final String label;

  const AppImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
    this.label = 'image',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          path,
          fit: fit,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final name = path.split('/').last;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 18, color: AppColors.faint),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.1,
                color: AppColors.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows a food-entry thumbnail or a placeholder emoji.
class ThumbnailWidget extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final double borderRadius;

  const ThumbnailWidget({
    super.key,
    required this.imagePath,
    this.width = 84,
    this.height = 84,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: hasImage
            ? Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.cardAlt,
      child: const Center(
        child: Text('🍛', style: TextStyle(fontSize: 30)),
      ),
    );
  }
}

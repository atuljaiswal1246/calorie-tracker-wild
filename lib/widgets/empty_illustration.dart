import 'package:flutter/material.dart';

/// A flat illustration tile for empty states.
///
/// The artwork carries its own warm cream background (the app's illustration
/// family), so it is presented as a rounded tile rather than a cut-out.
class EmptyIllustration extends StatelessWidget {
  final String asset;
  final double size;

  const EmptyIllustration({
    super.key,
    required this.asset,
    this.size = 104,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

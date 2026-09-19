import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
export '../../widgets/animated_stats.dart';

/// Small "DEMO" pill shown on every try-before-you-buy screen.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.carbs.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'DEMO',
        style: TextStyle(
          fontSize: AppType.micro,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.carbs,
        ),
      ),
    );
  }
}

class DemoHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const DemoHeader({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 18, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const DemoBadge(),
      ],
    );
  }
}

/// Bottom call-to-action used across the demo screens.
class DemoCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DemoCta({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.inkButton,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: AppType.bodyStrong,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white app-style card.
class DemoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const DemoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: child,
    );
  }
}

/// One labelled macro progress row.
class MacroBar extends StatelessWidget {
  final String label;
  final String value;
  final double pct;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(label,
                style: TextStyle(fontSize: AppType.small, color: AppColors.muted)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct.clamp(0, 1)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.16),
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppType.body,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular progress ring that sweeps from 0 to [pct], with [child] inside.
class RingStat extends StatelessWidget {
  final double pct;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;

  const RingStat({
    super.key,
    required this.pct,
    required this.color,
    this.size = 120,
    this.stroke = 10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pct.clamp(0, 1)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}


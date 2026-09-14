import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A full-screen celebration for big reward moments (level-up, streak
/// milestone). Tap anywhere or wait ~2.4s to dismiss.
///
/// Motion honours the OS reduce-motion setting: when disabled, the card still
/// appears but without the confetti/scale animation.
class CelebrationOverlay extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const CelebrationOverlay({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  /// Push the celebration as a transparent full-screen route.
  static void show(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) =>
            CelebrationOverlay(emoji: emoji, title: title, subtitle: subtitle),
        transitionsBuilder: (context, animation, __, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child;
          }
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismiss;
  late final List<_Confetti> _confetti;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _confetti = List.generate(
      18,
      (_) => _Confetti(
        dx: rng.nextDouble() * 2 - 1,
        dy: rng.nextDouble(),
        size: 14 + rng.nextDouble() * 16,
        emoji: const ['🎉', '✨', '🔥', '🌟', '💚'][rng.nextInt(5)],
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _dismiss = Timer(const Duration(milliseconds: 2400), _close);
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!reduce) ..._confetti.map((c) => _confettiWidget(c)),
            _card(reduce),
          ],
        ),
      ),
    );
  }

  Widget _confettiWidget(_Confetti c) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(c.dx * 160 * t, -220 + c.dy * 460 * t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Text(c.emoji, style: TextStyle(fontSize: c.size)),
          ),
        );
      },
    );
  }

  Widget _card(bool reduce) {
    final content = Semantics(
      liveRegion: true,
      label: '${widget.title}. ${widget.subtitle}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 34),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );

    if (reduce) return content;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ),
      child: content,
    );
  }
}

class _Confetti {
  final double dx;
  final double dy;
  final double size;
  final String emoji;

  _Confetti({
    required this.dx,
    required this.dy,
    required this.size,
    required this.emoji,
  });
}

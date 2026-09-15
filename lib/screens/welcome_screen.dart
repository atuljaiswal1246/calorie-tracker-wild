import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// First screen — a single, clean hero (no carousel, no mascot).
///
/// Brand · one promise · one food visual · an expectation line · one CTA.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _iv(double a, double b) =>
      ((_c.value - a) / (b - a)).clamp(0.0, 1.0);

  void _start() {
    HapticFeedback.mediumImpact();
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? true;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brand(),
                const SizedBox(height: 22),
                _hero(reduce),
                const SizedBox(height: 26),
                _fade(0.25, 0.55,
                    Text(
                      'Know your calories\nfrom a single photo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 30,
                        height: 1.14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    )),
                const SizedBox(height: 12),
                _fade(0.35, 0.65,
                    Text(
                      '6 quick questions · ~60 seconds → your personal plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    )),
                const SizedBox(height: 28),
                _fade(0.45, 0.75, _springButton()),
                const SizedBox(height: 14),
                _fade(0.55, 0.85, _signIn()),
                const SizedBox(height: 18),
                _fade(
                    0.6,
                    0.9,
                    Text(
                      'AI-powered · your photos aren’t stored   ·   Terms · Privacy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.faint),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fade(double a, double b, Widget child) => Opacity(
        opacity: _iv(a, b),
        child: Transform.translate(
          offset: Offset(0, (1 - _iv(a, b)) * 10),
          child: child,
        ),
      );

  Widget _brand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/icons/app_icon.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.eco_rounded, size: 26, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'Cal Matters',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  // One real food visual. (A photo can replace the emoji later; the frame,
  // chip and one-shot scan stay the same.)
  Widget _hero(bool reduce) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF3E7D3),
                      Color(0xFFE4D2B4),
                    ],
                  ),
                ),
                child: Center(
                  child: Text('🍛', style: TextStyle(fontSize: 104)),
                ),
              ),
              // One-shot scan sweep on first view.
              if (!reduce)
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = ((_c.value - 0.10) / 0.45).clamp(0.0, 1.0);
                    if (t <= 0 || t >= 1) return const SizedBox.shrink();
                    return Positioned(
                      top: 20 + t * 220,
                      left: 14,
                      right: 14,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // Result chip — hints the product.
              Positioned(
                left: 14,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Palak Paneer',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(width: 8),
                      Text('420 kcal · 18g protein',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _springButton() {
    return _SpringButton(label: 'Get started', onTap: _start);
  }

  Widget _signIn() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Already have an account? ',
              style: TextStyle(color: AppColors.muted)),
          GestureDetector(
            onTap: widget.onSignIn,
            child: Text(
              'Sign in',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpringButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SpringButton({required this.label, required this.onTap});

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.inkButton,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

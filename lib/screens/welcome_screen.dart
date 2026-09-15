import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/pagination_dots.dart';

/// First screen — a feature carousel (scan · macros · workouts · water) with
/// the brand and one CTA below it. Fits a single viewport, no scrolling.
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
    duration: const Duration(milliseconds: 900),
  )..forward();

  final PageController _pages = PageController();
  Timer? _auto;
  int _slide = 0;

  static const _slides = [
    (asset: 'assets/onboarding/feature_scan.jpg', caption: 'Scan any food'),
    (asset: 'assets/onboarding/feature_macros.jpg', caption: 'Energy & macros'),
    (
      asset: 'assets/onboarding/feature_exercise.jpg',
      caption: 'Track your workouts'
    ),
    (asset: 'assets/onboarding/feature_water.jpg', caption: 'Stay hydrated'),
  ];

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.animateToPage(
        (_slide + 1) % _slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    _c.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _c,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _carousel()),
                const SizedBox(height: 10),
                PaginationDots(count: _slides.length, current: _slide),
                const SizedBox(height: 12),
                _brand(),
                const SizedBox(height: 16),
                _benefits(),
                const SizedBox(height: 18),
                _SpringButton(
                    label: 'Get started', onTap: _start, arrow: true),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Already have an account? ',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                      GestureDetector(
                        onTap: widget.onSignIn,
                        child: Text('Sign in',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carousel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _slide = i),
            itemBuilder: (_, i) => Image.asset(
              _slides[i].asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF3E7D3), Color(0xFFE4D2B4)],
                  ),
                ),
              ),
            ),
          ),
          // Bottom scrim so the headline sits legibly on any image
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.66),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Per-slide caption
          Positioned(
            left: 16,
            top: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(_slide),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _slides[_slide].caption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          // Headline — bottom of the image
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Text(
              'Track your calories,\nlive a healthier you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                height: 1.13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.eco_rounded, size: 30, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Cal Matters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Track  ·  Eat  ·  Feel Better',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _benefits() {
    final items = [
      (Icons.restaurant, AppColors.green, 'Log meals\neasily'),
      (Icons.bar_chart_rounded, AppColors.carbs, 'Calories\n& macros'),
      (Icons.track_changes_rounded, const Color(0xFF8B5CF6), 'Stay on\nyour goals'),
      (Icons.favorite_rounded, const Color(0xFFFF4D6D), 'Healthy\nhabits'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: it.$2.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(it.$1, size: 20, color: it.$2),
                ),
                const SizedBox(height: 6),
                Text(it.$3,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpringButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool arrow;
  const _SpringButton(
      {required this.label, required this.onTap, this.arrow = false});

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
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.inkButton,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              if (widget.arrow) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

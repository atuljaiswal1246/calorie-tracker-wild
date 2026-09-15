import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/pagination_dots.dart';
import 'demo/demo_exercise_screen.dart';
import 'demo/demo_scan_screen.dart';
import 'demo/demo_search_screen.dart';
import 'demo/demo_water_screen.dart';

/// First screen — a framed feature carousel where each slide is one unit:
/// the image, its title inside at the bottom, and a demo icon that opens a
/// real try-before-you-buy demo of that feature. Fits one viewport, no scroll.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const WelcomeScreen({
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
    (
      asset: 'assets/onboarding/food_scan.jpg',
      title: 'Scan any food.\nKnow your calories.',
      demoLabel: 'Try the food scanner',
      icon: Icons.qr_code_scanner_rounded,
      color: AppColors.green,
    ),
    (
      asset: 'assets/onboarding/food_palak_paneer.jpg',
      title: 'See your energy\nand macros clearly.',
      demoLabel: 'Try food search',
      icon: Icons.donut_large_rounded,
      color: AppColors.carbs,
    ),
    (
      asset: 'assets/onboarding/feature_exercise.jpg',
      title: 'Log your workouts.\nStay consistent.',
      demoLabel: 'Try activity tracking',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF8B5CF6),
    ),
    (
      asset: 'assets/onboarding/feature_water.jpg',
      title: 'Stay hydrated.\nFeel your best.',
      demoLabel: 'Try the water tracker',
      icon: Icons.water_drop_rounded,
      color: AppColors.water,
    ),
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

  void _openDemo(int i) {
    HapticFeedback.selectionClick();
    _auto?.cancel();
    final page = switch (i) {
      0 => DemoScanScreen(onGetStarted: widget.onGetStarted),
      1 => DemoSearchScreen(onGetStarted: widget.onGetStarted),
      2 => DemoExerciseScreen(onGetStarted: widget.onGetStarted),
      _ => DemoWaterScreen(onGetStarted: widget.onGetStarted),
    };
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) {
      if (mounted) {
        _auto = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted || !_pages.hasClients) return;
          _pages.animateToPage(
            (_slide + 1) % _slides.length,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = MediaQuery.of(context).size.height * 0.5;
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
                _brand(),
                const SizedBox(height: 14),
                // Framed carousel — capped at 50% of the screen.
                SizedBox(height: imageHeight, child: _framedCarousel()),
                const SizedBox(height: 12),
                PaginationDots(count: _slides.length, current: _slide),
                Expanded(
                  child: Column(
                    children: [
                      const Spacer(),
                      // Demo launcher — below the image, using the space
                      _TryButton(
                        label: _slides[_slide].demoLabel,
                        icon: _slides[_slide].icon,
                        color: _slides[_slide].color,
                        onTap: () => _openDemo(_slide),
                      ),
                      const Spacer(),
                      _SpringButton(
                          label: 'Get started', onTap: _start, arrow: true),
                      const SizedBox(height: 14),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _framedCarousel() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.divider, width: 1.5),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
            // Bottom scrim so the title and demo icon sit legibly
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
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Title inside the image, at the bottom
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  _slides[_slide].title,
                  key: ValueKey(_slide),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
}

/// The demo launcher shown below the image — a clear secondary button.
class _TryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          boxShadow: AppColors.cardShadowLight,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            Icon(Icons.play_circle_fill_rounded, size: 24, color: color),
          ],
        ),
      ),
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

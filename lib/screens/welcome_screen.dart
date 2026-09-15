import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// First screen — polished hero: brand + tagline, a real food photo with a
/// nutrition overlay, a benefit row, and one CTA. (Designed to match the
/// approved mockup.)
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

  @override
  void dispose() {
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
        child: Stack(
          children: [
            _cornerShapes(),
            FadeTransition(
              opacity: _c,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _brand(),
                    const SizedBox(height: 18),
                    _hero(),
                    const SizedBox(height: 26),
                    Text(
                      'Track your calories,\nlive a healthier you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Log your meals, see your nutrition, and reach your goals — one bite at a time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _benefits(),
                    const SizedBox(height: 26),
                    _SpringButton(
                        label: 'Get started', onTap: _start, arrow: true),
                    const SizedBox(height: 14),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Already have an account? ',
                              style: TextStyle(color: AppColors.muted)),
                          GestureDetector(
                            onTap: widget.onSignIn,
                            child: Text('Sign in',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI-powered  ·  Your data stays private  ·  Terms  ·  Privacy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerShapes() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -60,
            bottom: -70,
            child: _blob(200, const Color(0xFFF6E9CC)),
          ),
          Positioned(
            right: -50,
            bottom: -90,
            child: _blob(220, const Color(0xFFF0E1BF)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

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

  Widget _hero() {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.02,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/onboarding/hero_bowl.jpg',
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
              // Nutrition overlay card
              Positioned(top: 14, right: 14, child: _nutritionCard()),
              // Handwritten accent
              Positioned(
                right: 18,
                bottom: 22,
                child: Transform.rotate(
                  angle: -0.06,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good food.',
                          style: TextStyle(
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.55),
                          )),
                      Text('Real progress.',
                          style: TextStyle(
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.55),
                          )),
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

  Widget _nutritionCard() {
    return Container(
      width: 172,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: 0.62,
                    strokeWidth: 5,
                    backgroundColor: AppColors.green.withValues(alpha: 0.18),
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('420',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    Text('kcal',
                        style: TextStyle(
                            fontSize: 9, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _macroDot(AppColors.green, 'Protein', '18g'),
                const SizedBox(height: 6),
                _macroDot(AppColors.carbs, 'Carbs', '52g'),
                const SizedBox(height: 6),
                _macroDot(const Color(0xFF8B5CF6), 'Fats', '14g'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroDot(Color c, String k, String v) {
    return Row(
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(k, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        const Spacer(),
        Text(v,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      ],
    );
  }

  Widget _benefits() {
    final items = [
      (Icons.restaurant, AppColors.green, 'Log meals\neasily'),
      (Icons.bar_chart_rounded, AppColors.carbs, 'Track\ncalories & macros'),
      (Icons.track_changes_rounded, const Color(0xFF8B5CF6), 'Stay on\nyour goals'),
      (Icons.favorite_rounded, const Color(0xFFFF4D6D), 'Build\nhealthier habits'),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: it.$2.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(it.$1, size: 22, color: it.$2),
                ),
                const SizedBox(height: 8),
                Text(it.$3,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
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

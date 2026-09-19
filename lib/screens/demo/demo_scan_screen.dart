import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'demo_common.dart';

/// Try-before-you-buy demo: a simulated food scanner. It plays a camera +
/// scan animation and then reveals a sample dish with its calorie and macro
/// values. Purely illustrative — no camera, no account, no cost.
class DemoScanScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const DemoScanScreen({super.key, required this.onGetStarted});

  @override
  State<DemoScanScreen> createState() => _DemoScanScreenState();
}

enum _Phase { scanning, analyzing, done }

class _ScanDish {
  final String name;
  final String hindi;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;

  const _ScanDish(this.name, this.hindi, this.kcal, this.protein, this.carbs,
      this.fat);
}

class _DemoScanScreenState extends State<DemoScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  static const _dishes = [
    _ScanDish('Paneer Butter Masala', 'पनीर बटर मसाला', 320, 12, 14, 22),
    _ScanDish('Palak Paneer', 'पालक पनीर', 265, 14, 9, 19),
    _ScanDish('Masala Dosa', 'मसाला डोसा', 387, 8, 58, 13),
    _ScanDish('Chole Bhature', 'छोले भटूरे', 650, 15, 78, 30),
    _ScanDish('Dal Makhani', 'दाल मखनी', 380, 13, 32, 22),
  ];

  int _index = 0;
  _Phase _phase = _Phase.scanning;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _line.dispose();
    super.dispose();
  }

  void _run() {
    setState(() => _phase = _Phase.scanning);
    _line.repeat(reverse: true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.analyzing);
      _line.stop();
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() => _phase = _Phase.done);
      });
    });
  }

  void _scanAgain() {
    setState(() => _index = (_index + 1) % _dishes.length);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final dish = _dishes[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Stand-in for the camera preview — a real photo of a dish.
          Positioned.fill(
            child: Image.asset(
              'assets/onboarding/food_palak_paneer.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF17181C),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          // Viewfinder + scan beam (only while scanning)
          if (_phase == _Phase.scanning)
            Positioned.fill(child: _viewfinder()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 20, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      const DemoBadge(),
                    ],
                  ),
                ),
                const Spacer(),
                if (_phase != _Phase.done) _status(dish),
                if (_phase == _Phase.done)
                  _ResultCard(
                    dish: dish,
                    onScanAgain: _scanAgain,
                    onGetStarted: widget.onGetStarted,
                  )
                else
                  const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(_ScanDish dish) {
    final scanning = _phase == _Phase.scanning;
    return Column(
      children: [
        if (!scanning)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.carbs,
            ),
          ),
        if (!scanning) const SizedBox(height: 14),
        Text(
          scanning ? 'Point at your plate' : 'Analysing "${dish.name}"…',
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppType.bodyStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          scanning ? 'Hold steady — detecting your food' : 'Matching Indian foods',
          style: const TextStyle(color: Colors.white70, fontSize: AppType.body),
        ),
        const SizedBox(height: 34),
      ],
    );
  }

  Widget _viewfinder() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 230,
          height: 230,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sheet),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5),
                ),
              ),
              AnimatedBuilder(
                animation: _line,
                builder: (_, __) => Align(
                  alignment: Alignment(0, -1 + 2 * _line.value),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.carbs,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.carbs.withValues(alpha: 0.8),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _ScanDish dish;
  final VoidCallback onScanAgain;
  final VoidCallback onGetStarted;

  const _ResultCard({
    required this.dish,
    required this.onScanAgain,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(dish.hindi,
                              style: TextStyle(
                                  fontSize: AppType.body, color: AppColors.muted)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.sm, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Demo result',
                                style: TextStyle(
                                    fontSize: AppType.micro,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onScanAgain,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.chipNeutral,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.refresh_rounded,
                        size: 19, color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RingStat(
                  pct: (dish.kcal / 600).clamp(0, 1),
                  color: AppColors.green,
                  size: 92,
                  stroke: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountUp(
                        value: dish.kcal,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
                      ),
                      Text('kcal',
                          style: TextStyle(
                              fontSize: AppType.micro, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      MacroBar(
                          label: 'Protein',
                          value: '${dish.protein.toStringAsFixed(0)}g',
                          pct: dish.protein / 40,
                          color: AppColors.green),
                      MacroBar(
                          label: 'Carbs',
                          value: '${dish.carbs.toStringAsFixed(0)}g',
                          pct: dish.carbs / 80,
                          color: AppColors.carbs),
                      MacroBar(
                          label: 'Fats',
                          value: '${dish.fat.toStringAsFixed(0)}g',
                          pct: dish.fat / 40,
                          color: const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DemoCta(label: 'Get started to log this', onTap: onGetStarted),
          ],
        ),
      ),
    );
  }
}

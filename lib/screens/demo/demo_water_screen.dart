import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'demo_common.dart';

/// Try-before-you-buy demo: tap droplets and watch the glass fill in real time.
class DemoWaterScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const DemoWaterScreen({super.key, required this.onGetStarted});

  @override
  State<DemoWaterScreen> createState() => _DemoWaterScreenState();
}

class _DemoWaterScreenState extends State<DemoWaterScreen> {
  static const int _goal = 8;
  int _glasses = 3;

  double get _pct => _glasses / _goal;

  void _tap(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      // Tapping a filled glass empties back to it; tapping an empty fills to it.
      _glasses = i + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _glasses >= _goal;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: DemoHeader(
                title: 'Water tracker',
                onBack: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tap a droplet — your glass fills instantly.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The glass
                  _Glass(fill: _pct, done: done),
                  const SizedBox(height: 18),
                  CountUp(
                    key: ValueKey(_glasses),
                    value: (_glasses * 250),
                    suffix: ' ml',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 2),
                  Text('$_glasses of $_goal glasses · goal 2,000 ml',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  const SizedBox(height: 18),
                  // Droplet row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        for (var i = 0; i < _goal; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 34,
                                decoration: BoxDecoration(
                                  color: i < _glasses
                                      ? AppColors.water
                                      : AppColors.water
                                          .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Icon(
                                  Icons.water_drop_rounded,
                                  size: 16,
                                  color: i < _glasses
                                      ? Colors.white
                                      : AppColors.water,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: done ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: AppSpace.sm),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.green),
                          const SizedBox(width: 6),
                          Text('Goal reached — nicely done!',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DemoCta(label: 'Get started', onTap: widget.onGetStarted),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final double fill;
  final bool done;

  const _Glass({required this.fill, required this.done});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 170,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Glass outline
          Container(
            decoration: BoxDecoration(
              color: AppColors.water.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10), bottom: Radius.circular(26)),
              border: Border.all(
                  color: AppColors.water.withValues(alpha: 0.35), width: 2),
            ),
          ),
          // Water
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8), bottom: Radius.circular(24)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill.clamp(0, 1)),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => FractionallySizedBox(
                  heightFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.water.withValues(alpha: 0.55),
                          AppColors.water,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 54,
            child: Icon(
              done
                  ? Icons.emoji_events_rounded
                  : Icons.local_drink_rounded,
              size: 34,
              color: done
                  ? AppColors.gold
                  : AppColors.water.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'demo_common.dart';

/// Try-before-you-buy demo: a live activity dashboard. Tap "Log a workout"
/// and watch today's numbers climb.
class DemoExerciseScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const DemoExerciseScreen({super.key, required this.onGetStarted});

  @override
  State<DemoExerciseScreen> createState() => _DemoExerciseScreenState();
}

class _DemoExerciseScreenState extends State<DemoExerciseScreen> {
  int _steps = 8420;
  int _kcal = 320;
  int _minutes = 45;
  double get _distance => _steps / 1350;

  static const _week = [4200, 9100, 6300, 8100, 11200, 7600, 8420];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  final List<(String, int, int)> _workouts = [
    ('Morning run', 32, 320),
  ];

  void _logWorkout() {
    HapticFeedback.mediumImpact();
    const options = [
      ('Evening walk', 24, 110),
      ('Cycling', 40, 260),
      ('Yoga', 20, 90),
      ('Strength', 35, 210),
    ];
    final next = options[_workouts.length % options.length];
    setState(() {
      _workouts.insert(0, next);
      _kcal += next.$3;
      _minutes += next.$2;
      _steps += next.$2 * 90;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: DemoHeader(
                title: 'Activity',
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  DemoCard(
                    child: Row(
                      children: [
                        RingStat(
                          pct: _kcal / 600,
                          color: AppColors.carbs,
                          size: 104,
                          stroke: 9,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CountUp(
                                key: ValueKey(_kcal),
                                value: _kcal,
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink),
                              ),
                              Text('kcal',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            children: [
                              _stat(Icons.directions_walk_rounded,
                                  AppColors.green,
                                  'Steps',
                                  _thousands(_steps)),
                              const SizedBox(height: 12),
                              _stat(Icons.timer_outlined, AppColors.water,
                                  'Active', '$_minutes min'),
                              const SizedBox(height: 12),
                              _stat(Icons.route_rounded,
                                  const Color(0xFF8B5CF6),
                                  'Distance',
                                  '${_distance.toStringAsFixed(1)} km'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DemoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This week',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < _week.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _Bar(
                                    value: i == 6 ? _steps : _week[i],
                                    max: 12000,
                                    label: _days[i],
                                    highlight: i == 6,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Logged workouts',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 8),
                  for (final w in _workouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DemoCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.carbs.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.fitness_center_rounded,
                                  size: 17, color: AppColors.carbs),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(w.$1,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink)),
                            ),
                            Text('${w.$2} min · ${w.$3} kcal',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _logWorkout,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.chipNeutral,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 20, color: AppColors.ink),
                          const SizedBox(width: 6),
                          Text('Log a demo workout',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
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

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _stat(IconData icon, Color color, String label, String value) {    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final int max;
  final String label;
  final bool highlight;

  const _Bar({
    required this.value,
    required this.max,
    required this.label,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / max).clamp(0.06, 1)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                heightFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    color: highlight
                        ? AppColors.carbs
                        : AppColors.carbs.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                color: highlight ? AppColors.ink : AppColors.muted)),
      ],
    );
  }
}

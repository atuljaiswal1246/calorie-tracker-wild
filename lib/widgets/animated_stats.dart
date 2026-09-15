import 'package:flutter/material.dart';

/// Number that animates from 0 to [value].
class CountUp extends StatelessWidget {
  final int value;
  final String suffix;
  final TextStyle style;
  final Duration duration;

  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}$suffix', style: style),
    );
  }
}

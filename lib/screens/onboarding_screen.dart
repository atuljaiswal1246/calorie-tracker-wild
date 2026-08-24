import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  /// Start directly at the pricing step (returning user who hasn't paid).
  final bool startAtPricing;

  const OnboardingScreen({
    super.key,
    required this.storage,
    required this.auth,
    required this.onComplete,
    required this.onBack,
    this.startAtPricing = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // 0-7 are questions; 8 = "building your plan"; 9 = plan summary;
  // 10 = pricing.
  static const _totalSteps = 8;
  static const _buildingStep = 8;
  static const _planStep = 9;
  static const _pricingStep = 10;

  // Step 0: goal
  String? _goal;
  static const _goals = [
    _Option(icon: Icons.arrow_downward, label: 'Lose weight', value: 'lose'),
    _Option(icon: Icons.balance, label: 'Maintain weight', value: 'maintain'),
    _Option(
        icon: Icons.arrow_upward,
        label: 'Gain weight / Build muscle',
        value: 'gain'),
    _Option(icon: Icons.explore_outlined, label: 'Just exploring', value: 'exploring'),
  ];

  // Step 1: sex
  String? _sex;
  static const _sexes = [
    _Option(icon: Icons.male, label: 'Male', value: 'male'),
    _Option(icon: Icons.female, label: 'Female', value: 'female'),
    _Option(icon: Icons.emoji_people, label: 'Others', value: 'others'),
    _Option(icon: Icons.help_outline, label: 'Rather not say', value: 'unspecified'),
  ];

  // Steps 2-5: age, height, weight, target weight (slider values)
  int _age = 25;
  double _height = 165;
  double _weight = 70;
  double _targetWeight = 65;
  bool _noTarget = false;

  // Optional user overrides for the computed targets (null = use computed).
  int? _calorieOverride;
  int? _proteinOverride;
  int? _carbsOverride;
  int? _fatOverride;

  // Step 6: pace (slow / moderate / fast)
  String? _pace;

  // Step 5: workout frequency (workouts per week, matches mainstream apps)
  String? _workoutFreq;
  static const _workoutFreqs = [
    _Option(icon: Icons.looks_one, label: '0–2 times', value: '0to2'),
    _Option(icon: Icons.looks_two, label: '3–5 times', value: '3to5'),
    _Option(icon: Icons.looks_3, label: '6 or more times', value: '6plus'),
  ];

  @override
  void initState() {
    super.initState();
    _goal = _goals.first.value;
    _sex = _sexes.first.value;
    _pace = 'fast'; // fast default
    _workoutFreq = _workoutFreqs.first.value;
    if (widget.startAtPricing) _step = _pricingStep;
  }

  @override
  void dispose() {
    super.dispose();
  }

  double get _progress => (_step + 1) / _totalSteps;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _goal != null;
      case 1:
        return _sex != null;
      case 2:
        return _age >= 10 && _age <= 100;
      case 3:
        return _height >= 50 && _height <= 250;
      case 4:
        return _weight > 0 && _weight <= 300;
      case 5:
        return _workoutFreq != null;
      case 6:
        if (_skipTargetQuestions) return true;
        final v = _targetWeight;
        if (v < 30 || v > 300) return false;
        // Goal-consistency: lose must be below current, gain above current.
        if (_goal == 'lose') return v < _weight;
        if (_goal == 'gain') return v > _weight;
        return true;
      case 7:
        return _pace != null;
      default:
        return false;
    }
  }

  void _next() {
    setState(() {
      _step++;
      // Skip target-weight & pace when there's no target OR the goal
      // doesn't involve weight change (maintain / exploring).
      if (_skipTargetQuestions && _step == 6) _step += 2;
    });
  }

  void _toPlan() {
    setState(() => _step = _planStep);
  }

  Future<void> _goToPricing() async {
    // New users must create an account before paying.
    if (!widget.auth.isSignedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            auth: widget.auth,
            isSignUp: true,
            onAuthenticated: () {
              widget.storage.setUserId(widget.auth.currentUser!.uid);
              Navigator.of(context).pop();
            },
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      );
      if (!mounted) return;
      if (!widget.auth.isSignedIn) return; // user backed out of signup
    }
    if (!mounted) return;
    if (widget.storage.isPaid) {
      _finish();
    } else {
      setState(() => _step = _pricingStep);
    }
  }

  Future<void> _onPaid() async {
    await widget.storage.savePaid(true);
    if (!mounted) return;
    _finish();
  }

  void _back() {
    if (_step == 0) {
      widget.onBack();
      return;
    }
    setState(() {
      _step--;
      // Skip the target-weight step when going back past it.
      if (_skipTargetQuestions && _step == 6) _step--;
    });
  }

  /// True when target-weight & pace questions shouldn't be shown:
  /// no target selected, or the goal doesn't change weight.
  bool get _skipTargetQuestions =>
      _noTarget || _goal == 'maintain' || _goal == 'exploring';

  /// Real-time computed details for a pace, used by the pace screen.
  Map<String, String> _paceDetail(String pace) {
    final p = _buildProfile().copyWith(pace: pace);
    final weeks = p.weeksToGoal;
    final time = _formatWeeks(weeks);
    final weekly = p.weeklyChangeKg.abs().toStringAsFixed(1);
    return {
      'time': time,
      'kcal': '${p.calorieGoal}',
      'weekly': weekly,
      'totalKg': (_weight - _targetWeight).abs().toStringAsFixed(0),
    };
  }

  String _formatWeeks(int? weeks) {
    if (weeks == null || weeks <= 0) return 'a while';
    // Calendar months: ~30.5 days/month (matches mainstream apps exactly:
    // 100wk -> 23mo, 50wk -> 11mo, 20wk -> 5mo, 10wk -> 2mo, 12wk -> 3mo).
    final months = (weeks * 7 / 30.5).round();
    if (months >= 1) return '$months month${months == 1 ? '' : 's'}';
    return '$weeks week${weeks == 1 ? '' : 's'}';
  }

  double? _targetWeightValue() {
    if (_noTarget) return null;
    return _targetWeight;
  }

  Future<void> _finish() async {
    final profile = _buildProfile();
    await widget.storage.saveProfile(profile);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _buildingStep) {
      return _BuildingPlanScreen(onDone: _toPlan);
    }
    if (_step == _planStep) {
      return _PlanSummaryScreen(
        profile: _buildProfile(),
        onGetStarted: _goToPricing,
        onBack: () => setState(() => _step = _totalSteps - 1),
        onEditAge: () async {
          final v = await _showNumberEdit(
            context,
            title: 'Enter your age',
            initialValue: _age.toDouble(),
            min: 10,
            max: 100,
            suffix: 'years',
            allowDecimal: false,
          );
          if (v != null) setState(() => _age = v.round());
        },
        onEditHeight: () async {
          final cm = await _showFeetInchesEdit(
            context,
            heightCm: _height,
          );
          if (cm != null) setState(() => _height = cm);
        },
        onEditWeight: () async {
          final v = await _showNumberEdit(
            context,
            title: 'Enter your weight',
            initialValue: _weight,
            min: 30,
            max: 300,
            suffix: 'kg',
          );
          if (v != null) setState(() => _weight = v);
        },
        onEditTarget: () async {
          final v = await _showNumberEdit(
            context,
            title: 'Enter your target weight',
            initialValue: _targetWeight,
            min: 30,
            max: 300,
            suffix: 'kg',
          );
          if (v != null) setState(() => _targetWeight = v);
        },
        onEditCalories: () async {
          final base = _calorieOverride ??
              _buildProfile().calorieGoal;
          final v = await _showNumberEdit(
            context,
            title: 'Edit daily calories',
            initialValue: base.toDouble(),
            min: 1200,
            max: 5000,
            suffix: 'kcal',
            allowDecimal: false,
          );
          if (v != null) setState(() => _calorieOverride = v.round());
        },
        onEditProtein: () async {
          final base =
              _proteinOverride ?? _buildProfile().proteinGrams;
          final v = await _showNumberEdit(
            context,
            title: 'Edit protein target',
            initialValue: base.toDouble(),
            min: 20,
            max: 400,
            suffix: 'g',
            allowDecimal: false,
          );
          if (v != null) setState(() => _proteinOverride = v.round());
        },
        onEditCarbs: () async {
          final base =
              _carbsOverride ?? _buildProfile().carbsGrams;
          final v = await _showNumberEdit(
            context,
            title: 'Edit carbs target',
            initialValue: base.toDouble(),
            min: 20,
            max: 600,
            suffix: 'g',
            allowDecimal: false,
          );
          if (v != null) setState(() => _carbsOverride = v.round());
        },
        onEditFat: () async {
          final base =
              _fatOverride ?? _buildProfile().fatGrams;
          final v = await _showNumberEdit(
            context,
            title: 'Edit fat target',
            initialValue: base.toDouble(),
            min: 10,
            max: 300,
            suffix: 'g',
            allowDecimal: false,
          );
          if (v != null) setState(() => _fatOverride = v.round());
        },
      );
    }
    if (_step == _pricingStep) {
      return _PricingScreen(
        onPaid: _onPaid,
        onBack: _back,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grey section: top bar + heading + fixed slots
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: const Color(0xFFF7F7F7),
                    child: _TopBar(
                      progress: _progress,
                      stepNumber: _step + 1,
                      onBack: _back,
                    ),
                  ),
                  // Heading block — FIXED height slot so the middle never moves,
                  // whether the heading is 1 line or 2 lines.
                  SizedBox(
                    height: 96,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _buildHeading(),
                      ),
                    ),
                  ),
                  // MIDDLE component — centered in this slot; scrolls if it gets tall
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 8),
                                child: _buildStep(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Warning slot — reserved (min height), warning appears here
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _buildWarning() != null ? 1 : 0,
                          child: _buildWarning() == null
                              ? const SizedBox.shrink()
                              : _WarningBox(message: _buildWarning()!),
                        ),
                      ),
                    ),
                  ),
                  // Footer option slot — reserved (min height), card appears here
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _buildStepFooter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // White section: continue button, extends to the very bottom
          _BottomBar(
            canContinue: _canContinue,
            onContinue: _next,
            isLast: false,
          ),
        ],
      ),
    );
  }

  Profile _buildProfile() {
    return Profile(
      name: 'User',
      age: _age,
      sex: _sex ?? 'unspecified',
      weightKg: _weight,
      heightCm: _height,
      activityLevel: 'sedentary',
      workoutFreq: _workoutFreq ?? 'none',
      goal: _goal ?? 'maintain',
      pace: _pace ?? 'recommended',
      targetWeightKg: _targetWeightValue(),
      calorieGoalOverride: _calorieOverride,
      proteinOverride: _proteinOverride,
      carbsOverride: _carbsOverride,
      fatOverride: _fatOverride,
    );
  }

  Widget _buildHeading() {
    switch (_step) {
      case 0:
        return const Text('Choose your goal',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 1:
        return const Text('Choose your sex',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 2:
        return const Text('What\'s your age?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 3:
        return const Text('What\'s your height?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 4:
        return const Text('What\'s your current weight?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 5:
        return const Text('How many times do you\nwork out in a week?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 6:
        return const Text('What\'s your target weight?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 7:
        return const Text('How fast do you\nwant to lose weight?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _OptionStep(
          options: _goals,
          selected: _goal,
          onSelect: (v) => setState(() => _goal = v),
        );
      case 1:
        return _OptionStep(
          options: _sexes,
          selected: _sex,
          onSelect: (v) => setState(() => _sex = v),
        );
      case 2:
        return _AgeStep(
          age: _age,
          onChanged: (v) => setState(() => _age = v),
        );
      case 3:
        return _HeightStep(
          heightCm: _height,
          onChangedCm: (v) => setState(() => _height = v),
        );
      case 4:
        return _WeightStep(
          weightKg: _weight,
          onChangedKg: (v) => setState(() => _weight = v),
        );
      case 5:
        return _OptionStep(
          options: _workoutFreqs,
          selected: _workoutFreq,
          onSelect: (v) => setState(() => _workoutFreq = v),
        );
      case 6:
        return _TargetWeightStep(
          targetWeight: _targetWeight,
          currentWeight: _weight,
          disabled: _noTarget,
          onChanged: (v) => setState(() => _targetWeight = v),
        );
      case 7:
        return _PaceStep(
          selected: _pace,
          onSelect: (v) => setState(() => _pace = v),
          detailFor: _paceDetail,
          isLose: _goal == 'lose',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepFooter() {
    if (_step == 8) {
      return _NoTargetCard(
        noTarget: _noTarget,
        onChanged: (v) {
          setState(() {
            _noTarget = v;
            if (v) _targetWeight = _weight;
          });
        },
      );
    }
    return const SizedBox.shrink();
  }

  String? _buildWarning() {
    if (_step == 8) return _targetWeightWarning();
    return null;
  }

  String? _targetWeightWarning() {
    if (_noTarget) return null;
    final target = _targetWeight;
    final current = _weight;

    if (_goal == 'lose' && target >= current) {
      return 'Your goal is to lose weight, but your target is above your current weight.';
    }
    if (_goal == 'gain' && target <= current) {
      return 'Your goal is to gain weight, but your target is below your current weight.';
    }

    final diff = (target - current).abs();
    final pct = current == 0 ? 0 : diff / current;
    if (pct > 0.25) {
      return 'That\'s quite far from your current weight. Make sure it\'s a healthy goal.';
    }
    return null;
  }
}

class _WarningBox extends StatelessWidget {
  final String message;

  const _WarningBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6C567)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF8A6D1F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B5414), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Option {
  final IconData icon;
  final String label;
  final String value;
  const _Option({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Shows a numeric edit dialog; returns the value or null if cancelled.
Future<double?> _showNumberEdit(
  BuildContext context, {
  required String title,
  required double initialValue,
  required double min,
  required double max,
  String suffix = '',
  bool allowDecimal = true,
}) {
  final controller = TextEditingController(
    text: allowDecimal
        ? initialValue.toString()
        : initialValue.round().toString(),
  );
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => Navigator.pop(
            context, _parseAndClamp(controller.text, min, max, allowDecimal)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.pop(
              context, _parseAndClamp(controller.text, min, max, allowDecimal)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

double? _parseAndClamp(String text, double min, double max, bool decimal) {
  final v = decimal ? double.tryParse(text) : int.tryParse(text)?.toDouble();
  if (v == null) return null;
  return v.clamp(min, max);
}

/// Two-field dialog for height in feet + inches. Returns cm or null.
Future<double?> _showFeetInchesEdit(
  BuildContext context, {
  required double heightCm,
}) {
  final feetController =
      TextEditingController(text: (heightCm / 30.48).floor().toString());
  final inchesController = TextEditingController(
      text: (((heightCm / 2.54) - (heightCm / 30.48).floor() * 12).round())
          .toString());
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Enter your height',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: feetController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                suffixText: 'ft',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: inchesController,
              keyboardType: TextInputType.number,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                suffixText: 'in',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            final feet = int.tryParse(feetController.text);
            final inches = int.tryParse(inchesController.text);
            if (feet == null) {
              Navigator.pop(context);
              return;
            }
            final i = (inches ?? 0).clamp(0, 11);
            Navigator.pop(context, (feet * 30.48 + i * 2.54).round());
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// An editable big value — tap to type a new number; slider syncs back.

// ---------------- Top bar with progress ----------------
class _TopBar extends StatelessWidget {
  final double progress;
  final int stepNumber;
  final VoidCallback onBack;

  const _TopBar({
    required this.progress,
    required this.stepNumber,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 24, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 20,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              foregroundColor: Colors.black54,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.black12,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$stepNumber/$_totalSteps',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  static const _totalSteps = 8;
}

// ---------------- Bottom bar ----------------
class _BottomBar extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onContinue;
  final bool isLast;

  const _BottomBar({
    required this.canContinue,
    required this.onContinue,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 2px boundary divider above the continue button
            Container(height: 2, color: Colors.black12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: canContinue ? onContinue : null,
                  child: Text(
                    isLast ? 'Finish' : 'Continue',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Option selection step ----------------
class _OptionStep extends StatelessWidget {
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _OptionStep({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...options.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectableCard(
                selected: selected == g.value,
                icon: g.icon,
                label: g.label,
                onTap: () => onSelect(g.value),
              ),
            )),
      ],
    );
  }
}

// ---------------- Pace step (informative) ----------------
class _PaceStep extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final Map<String, String> Function(String pace) detailFor;
  final bool isLose;

  const _PaceStep({
    required this.selected,
    required this.onSelect,
    required this.detailFor,
    required this.isLose,
  });

  @override
  Widget build(BuildContext context) {
    final paces = [
      (value: 'fast', name: 'Fast', icon: Icons.bolt),
      (value: 'recommended', name: 'Moderate', icon: Icons.thumb_up),
      (value: 'slow', name: 'Slow', icon: Icons.self_improvement),
    ];

    final current = selected ?? 'fast';
    final currentDetail = detailFor(current);
    final action = isLose ? 'lose' : 'gain';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...paces.map((pace) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaceCard(
                selected: selected == pace.value,
                icon: pace.icon,
                name: pace.name,
                detail: detailFor(pace.value),
                isLose: isLose,
                onTap: () => onSelect(pace.value),
              ),
            )),
        const SizedBox(height: 4),
        // Live summary of what the selected pace means
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(
            'At this pace, you\'ll $action about '
            '${currentDetail['totalKg']} kg in ${currentDetail['time']}, '
            'eating ${currentDetail['kcal']} kcal/day '
            '(~${currentDetail['weekly']} kg ${action == 'lose' ? 'lost' : 'gained'} '
            'per week).',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _PaceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String name;
  final Map<String, String> detail;
  final bool isLose;
  final VoidCallback onTap;

  const _PaceCard({
    required this.selected,
    required this.icon,
    required this.name,
    required this.detail,
    required this.isLose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              child: Icon(icon,
                  color: selected ? AppColors.accent : Colors.black54,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(
                    '${detail['kcal']} kcal/day · ~${detail['weekly']} kg '
                        '${isLose ? 'lost' : 'gained'} per week',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(detail['time'] ?? '',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(width: 8),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon in a round box (like the back button)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              child: Icon(icon,
                  color: selected ? AppColors.accent : Colors.black54,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ---------------- Slider input step ----------------
// ---------------- Age step ----------------
class _AgeStep extends StatelessWidget {
  final int age;
  final ValueChanged<int> onChanged;

  const _AgeStep({
    required this.age,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          child: _PickerWheel(
            label: 'years',
            min: 10,
            max: 100,
            value: age,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}


// ---------------- Time period step (single days wheel) ----------------
// ---------------- Height step (cm OR feet/inches) ----------------
class _HeightStep extends StatefulWidget {
  final double heightCm;
  final ValueChanged<double> onChangedCm;

  const _HeightStep({
    required this.heightCm,
    required this.onChangedCm,
  });

  @override
  State<_HeightStep> createState() => _HeightStepState();
}

class _HeightStepState extends State<_HeightStep> {
  bool _useFeet = true; // ft/in first, as most users think in ft/in

  int get _feet => (widget.heightCm / 30.48).floor();
  int get _inches => ((widget.heightCm / 2.54) - _feet * 12).round();

  void _fromFeetInches(int feet, int inches) {
    widget.onChangedCm((feet * 30.48 + inches * 2.54).roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Unit toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UnitButton(
                label: 'ft/in',
                active: _useFeet,
                onTap: () => setState(() => _useFeet = true),
              ),
              _UnitButton(
                label: 'cm',
                active: !_useFeet,
                onTap: () => setState(() => _useFeet = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (_useFeet)
          Row(
            children: [
              Expanded(
                child: _PickerWheel(
                  label: 'feet',
                  min: 3,
                  max: 8,
                  value: _feet,
                  onChanged: (v) => _fromFeetInches(v, _inches),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _PickerWheel(
                  label: 'inches',
                  min: 0,
                  max: 11,
                  value: _inches,
                  onChanged: (v) => _fromFeetInches(_feet, v),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              SizedBox(
                height: 200,
                child: _PickerWheel(
                  label: 'cm',
                  min: 100,
                  max: 250,
                  value: widget.heightCm.round(),
                  onChanged: (v) => widget.onChangedCm(v.toDouble()),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UnitButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// A polished iOS-style picker wheel with a selection highlight bar
// and auto-centering on the current value.
class _PickerWheel extends StatefulWidget {
  final String label;
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;

  const _PickerWheel({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_PickerWheel> createState() => _PickerWheelState();
}

class _PickerWheelState extends State<_PickerWheel> {
  static const _itemExtent = 44.0;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
        initialItem: widget.value - widget.min);
  }

  @override
  void didUpdateWidget(_PickerWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_controller.hasClients) {
      _controller = FixedExtentScrollController(
          initialItem: widget.value - widget.min);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.max - widget.min + 1;
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            children: [
              // Selection highlight bar (the "slot" the value sits in)
              Positioned(
                left: 10,
                right: 10,
                top: (170 - _itemExtent) / 2,
                height: _itemExtent,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) =>
                    widget.onChanged(widget.min + i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, i) => Center(
                    child: Text(
                      '${widget.min + i}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: (widget.min + i) == widget.value
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: (widget.min + i) == widget.value
                            ? AppColors.accent
                            : Colors.black26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}

// A labeled picker wheel showing friendly labels (e.g. "1 month", "6 months").

// ---------------- Weight step (kg or lbs) ----------------
class _WeightStep extends StatefulWidget {
  final double weightKg;
  final ValueChanged<double> onChangedKg;

  const _WeightStep({
    required this.weightKg,
    required this.onChangedKg,
  });

  @override
  State<_WeightStep> createState() => _WeightStepState();
}

class _WeightStepState extends State<_WeightStep> {
  bool _useLbs = false;

  double get _lbs => widget.weightKg * 2.20462;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UnitButton(
                label: 'kg',
                active: !_useLbs,
                onTap: () => setState(() => _useLbs = false),
              ),
              _UnitButton(
                label: 'lbs',
                active: _useLbs,
                onTap: () => setState(() => _useLbs = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 200,
          child: _useLbs
              ? _PickerWheel(
                  label: 'lbs',
                  min: 66,
                  max: 660,
                  value: _lbs.round(),
                  onChanged: (v) => widget.onChangedKg(v / 2.20462),
                )
              : _PickerWheel(
                  label: 'kg',
                  min: 30,
                  max: 300,
                  value: widget.weightKg.round(),
                  onChanged: (v) => widget.onChangedKg(v.toDouble()),
                ),
        ),
      ],
    );
  }
}

// ---------------- Target weight step ----------------
class _TargetWeightStep extends StatefulWidget {
  final double targetWeight;
  final double currentWeight;
  final bool disabled;
  final ValueChanged<double> onChanged;

  const _TargetWeightStep({
    required this.targetWeight,
    required this.currentWeight,
    required this.disabled,
    required this.onChanged,
  });

  @override
  State<_TargetWeightStep> createState() => _TargetWeightStepState();
}

class _TargetWeightStepState extends State<_TargetWeightStep> {
  bool _useLbs = false;

  double get _lbs => widget.targetWeight * 2.20462;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UnitButton(
                label: 'kg',
                active: !_useLbs,
                onTap: () => setState(() => _useLbs = false),
              ),
              _UnitButton(
                label: 'lbs',
                active: _useLbs,
                onTap: () => setState(() => _useLbs = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 200,
          child: widget.disabled
              ? const SizedBox.shrink()
              : _useLbs
                  ? _PickerWheel(
                      label: 'lbs',
                      min: 66,
                      max: 660,
                      value: _lbs.round(),
                      onChanged: (v) => widget.onChanged(v / 2.20462),
                    )
                  : _PickerWheel(
                      label: 'kg',
                      min: 30,
                      max: 300,
                      value: widget.targetWeight.round(),
                      onChanged: (v) => widget.onChanged(v.toDouble()),
                    ),
        ),
      ],
    );
  }
}

class _NoTargetCard extends StatelessWidget {
  final bool noTarget;
  final ValueChanged<bool> onChanged;

  const _NoTargetCard({
    required this.noTarget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!noTarget),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: noTarget ? AppColors.accent : Colors.black12,
            width: noTarget ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: noTarget
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              child: Icon(Icons.remove_circle_outline,
                  color: noTarget ? AppColors.accent : Colors.black54,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'I don\'t have a target, just tracking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ),
            ),
            if (noTarget)
              const Icon(Icons.check_circle,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}


// ---------------- Building your plan screen ----------------
class _BuildingPlanScreen extends StatefulWidget {
  final VoidCallback onDone;

  const _BuildingPlanScreen({required this.onDone});

  @override
  State<_BuildingPlanScreen> createState() => _BuildingPlanScreenState();
}

class _BuildingPlanScreenState extends State<_BuildingPlanScreen> {
  final _items = [
    'Finalized your goal',
    'Set your calorie target',
    'Planned your macros',
    'Estimated your timeline',
  ];
  int _visible = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  void _startSequence() async {
    for (var i = 0; i < _items.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _visible = i + 1);
    }
    if (!mounted) return;
    setState(() => _finished = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _finished ? 'Your goal is ready!' : 'Setting your goal...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              ...List.generate(_items.length, (i) {
                final show = i < _visible;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: show ? 1 : 0,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.only(
                        bottom: show ? 16 : 0, top: show ? 16 : 0),
                    child: Row(
                      children: [
                        Icon(
                          show
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: show ? Colors.green.shade600 : Colors.black26,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _items[i],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: show ? Colors.black : Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Plan summary screen ----------------
// ---------------- Plan summary screen ----------------
class _PlanSummaryScreen extends StatefulWidget {
  final Profile profile;
  final VoidCallback onGetStarted;
  final VoidCallback onBack;
  final Future<void> Function() onEditAge;
  final Future<void> Function() onEditHeight;
  final Future<void> Function() onEditWeight;
  final Future<void> Function() onEditTarget;
  final Future<void> Function() onEditCalories;
  final Future<void> Function() onEditProtein;
  final Future<void> Function() onEditCarbs;
  final Future<void> Function() onEditFat;

  const _PlanSummaryScreen({
    required this.profile,
    required this.onGetStarted,
    required this.onBack,
    required this.onEditAge,
    required this.onEditHeight,
    required this.onEditWeight,
    required this.onEditTarget,
    required this.onEditCalories,
    required this.onEditProtein,
    required this.onEditCarbs,
    required this.onEditFat,
  });

  @override
  State<_PlanSummaryScreen> createState() => _PlanSummaryScreenState();
}

class _PlanSummaryScreenState extends State<_PlanSummaryScreen> {
  String _goalLabel() {
    switch (widget.profile.goal) {
      case 'lose':
        return 'Lose weight';
      case 'gain':
        return 'Gain weight / Build muscle';
      case 'exploring':
        return 'Just exploring';
      default:
        return 'Maintain weight';
    }
  }

  int? get _weeks => widget.profile.weeksToGoal;

  String _headline() {
    final p = widget.profile;
    final target = p.targetWeightKg;
    final weeks = _weeks;
    if (p.goal == 'lose' && target != null && weeks != null) {
      final kg = (p.weightKg - target).abs().toStringAsFixed(0);
      return 'Goal: Lose $kg kg in the next $weeks weeks';
    }
    if (p.goal == 'gain' && target != null && weeks != null) {
      final kg = (target - p.weightKg).abs().toStringAsFixed(0);
      return 'Goal: Gain $kg kg in the next $weeks weeks';
    }
    if (p.goal == 'maintain' || p.goal == 'exploring') {
      return 'Goal: Stay on track\nwith your weight';
    }
    return 'Goal: Set and start tracking';
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main heading
                    Text(
                      _headline(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 20),

                    // Representational weight progress graph (or maintain card)
                    if (profile.targetWeightKg == null) ...[
                      _MaintainCard(profile: profile),
                    ] else ...[
                      _WeightGraph(profile: profile),
                    ],
                    const SizedBox(height: 24),

                    // Daily recommendation
                    const Text('Your daily recommendation',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 10),
                    _CalorieCard(
                      profile: profile,
                      onEdit: widget.onEditCalories,
                    ),
                    const SizedBox(height: 20),

                    // Macros
                    const Text('Your daily macros',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroChip(
                              label: 'Protein',
                              grams: profile.proteinGrams,
                              color: const Color(0xFFE53935),
                              onEdit: widget.onEditProtein),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MacroChip(
                              label: 'Carbs',
                              grams: profile.carbsGrams,
                              color: const Color(0xFF43A047),
                              onEdit: widget.onEditCarbs),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MacroChip(
                              label: 'Fat',
                              grams: profile.fatGrams,
                              color: const Color(0xFFFB8C00),
                              onEdit: widget.onEditFat),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // What you selected (editable)
                    const Text('Your details',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.monitor_weight,
                      label: 'Current weight',
                      value: '${profile.weightKg.round()} kg',
                      onEdit: widget.onEditWeight,
                    ),
                    _DetailRow(
                      icon: Icons.height,
                      label: 'Height',
                      value: _heightLabel(profile.heightCm),
                      onEdit: widget.onEditHeight,
                    ),
                    _DetailRow(
                      icon: Icons.cake,
                      label: 'Age',
                      value: '${profile.age} years',
                      onEdit: widget.onEditAge,
                    ),
                    _DetailRow(
                      icon: Icons.flag,
                      label: 'Target weight',
                      value: profile.targetWeightKg == null
                          ? 'No target'
                          : '${profile.targetWeightKg!.round()} kg',
                      onEdit: profile.targetWeightKg == null
                          ? null
                          : widget.onEditTarget,
                    ),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Goal',
                      value: _goalLabel(),
                      onEdit: null,
                    ),
                    const SizedBox(height: 24),

                    // How to reach your goal
                    const Text('How to reach your goal',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 10),
                    const _HowCard(
                      icon: Icons.restaurant,
                      title: 'Track your calories',
                      subtitle: 'Log your meals with a photo every day.',
                    ),
                    const _HowCard(
                      icon: Icons.donut_large,
                      title: 'Hit your daily macros',
                      subtitle: 'Balance protein, carbs and fat.',
                    ),
                    const _HowCard(
                      icon: Icons.monitor_weight_outlined,
                      title: 'Track your weight',
                      subtitle: 'Weigh in weekly to stay on course.',
                    ),
                    const SizedBox(height: 24),

                    // Why Cal Matters
                    const Text('Why Cal Matters',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 10),
                    const _HowCard(
                      icon: Icons.auto_awesome,
                      title: 'Made for you',
                      subtitle:
                          'A plan built around your body, goal and workouts.',
                    ),
                    const _HowCard(
                      icon: Icons.trending_up,
                      title: 'Simple & honest',
                      subtitle:
                          'Realistic targets and clear progress — no shortcuts.',
                    ),
                    const SizedBox(height: 24),

                    // AI disclosure
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              size: 22, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cal Matters uses AI to analyze your food photos '
                              'and estimate calories and macros. Estimates may '
                              'vary — always listen to your body.',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Get started button -> pricing
            ColoredBox(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: widget.onGetStarted,
                      child: const Text(
                        "Let's get started",
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heightLabel(double cm) {
    final feet = (cm / 30.48).floor();
    final inches = ((cm / 2.54) - feet * 12).round();
    return "$feet' $inches\"";
  }
}

// ---------------- Maintain card (for users with no target) ----------------
class _MaintainCard extends StatelessWidget {
  final Profile profile;

  const _MaintainCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.balance, size: 28, color: Colors.black),
          const SizedBox(height: 10),
          const Text('Keep your weight steady',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'No target — we\'ll help you stay at your current weight '
            'by matching your daily intake to what your body uses.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ---------------- Representational weight graph ----------------
class _WeightGraph extends StatelessWidget {
  final Profile profile;

  const _WeightGraph({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weeks = profile.weeksToGoal ?? 10;
    final start = profile.weightKg;
    final end = profile.targetWeightKg ?? start;
    final isLoss = end < start;

    // Representative points: week 0 = start, week N = end.
    final weeksToShow = weeks.clamp(1, 12);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${start.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text('→ ${end.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          // Simple representative line
          SizedBox(
            height: 80,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, 80),
                  painter: _WeightLinePainter(
                    startWeight: start,
                    endWeight: end,
                    weeks: weeksToShow,
                    color: isLoss ? Colors.black : Colors.black,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Week 1',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('Week $weeks',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile.weeklyChangeKg == 0
                  ? 'Maintain your weight'
                  : '${profile.weeklyChangeKg < 0 ? 'Losing' : 'Gaining'} '
                      '~${profile.weeklyChangeKg.abs().toStringAsFixed(1)} kg per week',
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  final double startWeight;
  final double endWeight;
  final int weeks;
  final Color color;

  _WeightLinePainter({
    required this.startWeight,
    required this.endWeight,
    required this.weeks,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw a gentle curve from top (start) to bottom (end).
    final path = Path();
    final startX = size.width * 0.1;
    final endX = size.width * 0.9;
    final topY = size.height * 0.15;
    final bottomY = size.height * 0.85;

    for (var i = 0; i <= weeks; i++) {
      final t = i / weeks;
      final x = startX + (endX - startX) * t;
      // smooth curve: ease the descent
      final eased = t * t * (3 - 2 * t);
      final y = topY + (bottomY - topY) * eased;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Start & end dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(startX, topY), 4, dotPaint);
    canvas.drawCircle(Offset(endX, bottomY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- Calorie card ----------------
class _CalorieCard extends StatelessWidget {
  final Profile profile;
  final Future<void> Function() onEdit;

  const _CalorieCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final goal = profile.calorieGoal;
    // Maintenance = current-weight burn (what a maintain user would get).
    final tdee = (profile.currentBmr * profile.activityMultiplier).floor();
    final adjustment = goal - tdee;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Calories',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      letterSpacing: -0.3)),
              GestureDetector(
                onTap: onEdit,
                child: const Row(
                  children: [
                    Text('Edit',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 16, color: Colors.black38),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$goal',
                  style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -1)),
              const SizedBox(width: 8),
              const Text('kcal / day',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            adjustment == 0
                ? 'Your maintenance calories — eat this to stay on track.'
                : adjustment < 0
                    ? 'That\'s a ${adjustment.abs()} kcal/day deficit from your '
                        'maintenance of $tdee kcal.'
                    : 'That\'s a ${adjustment.abs()} kcal/day surplus over your '
                        'maintenance of $tdee kcal.',
            style: const TextStyle(
                fontSize: 14, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ---------------- Detail row (editable) ----------------
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function()? onEdit;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black54)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: Colors.black38),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- How / Why card ----------------
class _HowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Pricing screen ----------------
class _PricingScreen extends StatefulWidget {
  final VoidCallback onPaid;
  final VoidCallback onBack;

  const _PricingScreen({required this.onPaid, required this.onBack});

  @override
  State<_PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<_PricingScreen> {
  bool _yearly = true; // yearly selected by default
  bool _processing = false;
  bool _approved = false;

  static const _monthlyPrice = 100;
  static const _yearlyPrice = 500;

  int get _savingsPercent {
    final annualIfMonthly = _monthlyPrice * 12;
    return ((annualIfMonthly - _yearlyPrice) / annualIfMonthly * 100).round();
  }

  Future<void> _continue() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _approved = true;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    widget.onPaid();
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) {
      return const _PaymentApprovedScreen();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero image with fading bottom + heading overlay
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // App placeholder (phone mockup)
                          Container(
                            color: const Color(0xFFF7F7F7),
                            child: const Center(
                              child: _PricingHeroMock(),
                            ),
                          ),
                          // Bottom fade so the heading is readable
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 150,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Heading overlaid on the faded area
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding:
                                  EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Text(
                                'Cal Matters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Plan options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Yearly (default selected)
                          _PlanOptionCard(
                            selected: _yearly,
                            badge: '7 days free',
                            left: 'Start for free & save $_savingsPercent%',
                            right: 'Rs $_yearlyPrice/year',
                            sub: 'About Rs $_monthlyPrice/month · Rs $_yearlyPrice billed annually',
                            onTap: () => setState(() => _yearly = true),
                          ),
                          const SizedBox(height: 14),
                          // Monthly
                          _PlanOptionCard(
                            selected: !_yearly,
                            left: 'Monthly',
                            right: 'Rs $_monthlyPrice/month',
                            onTap: () => setState(() => _yearly = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Continue button + fine print
            ColoredBox(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _processing ? null : _continue,
                          child: _processing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.5),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _yearly
                            ? '7 days free, then Rs $_yearlyPrice.00 per year.\n'
                                'Billed annually and renews automatically unless cancelled.'
                            : '7 days free, then Rs $_monthlyPrice.00 per month.\n'
                                'Billed monthly and renews automatically unless cancelled.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                            height: 1.5),
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
}

// ---------------- Pricing hero placeholder (phone mockup) ----------------
class _PricingHeroMock extends StatelessWidget {
  const _PricingHeroMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black12, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Column(
          children: [
            Container(height: 28, color: const Color(0xFFF6F6F6)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's calories",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('1520',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const Text('of 1829 kcal goal',
                        style: TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: 0.83,
                        minHeight: 8,
                        color: Colors.black,
                        backgroundColor: const Color(0xFFEEEEEE),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMacro('Protein', '68g'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _HeroMacro('Carbs', '190g'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _HeroMacro('Fat', '55g'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Log a meal',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
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
}

class _HeroMacro extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMacro(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ---------------- Selectable plan option ----------------
class _PlanOptionCard extends StatelessWidget {
  final bool selected;
  final String? badge;
  final String left;
  final String right;
  final String? sub;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.selected,
    required this.left,
    required this.right,
    required this.onTap,
    this.badge,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null && selected) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(left,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                ),
                const SizedBox(width: 12),
                Text(right,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected ? Colors.black : Colors.black38,
                  size: 22,
                ),
              ],
            ),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- Payment approved (testing phase) ----------------
class _PaymentApprovedScreen extends StatelessWidget {
  const _PaymentApprovedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.check_circle,
                    color: Colors.green, size: 80),
              ),
              const SizedBox(height: 20),
              const Text('Payment approved!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('Welcome to Cal Matters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;
  final Future<void> Function() onEdit;

  const _MacroChip({
    required this.label,
    required this.grams,
    required this.color,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text('$grams g',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 4),
            const Icon(Icons.edit_outlined, size: 14, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}


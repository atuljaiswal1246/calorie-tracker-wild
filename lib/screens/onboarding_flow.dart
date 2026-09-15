import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/funnel.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_stats.dart';
import '../widgets/app_image.dart';
import '../widgets/date_picker_3step.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart' show PricingScreen;

/// The redesigned onboarding journey — six screens, one question each:
///   1 · Goal  2 · You  3 · Height & weight  4 · Activity  5 · Target & pace
///   6 · Plan ready.  Then sign-up → pricing.
///
/// Tap-only; the calorie / macro math lives in [Profile] and is unchanged.
class OnboardingFlow extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final bool startAtPricing;
  final bool startAtSignup;
  final int? startAtStep;

  const OnboardingFlow({
    super.key,
    required this.storage,
    required this.auth,
    required this.onComplete,
    required this.onBack,
    this.startAtPricing = false,
    this.startAtSignup = false,
    this.startAtStep,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _goalStep = 0;
  static const int _youStep = 1;
  static const int _bodyStep = 2;
  static const int _activityStep = 3;
  static const int _targetStep = 4;
  static const int _buildingStep = 5;
  static const int _planStep = 6;
  static const int _signupStep = 7;
  static const int _pricingStep = 8;
  static const int _questionCount = 6;

  int _step = 0;

  // 1 · You
  final _nameController = TextEditingController();
  DateTime? _dob;
  String? _sex;

  // Goal
  String? _goal;

  // Body
  double _height = 165;
  double _weight = 70;

  // Target & pace
  double _targetWeight = 65;
  bool _noTarget = false;
  String? _pace;

  // Activity
  String? _workoutFreq;

  // Optional overrides for the computed targets (null = use computed).
  int? _calorieOverride;
  int? _proteinOverride;
  int? _carbsOverride;
  int? _fatOverride;

  DateTime _stepStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _goal = 'lose';
    _pace = 'recommended';
    _workoutFreq = '3to5';
    if (widget.startAtPricing) {
      _step = _pricingStep;
    } else if (widget.startAtSignup) {
      _restoreFromSavedProfile();
      _step = _signupStep;
    } else if (widget.startAtStep != null && widget.startAtStep! > 0) {
      _restoreFromDraft(widget.storage.onboardingDraft);
      _step = widget.startAtStep!.clamp(0, _planStep);
    }
    _stepStartedAt = DateTime.now();
    Funnel.onboardingStart(_step);
    if (_step == _pricingStep) Funnel.paywallView();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _stepName(int s) => switch (s) {
        0 => 'goal',
        1 => 'name_sex',
        2 => 'body',
        3 => 'workouts',
        4 => 'pace',
        5 => 'building',
        6 => 'plan',
        7 => 'signup',
        8 => 'pricing',
        _ => 'unknown',
      };

  void _logStep(int step) {
    Funnel.stepComplete(step, _stepName(step),
        DateTime.now().difference(_stepStartedAt).inMilliseconds);
    _stepStartedAt = DateTime.now();
  }

  void _restoreFromSavedProfile() {
    final p = widget.storage.profile;
    if (p == null) return;
    _nameController.text = p.name == 'Friend' ? '' : p.name;
    _dob = p.dob != null ? DateTime.tryParse(p.dob!) : null;
    _sex = p.sex == 'unspecified' ? null : p.sex;
    _goal = p.goal;
    _weight = p.weightKg;
    _targetWeight = p.targetWeightKg ?? p.weightKg;
    _noTarget = p.targetWeightKg == null;
    _height = p.heightCm;
    _workoutFreq = p.workoutFreq;
    _pace = p.pace;
  }

  void _restoreFromDraft(Map<String, dynamic>? d) {
    if (d == null) return;
    _nameController.text = (d['name'] as String?) ?? '';
    final dob = d['dob'] as String?;
    _dob = dob != null ? DateTime.tryParse(dob) : null;
    _sex = d['sex'] as String?;
    _goal = (d['goal'] as String?) ?? 'lose';
    _weight = (d['weightKg'] as num?)?.toDouble() ?? 70;
    _targetWeight = (d['targetWeightKg'] as num?)?.toDouble() ?? _weight;
    _noTarget = (d['noTarget'] as bool?) ?? false;
    _height = (d['heightCm'] as num?)?.toDouble() ?? 165;
    _workoutFreq = (d['workoutFreq'] as String?) ?? '3to5';
    _pace = (d['pace'] as String?) ?? 'recommended';
  }

  void _saveDraft() {
    widget.storage.saveOnboardingDraft({
      'step': _step,
      'name': _nameController.text.trim(),
      'dob': _dob == null ? null : _isoDate(_dob!),
      'sex': _sex,
      'goal': _goal,
      'weightKg': _weight,
      'targetWeightKg': _targetWeightValue(),
      'noTarget': _noTarget,
      'heightCm': _height,
      'workoutFreq': _workoutFreq,
      'pace': _pace,
      'calorieOverride': _calorieOverride,
      'proteinOverride': _proteinOverride,
      'carbsOverride': _carbsOverride,
      'fatOverride': _fatOverride,
    });
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool get _skipTargetQuestions =>
      _noTarget || _goal == 'maintain' || _goal == 'exploring';

  double? _targetWeightValue() {
    if (_skipTargetQuestions) return null;
    return _targetWeight;
  }

  double get _progress => (_step + 1) / _questionCount;

  bool get _canContinue {
    switch (_step) {
      case _goalStep:
        return _goal != null;
      case _youStep:
        return _nameController.text.trim().isNotEmpty &&
            _dob != null &&
            _sex != null;
      case _bodyStep:
        return _weight > 0 &&
            _weight <= 300 &&
            _height >= 50 &&
            _height <= 250;
      case _activityStep:
        return _workoutFreq != null;
      case _targetStep:
        if (_skipTargetQuestions) return true;
        final v = _targetWeight;
        if (v < 30 || v > 300) return false;
        if (_goal == 'lose') return v < _weight;
        if (_goal == 'gain') return v > _weight;
        return true;
      default:
        return true;
    }
  }

  Profile _buildProfile() {
    final dobIso = _dob == null ? null : _isoDate(_dob!);
    return Profile(
      name: _nameController.text.trim().isEmpty
          ? 'Friend'
          : _nameController.text.trim(),
      age: dobIso != null && Profile.ageFromDob(dobIso) != null
          ? Profile.ageFromDob(dobIso)!
          : 25,
      sex: _sex ?? 'unspecified',
      dob: dobIso,
      weightKg: _weight,
      heightCm: _height,
      activityLevel: 'sedentary',
      workoutFreq: _workoutFreq ?? '3to5',
      goal: _goal ?? 'maintain',
      pace: _pace ?? 'recommended',
      targetWeightKg: _targetWeightValue(),
      calorieGoalOverride: _calorieOverride,
      proteinOverride: _proteinOverride,
      carbsOverride: _carbsOverride,
      fatOverride: _fatOverride,
    );
  }

  // ── navigation ────────────────────────────────────────────────────────

  void _next() {
    _logStep(_step);
    setState(() {
      if (_step == _activityStep && _skipTargetQuestions) {
        _step = _buildingStep;
      } else {
        _step++;
      }
    });
    _saveDraft();
  }

  void _back() {
    if (_step == _goalStep) {
      widget.onBack();
      return;
    }
    _logStep(_step);
    setState(() {
      if (_step == _buildingStep || _step == _planStep) {
        _step = _skipTargetQuestions ? _activityStep : _targetStep;
      } else {
        _step--;
      }
    });
    _saveDraft();
  }

  void _toPlan() {
    _logStep(_step);
    Funnel.questionsComplete();
    setState(() => _step = _planStep);
    Funnel.planView();
    widget.storage.saveProfile(_buildProfile());
    _saveDraft();
  }

  Future<void> _goToPricing() async {
    if (widget.storage.isPaidOrSandbox(
        authEmail: widget.auth.currentUser?.email)) {
      _finish();
      return;
    }
    _logStep(_step);
    if (widget.auth.isSignedIn) {
      setState(() => _step = _pricingStep);
      Funnel.paywallView();
    } else {
      setState(() => _step = _signupStep);
    }
    _saveDraft();
  }

  Future<void> _onPaid() async {
    Funnel.purchaseComplete();
    await widget.storage.savePaid(true);
    if (!mounted) return;
    _finish();
  }

  Future<void> _finish() async {
    await widget.storage.saveProfile(_buildProfile());
    await widget.storage.clearOnboardingDraft();
    widget.onComplete();
  }

  // ── heights / weights / dob ───────────────────────────────────────────

  static String _formatDob(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _formatWeeks(int? weeks) {
    if (weeks == null || weeks <= 0) return '';
    final months = (weeks * 7 / 30.5).round();
    if (months >= 1) return '$months month${months == 1 ? '' : 's'}';
    return '$weeks week${weeks == 1 ? '' : 's'}';
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker3Step(
      context,
      initial: _dob,
      firstYear: DateTime.now().year - 100,
      lastYear: DateTime.now().year,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickHeight() async {
    final cm = await _showHeightSheet(context, _height);
    if (cm != null) setState(() => _height = cm);
  }

  Future<void> _pickWeight() async {
    final v = await _showWheelSheet(
      context,
      title: 'Current weight',
      min: 30,
      max: 300,
      value: _weight.round(),
      suffix: 'kg',
    );
    if (v != null) setState(() => _weight = v.toDouble());
  }

  Future<void> _pickTargetWeight() async {
    final v = await _showWheelSheet(
      context,
      title: 'Target weight',
      min: 30,
      max: 300,
      value: _targetWeight.round(),
      suffix: 'kg',
    );
    if (v != null) setState(() => _targetWeight = v.toDouble());
  }

  /// Live plan numbers for a given target + pace (drives the projection card
  /// and the pace pills). Uses the LOCKED Profile maths.
  Map<String, String> _planStats(double target, String pace) {
    final p = _buildProfile()
        .copyWith(targetWeightKg: target, pace: pace);
    return {
      'kcal': '${p.calorieGoal}',
      'time': _formatWeeks(p.weeksToGoal),
      'weekly': p.weeklyChangeKg.abs().toStringAsFixed(1),
      'totalKg': (_weight - target).abs().toStringAsFixed(0),
      'floor': p.floorHit ? '1' : '0',
    };
  }

  /// Short goal phrase for the sign-up recap card.
  String _goalShort() {
    final diff = (_weight - _targetWeight).abs().toStringAsFixed(0);
    switch (_goal) {
      case 'gain':
        return 'Gain $diff kg';
      case 'maintain':
        return 'Maintain';
      case 'exploring':
        return 'Exploring';
      default:
        return 'Lose $diff kg';
    }
  }

  String _goalSummary() {
    final diff = (_weight - _targetWeight).abs().toStringAsFixed(0);
    final time = _formatWeeks(_buildProfile().weeksToGoal);
    switch (_goal) {
      case 'gain':
        return 'Gain $diff kg${time.isEmpty ? '' : ' · ~$time'}';
      case 'maintain':
        return 'Maintain weight';
      case 'exploring':
        return 'Just exploring';
      default:
        return 'Lose $diff kg${time.isEmpty ? '' : ' · ~$time'}';
    }
  }

  static String _workoutSummary(String? v) => switch (v) {
        'none' => 'No workout',
        '1to2' => '1–2× / week',
        '0to2' => '0–2× / week',
        '3to5' => '3–5× / week',
        '6plus' => '6+× / week',
        _ => 'Not set',
      };

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_step == _buildingStep) {
      return _BuildingScreen(onDone: _toPlan);
    }
    if (_step == _planStep) {
      return _PlanReadyScreen(
        profile: _buildProfile(),
        name: _nameController.text.trim().isEmpty
            ? 'there'
            : _nameController.text.trim(),
        goalSummary: _goalSummary(),
        workoutSummary: _workoutSummary(_workoutFreq),
        onBack: _back,
        onGetStarted: () {
          if (widget.auth.isSignedIn) {
            _goToPricing();
          } else {
            setState(() => _step = _signupStep);
            _saveDraft();
          }
        },
      );
    }
    if (_step == _signupStep) {
      return AuthScreen(
        auth: widget.auth,
        isSignUp: true,
        recap: PlanRecap(
          kcal: '${_buildProfile().calorieGoal}',
          goal: _goalShort(),
          workouts: _workoutSummary(_workoutFreq).replaceAll(' / week', ''),
        ),
        onAuthenticated: () async {
          final uid = widget.auth.currentUser?.uid;
          if (uid != null) widget.storage.setUserId(uid);
          if (widget.storage.isPaidOrSandbox(
              authEmail: widget.auth.currentUser?.email)) {
            _finish();
            return;
          }
          setState(() => _step = _pricingStep);
          _saveDraft();
        },
        onBack: () => setState(() => _step = _planStep),
      );
    }
    if (_step == _pricingStep) {
      return PricingScreen(
        storage: widget.storage,
        onPaid: _onPaid,
        onBack: () => setState(() => _step = _planStep),
      );
    }
    return _questionScreen();
  }

  Widget _questionScreen() {
    switch (_step) {
      case _goalStep:
        return _StepScaffold(
          progress: _progress,
          stepNumber: _step + 1,
          totalSteps: _questionCount,
          onBack: _back,
          title: 'What\'s your goal?',
          subtitle: 'I\'ll build your plan around this.',
          canContinue: _canContinue,
          onContinue: _next,
          child: _GoalStep(
            selected: _goal,
            onSelect: (v) => setState(() => _goal = v),
          ),
        );
      case _youStep:
        return _StepScaffold(
          progress: _progress,
          stepNumber: _step + 1,
          totalSteps: _questionCount,
          onBack: _back,
          title: 'First things first.',
          subtitle:
              'Help us personalize your experience and get better calorie insights.',
          centerTitle: false,
          showDoodle: true,
          canContinue: _canContinue,
          onContinue: _next,
          child: _YouStep(
            nameController: _nameController,
            dob: _dob,
            sex: _sex,
            onNameChanged: () => setState(() {}),
            onDobTap: _pickDob,
            onSexChanged: (v) => setState(() => _sex = v),
          ),
        );
      case _bodyStep:
        return _StepScaffold(
          progress: _progress,
          stepNumber: _step + 1,
          totalSteps: _questionCount,
          onBack: _back,
          title: 'Your height & weight',
          subtitle: 'Slide or tap — no typing needed.',
          canContinue: _canContinue,
          onContinue: _next,
          child: _BodyStep(
            heightCm: _height,
            weightKg: _weight,
            // Silent updates: the ruler rebuilds its own subtree while
            // dragging, so the whole screen isn't rebuilt per tick.
            onHeightDrag: (v) => _height = v,
            onWeightDrag: (v) => _weight = v,
            onHeightTap: _pickHeight,
            onWeightTap: _pickWeight,
          ),
        );
      case _activityStep:
        return _StepScaffold(
          progress: _progress,
          stepNumber: _step + 1,
          totalSteps: _questionCount,
          onBack: _back,
          title: 'How often do you\nwork out?',
          subtitle: 'This sets how many calories you burn.',
          canContinue: _canContinue,
          onContinue: _next,
          child: _ActivityStep(
            selected: _workoutFreq,
            onSelect: (v) => setState(() => _workoutFreq = v),
          ),
        );
      default:
        return _StepScaffold(
          progress: _progress,
          stepNumber: _step + 1,
          totalSteps: _questionCount,
          onBack: _back,
          title: 'Your target & pace',
          subtitle: 'Slow and steady wins — pick what feels real.',
          canContinue: _canContinue,
          onContinue: _next,
          child: _TargetPaceStep(
            targetWeight: _targetWeight,
            currentWeight: _weight,
            // Silent drag sync (no whole-screen rebuild per tick).
            onTargetDrag: (v) => _targetWeight = v,
            onTargetTap: _pickTargetWeight,
            pace: _pace,
            onPace: (v) => setState(() => _pace = v),
            statsFor: _planStats,
            noTarget: _noTarget,
            onNoTarget: (v) => setState(() {
              _noTarget = v;
              if (v) _targetWeight = _weight;
            }),
            isLose: _goal != 'gain',
          ),
        );
    }
  }
}

// ── shared chrome ─────────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final double progress;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final bool centerTitle;
  final bool showDoodle;
  final Widget child;
  final bool canContinue;
  final VoidCallback onContinue;

  const _StepScaffold({
    required this.progress,
    required this.stepNumber,
    required this.totalSteps,
    required this.onBack,
    required this.title,
    this.subtitle,
    this.centerTitle = true,
    this.showDoodle = false,
    required this.child,
    required this.canContinue,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              progress: progress,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDoodle) const _Doodle(),
                    Text(
                      title,
                      textAlign:
                          centerTitle ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign:
                            centerTitle ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    child,
                  ],
                ),
              ),
            ),
            _BottomCta(
              label: 'Continue',
              arrow: true,
              enabled: canContinue,
              onTap: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double progress;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onBack;

  const _TopBar({
    required this.progress,
    required this.stepNumber,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.divider,
                color: AppColors.carbs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$stepNumber/$totalSteps',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatefulWidget {
  final String label;
  final bool arrow;
  final bool enabled;
  final VoidCallback onTap;

  const _BottomCta({
    required this.label,
    required this.onTap,
    this.arrow = false,
    this.enabled = true,
  });

  @override
  State<_BottomCta> createState() => _BottomCtaState();
}

class _BottomCtaState extends State<_BottomCta> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final bg = widget.enabled ? AppColors.inkButton : AppColors.divider;
    final fg = widget.enabled ? Colors.white : AppColors.faint;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: GestureDetector(
          onTapDown: widget.enabled
              ? (_) => setState(() => _scale = 0.97)
              : null,
          onTapCancel:
              widget.enabled ? () => setState(() => _scale = 1) : null,
          onTapUp:
              widget.enabled ? (_) => setState(() => _scale = 1) : null,
          onTap: widget.enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onTap();
                }
              : null,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 110),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (widget.arrow) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Doodle extends StatelessWidget {
  const _Doodle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '///',
        style: TextStyle(
          fontSize: 16,
          letterSpacing: 3,
          fontWeight: FontWeight.w900,
          color: AppColors.carbs,
        ),
      ),
    );
  }
}

// ── step 1 · goal ─────────────────────────────────────────────────────────

class _GoalStep extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _GoalStep({required this.selected, required this.onSelect});

  static const _choices = [
    _IllustData(
      asset: 'assets/onboarding/goal_lose.jpg',
      label: 'Lose weight',
      sub: 'Burn more than you eat',
      value: 'lose',
    ),
    _IllustData(
      asset: 'assets/onboarding/goal_maintain.jpg',
      label: 'Maintain weight',
      sub: 'Stay right where you are',
      value: 'maintain',
    ),
    _IllustData(
      asset: 'assets/onboarding/goal_gain.jpg',
      label: 'Gain weight',
      sub: 'Eat more, build up',
      value: 'gain',
    ),
    _IllustData(
      asset: 'assets/onboarding/goal_explore.jpg',
      label: 'Just exploring',
      sub: 'See what the app can do',
      value: 'exploring',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [
        for (final c in _choices)
          _IllustCard(
            choice: c,
            selected: selected == c.value,
            onTap: () => onSelect(c.value),
          ),
      ],
    );
  }
}

class _IllustData {
  final String asset;
  final String label;
  final String sub;
  final String value;
  const _IllustData({
    required this.asset,
    required this.label,
    required this.sub,
    required this.value,
  });
}

/// Illustrated option card — image on top, label + sub-line below, with the
/// orange selected treatment (used by both the goal and activity screens).
class _IllustCard extends StatelessWidget {
  final _IllustData choice;
  final bool selected;
  final VoidCallback onTap;

  const _IllustCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.carbs : AppColors.divider,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.carbs.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : AppColors.cardShadowLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFFFBF3E2),
                    child: Image.asset(
                      choice.asset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        choice.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.carbs,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 2),
                  ),
                  child:
                      const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── step 2 · you ──────────────────────────────────────────────────────────

class _YouStep extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? dob;
  final String? sex;
  final VoidCallback onNameChanged;
  final VoidCallback onDobTap;
  final ValueChanged<String> onSexChanged;

  const _YouStep({
    required this.nameController,
    required this.dob,
    required this.sex,
    required this.onNameChanged,
    required this.onDobTap,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NameField(
          controller: nameController,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 10),
        _TapField(
          icon: Icons.calendar_today_outlined,
          label: 'Date of birth',
          value: dob == null
              ? null
              : _OnboardingFlowState._formatDob(dob!),
          trailing: dob == null
              ? Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.faint)
              : const Icon(Icons.check_circle,
                  size: 20, color: AppColors.carbs),
          onTap: onDobTap,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _AvatarCard(
              asset: 'assets/onboarding/avatar_male.png',
              label: 'Male',
              selected: sex == 'male',
              onTap: () => onSexChanged('male'),
            ),
            const SizedBox(width: 10),
            _AvatarCard(
              asset: 'assets/onboarding/avatar_female.png',
              label: 'Female',
              selected: sex == 'female',
              onTap: () => onSexChanged('female'),
            ),
            const SizedBox(width: 10),
            _AvatarCard(
              asset: 'assets/onboarding/avatar_other.png',
              label: 'Other',
              selected: sex == 'others',
              onTap: () => onSexChanged('others'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Better choices.\nHealthier you.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.2,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
            const AppImage(
              path: 'assets/onboarding/bowl_illustration.png',
              width: 120,
              height: 90,
              radius: 16,
            ),
          ],
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.5),
        boxShadow: AppColors.cardShadowLight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Name',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.faint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarCard({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.carbs.withValues(alpha: 0.08)
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.carbs : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  AppImage(
                    path: asset,
                    width: 54,
                    height: 54,
                    radius: 27,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -4,
                  right: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.carbs,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 1.5),
                    ),
                    child: const Icon(Icons.check,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── step 3 · height & weight ──────────────────────────────────────────────

class _BodyStep extends StatefulWidget {
  final double heightCm;
  final double weightKg;
  final ValueChanged<double> onHeightDrag;
  final ValueChanged<double> onWeightDrag;
  final VoidCallback onHeightTap;
  final VoidCallback onWeightTap;

  const _BodyStep({
    required this.heightCm,
    required this.weightKg,
    required this.onHeightDrag,
    required this.onWeightDrag,
    required this.onHeightTap,
    required this.onWeightTap,
  });

  @override
  State<_BodyStep> createState() => _BodyStepState();
}

class _BodyStepState extends State<_BodyStep> {
  bool _useFeet = true;
  bool _useLbs = false;

  // Local copies so a drag rebuilds only this subtree (not the whole flow).
  late double _h = widget.heightCm;
  late double _w = widget.weightKg;

  @override
  void didUpdateWidget(_BodyStep old) {
    super.didUpdateWidget(old);
    // Value changed from outside (wheel sheet / draft restore) — re-sync.
    if (widget.heightCm != old.heightCm && widget.heightCm != _h) {
      _h = widget.heightCm;
    }
    if (widget.weightKg != old.weightKg && widget.weightKg != _w) {
      _w = widget.weightKg;
    }
  }

  void _dragHeight(double v) {
    setState(() => _h = v);
    widget.onHeightDrag(v); // silent sync (no parent rebuild)
  }

  void _dragWeight(double v) {
    setState(() => _w = v);
    widget.onWeightDrag(v); // silent sync (no parent rebuild)
  }

  String get _heightText {
    if (_useFeet) {
      final totalInches = (_h / 2.54).round();
      return '${totalInches ~/ 12} ft ${totalInches % 12} in';
    }
    return '${_h.round()} cm';
  }

  String get _weightText => _useLbs
      ? '${(_w * 2.20462).round()} lbs'
      : '${_w.round()} kg';

  double get _bmi {
    final m = _h / 100.0;
    if (m <= 0) return 0;
    return _w / (m * m);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BodyCard(
          asset: 'assets/onboarding/body_height.jpg',
          label: 'Height',
          value: _heightText,
          units: const ['ft / in', 'cm'],
          activeUnit: _useFeet ? 0 : 1,
          onUnit: (i) => setState(() => _useFeet = i == 0),
          ruler: _Ruler(
            value: _h,
            min: 120,
            max: 220,
            onChanged: _dragHeight,
          ),
          onTap: widget.onHeightTap,
        ),
        const SizedBox(height: 12),
        _BodyCard(
          asset: 'assets/onboarding/body_weight.jpg',
          label: 'Current weight',
          value: _weightText,
          units: const ['kg', 'lbs'],
          activeUnit: _useLbs ? 1 : 0,
          onUnit: (i) => setState(() => _useLbs = i == 1),
          ruler: _Ruler(
            value: _w,
            min: 30,
            max: 200,
            onChanged: _dragWeight,
          ),
          onTap: widget.onWeightTap,
        ),
        const SizedBox(height: 16),
        _BmiChip(bmi: _bmi),
      ],
    );
  }
}

class _BodyCard extends StatelessWidget {
  final String asset;
  final String label;
  final String value;
  final List<String> units;
  final int activeUnit;
  final ValueChanged<int> onUnit;
  final Widget ruler;
  final VoidCallback onTap;

  const _BodyCard({
    required this.asset,
    required this.label,
    required this.value,
    required this.units,
    required this.activeUnit,
    required this.onUnit,
    required this.ruler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFBF3E2),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < units.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onUnit(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == activeUnit
                                ? AppColors.ink
                                : AppColors.chipNeutral,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            units[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == activeUnit
                                  ? Colors.white
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ruler,
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 18),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tactile ruler you drag to change the value (tap the chevron for precision).
/// Keeps a FRACTIONAL phase locally, so the ticks scroll continuously instead
/// of snapping per unit, and reports whole values upward.
class _Ruler extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _Ruler({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_Ruler> createState() => _RulerState();
}

class _RulerState extends State<_Ruler> {
  static const double _pxPerUnit = 5.0;
  late double _phase = widget.value;

  @override
  void didUpdateWidget(_Ruler old) {
    super.didUpdateWidget(old);
    // Jumped from elsewhere (wheel sheet): snap the phase.
    if (widget.value != old.value && (widget.value - _phase).abs() >= 0.5) {
      _phase = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            final next =
                (_phase - d.delta.dx / _pxPerUnit).clamp(widget.min, widget.max);
            setState(() => _phase = next);
            final rounded = next.roundToDouble();
            if (rounded != widget.value) {
              HapticFeedback.selectionClick();
              widget.onChanged(rounded);
            }
          },
          child: SizedBox(
            height: 36,
            width: constraints.maxWidth,
            child: CustomPaint(
              painter: _RulerPainter(
                value: _phase,
                min: widget.min,
                pxPerUnit: _pxPerUnit,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;
  final double min;
  final double pxPerUnit;

  _RulerPainter({
    required this.value,
    required this.min,
    required this.pxPerUnit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFFBF3E2);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, bg);

    canvas.save();
    canvas.clipRRect(rrect);

    final tick = Paint()
      ..color = const Color(0x2E1C1C1E)
      ..strokeWidth = 1;
    const spacing = 11.0;
    final phase = -((value - min) * pxPerUnit) % spacing;
    for (var x = phase; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
          Offset(x, size.height * 0.18), Offset(x, size.height * 0.82), tick);
    }

    // Centre indicator
    final center = Paint()
      ..color = AppColors.carbs
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, 2),
        Offset(size.width / 2, size.height - 2), center);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.value != value || old.min != min;
}

/// Live BMI chip — updates as height/weight change, with a position marker.
class _BmiChip extends StatelessWidget {
  final double bmi;

  const _BmiChip({required this.bmi});

  (String, Color) get _band {
    if (bmi <= 0) return ('—', AppColors.muted);
    if (bmi < 18.5) return ('Below range', const Color(0xFF7FC8F8));
    if (bmi < 25) return ('Healthy', AppColors.green);
    if (bmi < 30) return ('Above range', AppColors.carbs);
    return ('High', const Color(0xFFFF6B6B));
  }

  @override
  Widget build(BuildContext context) {
    final (bandLabel, bandColor) = _band;
    final marker = ((bmi - 15) / (35 - 15)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: bandColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BMI ${bmi.toStringAsFixed(1)} · $bandLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text('Updates as you adjust',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 86,
            height: 8,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7FC8F8),
                          AppColors.green,
                          AppColors.carbs,
                          Color(0xFFFF6B6B),
                        ],
                        stops: [0.18, 0.35, 0.70, 0.95],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth - 3) * marker,
                    top: -3,
                    child: Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── step 4 · activity ─────────────────────────────────────────────────────

class _ActivityStep extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ActivityStep({required this.selected, required this.onSelect});

  static const _choices = [
    _IllustData(
      asset: 'assets/onboarding/act_none.jpg',
      label: 'No workout',
      sub: 'Mostly sitting',
      value: 'none',
    ),
    _IllustData(
      asset: 'assets/onboarding/act_1to2.jpg',
      label: '1–2 times a week',
      sub: 'Light activity',
      value: '1to2',
    ),
    _IllustData(
      asset: 'assets/onboarding/act_3to5.jpg',
      label: '3–5 times a week',
      sub: 'Active',
      value: '3to5',
    ),
    _IllustData(
      asset: 'assets/onboarding/act_6plus.jpg',
      label: '6+ times a week',
      sub: 'Very active',
      value: '6plus',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [
        for (final c in _choices)
          _IllustCard(
            choice: c,
            selected: selected == c.value,
            onTap: () => onSelect(c.value),
          ),
      ],
    );
  }
}

// ── step 5 · target & pace ────────────────────────────────────────────────

class _TargetPaceStep extends StatefulWidget {
  final double targetWeight;
  final double currentWeight;
  final ValueChanged<double> onTargetDrag;
  final VoidCallback onTargetTap;
  final String? pace;
  final ValueChanged<String> onPace;
  final Map<String, String> Function(double target, String pace) statsFor;
  final bool noTarget;
  final ValueChanged<bool> onNoTarget;
  final bool isLose;

  const _TargetPaceStep({
    required this.targetWeight,
    required this.currentWeight,
    required this.onTargetDrag,
    required this.onTargetTap,
    required this.pace,
    required this.onPace,
    required this.statsFor,
    required this.noTarget,
    required this.onNoTarget,
    required this.isLose,
  });

  @override
  State<_TargetPaceStep> createState() => _TargetPaceStepState();
}

class _TargetPaceStepState extends State<_TargetPaceStep> {
  static const _paces = [
    (value: 'slow', name: 'Slow'),
    (value: 'recommended', name: 'Moderate'),
    (value: 'fast', name: 'Fast'),
  ];

  late double _target = widget.targetWeight;

  @override
  void didUpdateWidget(_TargetPaceStep old) {
    super.didUpdateWidget(old);
    if (widget.targetWeight != old.targetWeight &&
        widget.targetWeight != _target) {
      _target = widget.targetWeight;
    }
  }

  void _dragTarget(double v) {
    setState(() => _target = v);
    widget.onTargetDrag(v); // silent sync
  }

  // Never let the ruler cross the current weight the wrong way — that would
  // silently invalidate the "Continue" gate.
  double get _min =>
      widget.isLose ? 30 : (widget.currentWeight + 1).clamp(30, 200);
  double get _max =>
      widget.isLose ? (widget.currentWeight - 1).clamp(30, 200) : 200;

  /// Signature of the numbers a pace would show, so we can spot duplicates.
  String _sig(String pace) {
    final s = widget.statsFor(_target, pace);
    return '${s['kcal']}/${s['weekly']}/${s['time']}';
  }

  @override
  Widget build(BuildContext context) {
    // When the safety floor binds, faster paces collapse to the same plan.
    // Showing two identical options is confusing, so drop the duplicate.
    final modDupSlow = _sig('recommended') == _sig('slow');
    final modDupFast = _sig('recommended') == _sig('fast');
    final hideModerate = modDupSlow || modDupFast;

    var current = widget.pace ?? 'recommended';
    if (hideModerate && current == 'recommended') {
      current = modDupSlow ? 'slow' : 'fast';
      // Persist the visible choice (same plan, but keeps profile + UI in sync).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.pace == 'recommended') {
          widget.onPace(current);
        }
      });
    }
    final stats = widget.statsFor(_target, current);

    return Column(
      children: [
        if (!widget.noTarget) ...[
          _ProjectionCard(
            stats: stats,
            minutes: null,
            currentWeight: widget.currentWeight,
            targetWeight: _target,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider, width: 1.2),
              boxShadow: AppColors.cardShadowLight,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target weight',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          '${_target.round()} kg',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onTargetTap,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 22, color: AppColors.faint),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Ruler(
                  value: _target,
                  min: _min,
                  max: _max,
                  onChanged: _dragTarget,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final p in [
                for (final pace in _paces)
                  if (!(hideModerate && pace.value == 'recommended')) pace,
              ]) ...[
                if (p.value != 'slow') const SizedBox(width: 8),
                _PacePill(
                  title: p.name,
                  rate: '${widget.statsFor(_target, p.value)['weekly']} kg/wk',
                  time: widget.statsFor(_target, p.value)['time'] ?? '',
                  selected: current == p.value,
                  onTap: () => widget.onPace(p.value),
                ),
              ],
            ],
          ),
          if (stats['floor'] == '1') ...[
            const SizedBox(height: 10),
            Text(
              '${stats['kcal']} kcal/day is your safe minimum, so a faster '
              'pace gives the same plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.faint,
              ),
            ),
          ],
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => widget.onNoTarget(!widget.noTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.noTarget
                  ? 'Set a target weight'
                  : 'I don\'t have a target, just tracking',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The plan preview: a weight-trend curve from today to the goal, with the
/// kcal/day, timeline and weekly rate it implies.
class _ProjectionCard extends StatelessWidget {
  final Map<String, String> stats;
  final Object? minutes;
  final double currentWeight;
  final double targetWeight;

  const _ProjectionCard({
    required this.stats,
    required this.minutes,
    required this.currentWeight,
    required this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    final time = (stats['time'] ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Your projected progress',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) => CustomPaint(
                      painter: _TrendPainter(progress: t),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text('Now ${currentWeight.round()} kg',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text('Goal ${targetWeight.round()} kg',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(height: 1, color: AppColors.divider),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PlanStat(value: stats['kcal'] ?? '—', label: 'kcal / day'),
              _PlanStat(
                  value: time.isEmpty ? 'a while' : '~$time',
                  label: 'to goal'),
              _PlanStat(value: stats['weekly'] ?? '0', label: 'kg / week'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  final String value;
  final String label;

  const _PlanStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Draws the projection curve (today top-left -> goal bottom-right) with a
/// soft fill, a dashed goal line, and the two end points.
class _TrendPainter extends CustomPainter {
  final double progress;

  _TrendPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 6.0;
    final right = size.width - 6;
    const top = 26.0;
    final bottom = size.height - 26;
    final w = right - left;
    final h = bottom - top;

    final path = Path()..moveTo(left, top);
    // A gentle S so the trend reads as a real curve, not a straight ramp.
    path.cubicTo(left + w * 0.28, top + h * 0.18 * progress,
        left + w * 0.66, top + h * 0.78 * progress, right, top + h * progress);

    final fill = Path.from(path)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.carbs.withValues(alpha: 0.22),
            AppColors.carbs.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.carbs,
    );

    // Dashed goal line
    final dash = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 2;
    for (var x = left; x < right; x += 10) {
      canvas.drawLine(Offset(x, bottom), Offset(x + 5, bottom), dash);
    }

    // End points
    canvas.drawCircle(
        Offset(left, top), 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(left, top),
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.carbs,
    );
    canvas.drawCircle(Offset(right, top + h * progress), 5,
        Paint()..color = AppColors.carbs);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.progress != progress;
}


class _PacePill extends StatelessWidget {
  final String title;
  final String rate;
  final String time;
  final bool selected;
  final VoidCallback onTap;

  const _PacePill({
    required this.title,
    required this.rate,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.carbs.withValues(alpha: 0.08)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.carbs : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                rate,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                time.isEmpty ? '—' : '~$time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── shared option / field widgets ─────────────────────────────────────────

class _TapField extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback onTap;

  const _TapField({
    this.icon,
    required this.label,
    this.value,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: AppColors.cardShadowLight,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: AppColors.muted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                  color: hasValue ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            if (hasValue)
              Text(
                value!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── building screen ───────────────────────────────────────────────────────

class _BuildingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const _BuildingScreen({required this.onDone});

  @override
  State<_BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<_BuildingScreen> {
  static const _items = [
    'Finalized your goal',
    'Set your calorie target',
    'Planned your macros',
    'Estimated your timeline',
  ];
  int _visible = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) return;
      if (_visible < _items.length) {
        setState(() => _visible++);
      } else {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Building your plan…',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < _items.length; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: i < _visible ? 1 : 0.18,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          i < _visible
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: i < _visible
                              ? AppColors.green
                              : AppColors.faint,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _items[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
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
}

// ── plan ready screen ─────────────────────────────────────────────────────

class _PlanReadyScreen extends StatelessWidget {
  final Profile profile;
  final String name;
  final String goalSummary;
  final String workoutSummary;
  final VoidCallback onBack;
  final VoidCallback onGetStarted;

  const _PlanReadyScreen({
    required this.profile,
    required this.name,
    required this.goalSummary,
    required this.workoutSummary,
    required this.onBack,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              progress: 1,
              stepNumber: 6,
              totalSteps: 6,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.carbs.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 30, color: AppColors.carbs),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your plan is ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hi $name — here\'s your daily target.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PlanHero(profile: profile),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Your goal',
                      value: goalSummary,
                      glyph: const _SparkGlyph(),
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Workouts',
                      value: workoutSummary,
                      glyph: const _BarsGlyph(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'You can change any of this later in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
            ),
            _BottomCta(
              label: 'Start tracking',
              arrow: true,
              enabled: true,
              onTap: onGetStarted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The daily target, in the same language as Home: a calorie ring + macros.
class _PlanHero extends StatelessWidget {
  final Profile profile;

  const _PlanHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 0.78),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => SizedBox(
                    width: 148,
                    height: 148,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.track,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.carbs),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountUp(
                      value: profile.calorieGoal,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                    Text('kcal / day',
                        style: TextStyle(
                            fontSize: 10.5, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroCol(
                  color: AppColors.green,
                  grams: profile.proteinGrams,
                  label: 'Protein'),
              _MacroCol(
                  color: AppColors.carbs,
                  grams: profile.carbsGrams,
                  label: 'Carbs'),
              _MacroCol(
                  color: const Color(0xFF8B5CF6),
                  grams: profile.fatGrams,
                  label: 'Fats'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroCol extends StatelessWidget {
  final Color color;
  final int grams;
  final String label;

  const _MacroCol({
    required this.color,
    required this.grams,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          CountUp(
            value: grams,
            suffix: 'g',
            duration: const Duration(milliseconds: 900),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// A summary row with a small glyph on the right.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget glyph;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ],
            ),
          ),
          glyph,
        ],
      ),
    );
  }
}

/// Mini projection curve for the goal row.
class _SparkGlyph extends StatelessWidget {
  const _SparkGlyph();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 76, height: 30, child: CustomPaint(painter: _SparkPainter()));
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(2, 5)
      ..cubicTo(w * 0.32, h * 0.3, w * 0.66, h * 0.72, w - 2, h - 5);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.carbs,
    );
    canvas.drawCircle(Offset(2, 5), 3.4, Paint()..color = AppColors.card);
    canvas.drawCircle(
      Offset(2, 5),
      3.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.carbs,
    );
    canvas.drawCircle(
        Offset(w - 2, h - 5), 3.4, Paint()..color = AppColors.carbs);
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

/// Mini weekly bars for the workouts row.
class _BarsGlyph extends StatelessWidget {
  const _BarsGlyph();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 76, height: 30, child: CustomPaint(painter: _BarsPainter()));
}

class _BarsPainter extends CustomPainter {
  static const _heights = [0.4, 0.6, 1.0, 0.75, 0.5];

  @override
  void paint(Canvas canvas, Size size) {
    const bw = 8.0;
    final gap = (size.width - bw * _heights.length) / (_heights.length - 1);
    for (var i = 0; i < _heights.length; i++) {
      final h = size.height * _heights[i];
      final x = i * (bw + gap);
      final active = _heights[i] == 1.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, bw, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = AppColors.carbs
              .withValues(alpha: active ? 1.0 : 0.35 + i * 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

// ── wheel sheets (height + weight) ────────────────────────────────────────

Future<int?> _showWheelSheet(
  BuildContext context, {
  required String title,
  required int min,
  required int max,
  required int value,
  required String suffix,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WheelSheet(
      title: title,
      min: min,
      max: max,
      value: value,
      suffix: suffix,
    ),
  );
}

class _WheelSheet extends StatefulWidget {
  final String title;
  final int min;
  final int max;
  final int value;
  final String suffix;

  const _WheelSheet({
    required this.title,
    required this.min,
    required this.max,
    required this.value,
    required this.suffix,
  });

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  late int _value = widget.value.clamp(widget.min, widget.max);
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _value - widget.min);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: widget.title,
            onCancel: () => Navigator.pop(context),
            onDone: () => Navigator.pop(context, _value),
          ),
          SizedBox(
            height: 210,
            child: _Wheel(
              controller: _controller,
              min: widget.min,
              max: widget.max,
              value: _value,
              suffix: widget.suffix,
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int min;
  final int max;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.controller,
    required this.min,
    required this.max,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const itemExtent = 46.0;
    return Stack(
      children: [
        Positioned(
          left: 40,
          right: 40,
          top: (210 - itemExtent) / 2,
          height: itemExtent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.chipNeutral,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: itemExtent,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => onChanged(min + i),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: max - min + 1,
            builder: (context, i) => Center(
              child: Text(
                '${min + i} $suffix',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      (min + i) == value ? FontWeight.w800 : FontWeight.w500,
                  color:
                      (min + i) == value ? AppColors.ink : AppColors.faint,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<double?> _showHeightSheet(BuildContext context, double heightCm) async {
  final totalInches = (heightCm / 2.54).round();
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HeightSheet(
      feet: totalInches ~/ 12,
      inches: totalInches % 12,
    ),
  );
}

class _HeightSheet extends StatefulWidget {
  final int feet;
  final int inches;

  const _HeightSheet({required this.feet, required this.inches});

  @override
  State<_HeightSheet> createState() => _HeightSheetState();
}

class _HeightSheetState extends State<_HeightSheet> {
  late int _feet = widget.feet.clamp(3, 8);
  late int _inches = widget.inches.clamp(0, 11);
  late final FixedExtentScrollController _feetC =
      FixedExtentScrollController(initialItem: _feet - 3);
  late final FixedExtentScrollController _inchesC =
      FixedExtentScrollController(initialItem: _inches);

  @override
  void dispose() {
    _feetC.dispose();
    _inchesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: 'Height',
            onCancel: () => Navigator.pop(context),
            onDone: () => Navigator.pop(
                context, (_feet * 30.48 + _inches * 2.54).roundToDouble()),
          ),
          SizedBox(
            height: 210,
            child: Row(
              children: [
                Expanded(
                  child: _Wheel(
                    controller: _feetC,
                    min: 3,
                    max: 8,
                    value: _feet,
                    suffix: 'ft',
                    onChanged: (v) => setState(() => _feet = v),
                  ),
                ),
                Expanded(
                  child: _Wheel(
                    controller: _inchesC,
                    min: 0,
                    max: 11,
                    value: _inches,
                    suffix: 'in',
                    onChanged: (v) => setState(() => _inches = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const _SheetHeader({
    required this.title,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDone,
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.carbs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

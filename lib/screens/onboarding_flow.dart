import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/funnel.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
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

  static String _formatHeight(double cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet ft $inches in';
  }

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

  Map<String, String> _paceDetail(String pace) {
    final p = _buildProfile().copyWith(pace: pace);
    return {
      'time': _formatWeeks(p.weeksToGoal),
      'kcal': '${p.calorieGoal}',
      'weekly': p.weeklyChangeKg.abs().toStringAsFixed(1),
      'totalKg': (_weight - _targetWeight).abs().toStringAsFixed(0),
      'floor': p.floorHit ? '1' : '0',
    };
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
      return PricingScreen(storage: widget.storage, onPaid: _onPaid);
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
          subtitle: 'Tap to adjust — no typing needed.',
          canContinue: _canContinue,
          onContinue: _next,
          child: _BodyStep(
            heightLabel: _formatHeight(_height),
            weightLabel: '${_weight.round()} kg',
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
            targetLabel: '${_targetWeight.round()} kg',
            onTargetTap: _pickTargetWeight,
            pace: _pace,
            onPace: (v) => setState(() => _pace = v),
            detailFor: _paceDetail,
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

class _Choice {
  final IconData icon;
  final String label;
  final String value;
  const _Choice(this.icon, this.label, this.value);
}

class _GoalStep extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _GoalStep({required this.selected, required this.onSelect});

  static const _choices = [
    _Choice(Icons.trending_down_rounded, 'Lose weight', 'lose'),
    _Choice(Icons.balance_rounded, 'Maintain weight', 'maintain'),
    _Choice(Icons.trending_up_rounded, 'Gain weight / Build muscle', 'gain'),
    _Choice(Icons.explore_outlined, 'Just exploring', 'exploring'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionCard(
              icon: c.icon,
              label: c.label,
              selected: selected == c.value,
              onTap: () => onSelect(c.value),
            ),
          ),
      ],
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

class _BodyStep extends StatelessWidget {
  final String heightLabel;
  final String weightLabel;
  final VoidCallback onHeightTap;
  final VoidCallback onWeightTap;

  const _BodyStep({
    required this.heightLabel,
    required this.weightLabel,
    required this.onHeightTap,
    required this.onWeightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TapField(label: 'Height', value: heightLabel, onTap: onHeightTap),
        const SizedBox(height: 10),
        _TapField(
            label: 'Current weight', value: weightLabel, onTap: onWeightTap),
      ],
    );
  }
}

// ── step 4 · activity ─────────────────────────────────────────────────────

class _ActivityStep extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ActivityStep({required this.selected, required this.onSelect});

  static const _choices = [
    _Choice(Icons.weekend_outlined, '0–2 times a week', '0to2'),
    _Choice(Icons.directions_walk_rounded, '3–5 times a week', '3to5'),
    _Choice(Icons.directions_run_rounded, '6+ times a week', '6plus'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionCard(
              icon: c.icon,
              label: c.label,
              selected: selected == c.value,
              onTap: () => onSelect(c.value),
            ),
          ),
      ],
    );
  }
}

// ── step 5 · target & pace ────────────────────────────────────────────────

class _TargetPaceStep extends StatelessWidget {
  final String targetLabel;
  final VoidCallback onTargetTap;
  final String? pace;
  final ValueChanged<String> onPace;
  final Map<String, String> Function(String pace) detailFor;
  final bool noTarget;
  final ValueChanged<bool> onNoTarget;
  final bool isLose;

  const _TargetPaceStep({
    required this.targetLabel,
    required this.onTargetTap,
    required this.pace,
    required this.onPace,
    required this.detailFor,
    required this.noTarget,
    required this.onNoTarget,
    required this.isLose,
  });

  @override
  Widget build(BuildContext context) {
    final current = pace ?? 'recommended';
    final detail = detailFor(current);
    final action = isLose ? 'lose' : 'gain';
    final paces = const [
      (value: 'slow', name: 'Slow'),
      (value: 'recommended', name: 'Moderate'),
      (value: 'fast', name: 'Fast'),
    ];

    return Column(
      children: [
        if (!noTarget)
          _TapField(
              label: 'Target weight', value: targetLabel, onTap: onTargetTap),
        const SizedBox(height: 14),
        if (!noTarget)
          Row(
            children: [
              for (var i = 0; i < paces.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _PacePill(
                  title: paces[i].name,
                  sub: '~${detailFor(paces[i].value)['weekly']} kg/wk',
                  selected: current == paces[i].value,
                  onTap: () => onPace(paces[i].value),
                ),
              ],
            ],
          ),
        if (!noTarget) const SizedBox(height: 12),
        if (!noTarget)
          Text(
            'You\'ll $action about ${detail['totalKg']} kg in '
            '${(detail['time'] ?? '').isEmpty ? 'a while' : detail['time']}, '
            'eating ${detail['kcal']} kcal/day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        if (!noTarget && detail['floor'] == '1') ...[
          const SizedBox(height: 6),
          Text(
            '${detail['kcal']} kcal/day is your safe minimum, so a faster '
            'pace gives the same plan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.faint,
            ),
          ),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => onNoTarget(!noTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              noTarget
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

class _PacePill extends StatelessWidget {
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _PacePill({
    required this.title,
    required this.sub,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── shared option / field widgets ─────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.carbs.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.carbs : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: AppColors.cardShadowLight,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColors.carbs : AppColors.chipNeutral,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.carbs,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inkButton,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          _Stat(
                              value: '${profile.calorieGoal}',
                              label: 'kcal/day'),
                          _Stat(
                              value: '${profile.proteinGrams}g',
                              label: 'protein'),
                          _Stat(
                              value: '${profile.carbsGrams}g',
                              label: 'carbs'),
                          _Stat(
                              value: '${profile.fatGrams}g', label: 'fat'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(label: 'Goal', value: goalSummary),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Workouts', value: workoutSummary),
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

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.5),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.5, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
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

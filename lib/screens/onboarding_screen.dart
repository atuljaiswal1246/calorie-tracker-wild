import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/profile.dart';
import '../services/funnel.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
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

  /// Start directly at the sign-up step (onboarding already done once,
  /// user dropped off before creating an account).
  final bool startAtSignup;

  /// Start at a saved position in the questionnaire (a relaunch mid-journey:
  /// the user had reached the goal page, sign-up or payment and reopens the
  /// app — resume where they left off, never restart).
  final int? startAtStep;

  OnboardingScreen({
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
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // 0-6 are questions; 7 = "building your plan"; 8 = plan summary;
  // 9 = sign-up; 10 = pricing.
  static const _totalSteps = 7;
  static const _buildingStep = 7;
  static const _planStep = 8;
  static const _signupStep = 9;
  static const _pricingStep = 10;

  // Step 0: name/date-of-birth/sex
  final _nameController = TextEditingController();
  DateTime? _dob;
  String? _sex;

  // Step 1: goal
  String? _goal;
  static final _goals = [
    _Option(icon: Icons.arrow_downward, label: 'Lose weight', value: 'lose'),
    _Option(icon: Icons.balance, label: 'Maintain weight', value: 'maintain'),
    _Option(
        icon: Icons.arrow_upward,
        label: 'Gain weight / Build muscle',
        value: 'gain'),
    _Option(icon: Icons.explore_outlined, label: 'Just exploring', value: 'exploring'),
  ];

  // Steps 2-6: height, weight, workouts, target, pace
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
  static final _workoutFreqs = [
    _Option(icon: Icons.horizontal_rule, label: 'No workout', value: 'none'),
    _Option(icon: Icons.looks_one, label: '1–2', value: '0to2'),
    _Option(icon: Icons.looks_two, label: '3–5', value: '3to5'),
    _Option(icon: Icons.looks_3, label: '6 or more', value: '6plus'),
  ];

  @override
  void initState() {
    super.initState();
    _goal = _goals.first.value;
    _pace = 'fast';
    _workoutFreq = _workoutFreqs.first.value;
    if (widget.startAtPricing) {
      _step = _pricingStep;
    } else if (widget.startAtSignup) {
      _restoreFromSavedProfile();
      _step = _signupStep;
    } else if (widget.startAtStep != null && widget.startAtStep! > 0) {
      // Resume mid-journey from the saved draft (0 < step < plan summary).
      _restoreFromDraft(widget.storage.onboardingDraft);
      _step = widget.startAtStep!.clamp(0, _totalSteps - 1);
    }
    _stepStartedAt = DateTime.now();
    Funnel.onboardingStart(_step);
    if (_step == _pricingStep) Funnel.paywallView();
  }

  DateTime _stepStartedAt = DateTime.now();

  String _stepName(int s) => switch (s) {
        0 => 'name_sex',
        1 => 'goal',
        2 => 'weight',
        3 => 'target_weight',
        4 => 'height',
        5 => 'workouts',
        6 => 'pace',
        7 => 'building',
        8 => 'plan',
        9 => 'signup',
        10 => 'pricing',
        _ => 'unknown',
      };

  void _logStep(int step) {
    Funnel.stepComplete(step, _stepName(step),
        DateTime.now().difference(_stepStartedAt).inMilliseconds);
    _stepStartedAt = DateTime.now();
  }

  /// Restore all question answers from the saved profile (drop-off recovery:
  /// user completes questions but abandons at sign-up; we must not clobber
  /// their real answers with defaults when they finish signing up).
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

  /// Restore answers from the saved draft (mid-questionnaire relaunch).
  void _restoreFromDraft(Map<String, dynamic>? d) {
    if (d == null) return;
    final name = d['name'] as String?;
    _nameController.text = name ?? '';
    final dob = d['dob'] as String?;
    _dob = dob != null ? DateTime.tryParse(dob) : null;
    _sex = d['sex'] as String?;
    _goal = (d['goal'] as String?) ?? _goals.first.value;
    _weight = (d['weightKg'] as num?)?.toDouble() ?? 70;
    _targetWeight = (d['targetWeightKg'] as num?)?.toDouble() ?? _weight;
    _noTarget = (d['noTarget'] as bool?) ?? false;
    _height = (d['heightCm'] as num?)?.toDouble() ?? 165;
    _workoutFreq =
        (d['workoutFreq'] as String?) ?? _workoutFreqs.first.value;
    _pace = (d['pace'] as String?) ?? 'fast';
  }

  /// Persist the journey: current step + answers, so killing the app at the
  /// goal page, sign-up screen or payment screen resumes in place.
  void _saveDraft() {
    final dobIso = _dob == null
        ? null
        : '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
    widget.storage.saveOnboardingDraft({
      'step': _step,
      'name': _nameController.text.trim(),
      'dob': dobIso,
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _progress => (_step + 1) / _totalSteps;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _dob != null &&
            _sex != null;
      case 1:
        return _goal != null;
      case 2:
        return _weight > 0 && _weight <= 300;
      case 3:
        if (_skipTargetQuestions) return true;
        final v = _targetWeight;
        if (v < 30 || v > 300) return false;
        if (_goal == 'lose') return v < _weight;
        if (_goal == 'gain') return v > _weight;
        return true;
      case 4:
        return _height >= 50 && _height <= 250;
      case 5:
        return _workoutFreq != null;
      case 6:
        return _pace != null;
      default:
        return false;
    }
  }

  Future<void> _pickDob() async {
    // Material date picker opens on year grid — fastest path for DOB.
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _next() {
    _logStep(_step);
    setState(() {
      _step++;
      // Skip target-weight & pace when there's no target OR the goal
      // doesn't involve weight change (maintain / exploring).
      if (_skipTargetQuestions && _step == 3) _step += 1;
      if (_skipTargetQuestions && _step == 6) _step += 1;
    });
    _saveDraft();
  }

  void _toPlan() {
    _logStep(_step);
    Funnel.questionsComplete();
    setState(() => _step = _planStep);
    Funnel.planView();
    // Drop-off recovery: save the profile NOW, before the sign-up wall.
    // If the user abandons here, next launch resumes at sign-up with their
    // answers intact instead of restarting the questionnaire.
    widget.storage.saveProfile(_buildProfile());
    _saveDraft();
  }

  Future<void> _goToPricing() async {
    // Paid already (restored purchase) or sandbox dev — straight to the app.
    if (widget.storage.isPaidOrSandbox(
        authEmail: widget.auth.currentUser?.email)) {
      _finish();
      return;
    }
    // Unpaid: go to the pricing step so the user can start the Play
    // subscription (its free-trial offer IS the trial — no app timer).
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

  void _back() {
    if (_step == 0) {
      widget.onBack();
      return;
    }
    _logStep(_step);
    setState(() {
      _step--;
      // Skip target & pace when going back past them.
      if (_skipTargetQuestions && _step == 6) _step--;
      if (_skipTargetQuestions && _step == 3) _step--;
    });
    _saveDraft();
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
      'floor': p.floorHit ? '1' : '0',
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
    // Maintain / exploring skip the target question; never attach the
    // stale default (65) as if the user chose a target.
    if (_goal == 'maintain' || _goal == 'exploring') return null;
    return _targetWeight;
  }

  Future<void> _finish() async {
    final profile = _buildProfile();
    await widget.storage.saveProfile(profile);
    // Journey complete — never resume mid-questionnaire again.
    await widget.storage.clearOnboardingDraft();
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
        onGetStarted: () {
          // If already signed in, go straight to pricing; else sign up first.
          if (widget.auth.isSignedIn) {
            _goToPricing();
          } else {
            setState(() => _step = _signupStep);
            _saveDraft();
          }
        },
        onBack: () => setState(() {
          _step = _totalSteps - 1;
          if (_skipTargetQuestions && _step == 6) _step--;
        }),
        onEditAge: () async {
          var temp = _dob ?? DateTime(2000, 1, 1);
          final picked = await showModalBottomSheet<DateTime>(
            context: context,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => _DobSheet(
              initialDate: temp,
              onChanged: (d) => temp = d,
            ),
          );
          if (picked != null) setState(() => _dob = picked);
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
      );
    }
    if (_step == _signupStep) {
      return AuthScreen(
        auth: widget.auth,
        isSignUp: true,
        onAuthenticated: () async {
          final uid = widget.auth.currentUser?.uid;
          if (uid != null) widget.storage.setUserId(uid);
          // Sandbox dev email on iOS: skip pricing entirely.
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
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
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
                    color: Color(0xFFF7F7F7),
                    child: _TopBar(
                      progress: _progress,
                      stepNumber: _step + 1,
                      totalSteps: _totalSteps,
                      onBack: _back,
                    ),
                  ),
                  // Heading block — grows if it's 2 lines so the content
                  // below never gets jammed against it.
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 96),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 14, 24, 8),
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
                        padding: EdgeInsets.only(top: 28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: _buildStep(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Warning slot — collapse when empty
                  if (_buildWarning() != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 40),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                          child: _WarningBox(message: _buildWarning()!),
                        ),
                      ),
                    ),
                  // Footer option slot — collapse when empty
                  if (_buildStepFooter() is! SizedBox)
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
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
      ),
    );
  }

  Profile _buildProfile() {
    final dobIso = _dob == null
        ? null
        : '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
    return Profile(
      name: _nameController.text.trim().isEmpty ? 'Friend' : _nameController.text.trim(),
      age: _dob != null && Profile.ageFromDob(dobIso!) != null
          ? Profile.ageFromDob(dobIso)!
          : 25,
      sex: _sex ?? 'unspecified',
      dob: dobIso,
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
        return Text('First things first.',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 1:
        return Text('Choose your goal',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 2:
        return Text('What\'s your current weight?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 3:
        return Text('What\'s your target weight?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 4:
        return Text('What\'s your height?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 5:
        return Text('How many times do you\nworkout in a week?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5));
      case 6:
        return Text(
          _goal == 'gain'
              ? 'How fast do you\nwant to gain weight?'
              : 'How fast do you\nwant to lose weight?',
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: -0.5));
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _AboutYouStep(
          nameController: _nameController,
          dob: _dob,
          sex: _sex,
          onChanged: () => setState(() {}),
          onDobTap: _pickDob,
          onSexChanged: (v) => setState(() => _sex = v),
        );
      case 1:
        return _OptionStep(
          options: _goals,
          selected: _goal,
          onSelect: (v) => setState(() => _goal = v),
        );
      case 2:
        return _WeightStep(
          weightKg: _weight,
          onChangedKg: (v) => setState(() => _weight = v),
        );
      case 3:
        return _TargetWeightStep(
          targetWeight: _targetWeight,
          currentWeight: _weight,
          disabled: _noTarget,
          onChanged: (v) => setState(() => _targetWeight = v),
        );
      case 4:
        return _HeightStep(
          heightCm: _height,
          onChangedCm: (v) => setState(() => _height = v),
        );
      case 5:
        return _OptionStep(
          options: _workoutFreqs,
          selected: _workoutFreq,
          onSelect: (v) => setState(() => _workoutFreq = v),
        );
      case 6:
        return _PaceStep(
          selected: _pace,
          onSelect: (v) => setState(() => _pace = v),
          detailFor: _paceDetail,
          isLose: _goal == 'lose',
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildStepFooter() {
    if (_step == 3) {
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
    return SizedBox.shrink();
  }

  String? _buildWarning() {
    if (_step == 3) return _targetWeightWarning();
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

  _WarningBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE6C567)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Color(0xFF8A6D1F)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
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
  _Option({
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
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          suffixText: suffix,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => Navigator.pop(
            context, _parseAndClamp(controller.text, min, max, allowDecimal)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: StadiumBorder(),
          ),
          onPressed: () => Navigator.pop(
              context, _parseAndClamp(controller.text, min, max, allowDecimal)),
          child: Text('OK'),
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
      title: Text('Enter your height',
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
                  TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                suffixText: 'ft',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: inchesController,
              keyboardType: TextInputType.number,
              style:
                  TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
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
          child: Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: StadiumBorder(),
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
          child: Text('OK'),
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
  final int totalSteps;
  final VoidCallback onBack;

  _TopBar({
    required this.progress,
    required this.stepNumber,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 24, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints:
                BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 20,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              foregroundColor: Colors.black54,
            ),
            icon: Icon(Icons.arrow_back),
          ),
          SizedBox(width: 12),
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
          SizedBox(width: 12),
          Text(
            '$stepNumber/$totalSteps',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }
}

// ---------------- Bottom bar ----------------
class _BottomBar extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onContinue;
  final bool isLast;

  _BottomBar({
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
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: StadiumBorder(),
                  ),
                  onPressed: canContinue ? onContinue : null,
                  child: Text(
                    isLast ? 'Finish' : 'Continue',
                    style: TextStyle(
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

// ---------------- About you step (name + dob + sex) ----------------
class _AboutYouStep extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? dob;
  final String? sex;
  final VoidCallback onChanged;
  final VoidCallback onDobTap;
  final ValueChanged<String> onSexChanged;

  _AboutYouStep({
    required this.nameController,
    required this.dob,
    required this.sex,
    required this.onChanged,
    required this.onDobTap,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BorderedInput(
          controller: nameController,
          hintText: 'Name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
        ),
        SizedBox(height: 10),
        _DateOfBirthField(
          dob: dob,
          onTap: onDobTap,
        ),
        SizedBox(height: 10),
        Row(
          children: [
            _SexChip(
              icon: Icons.male,
              label: 'Male',
              selected: sex == 'male',
              onTap: () => onSexChanged('male'),
            ),
            SizedBox(width: 10),
            _SexChip(
              icon: Icons.female,
              label: 'Female',
              selected: sex == 'female',
              onTap: () => onSexChanged('female'),
            ),
            SizedBox(width: 10),
            _SexChip(
              icon: Icons.more_horiz,
              label: 'Other',
              selected: sex == 'others',
              onTap: () => onSexChanged('others'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DobSheet extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;

  _DobSheet({required this.initialDate, required this.onChanged});

  @override
  State<_DobSheet> createState() => _DobSheetState();
}

class _DobSheetState extends State<_DobSheet> {
  late DateTime _value = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.black54)),
              ),
              Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context, _value),
                child: Text('Done',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Divider(height: 1),
          SizedBox(
            height: 260,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: widget.initialDate,
              minimumDate: DateTime(1900),
              maximumDate: DateTime.now(),
              onDateTimeChanged: (d) {
                setState(() => _value = d);
                widget.onChanged(d);
              },
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DateOfBirthField extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onTap;

  _DateOfBirthField({
    required this.dob,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.center,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: Colors.black45),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  dob == null
                      ? 'Date of birth'
                      : _formatDob(dob!),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: dob == null
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black,
                  ),
                ),
              ),
              if (dob != null)
                Icon(Icons.check_circle,
                    size: 20, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDob(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SexChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  _SexChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : Colors.black87;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.black12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: fg),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BorderedInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final TextCapitalization? textCapitalization;
  final TextInputAction? textInputAction;
  final VoidCallback? onChanged;

  _BorderedInput({
    required this.controller,
    required this.hintText,
    this.autofocus = false,
    this.textCapitalization,
    this.textInputAction,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        textInputAction: textInputAction,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 16,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        onChanged: (_) => onChanged?.call(),
      ),
    );
  }
}

// ---------------- Option selection step ----------------
class _OptionStep extends StatelessWidget {
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  _OptionStep({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...options.map((g) => Padding(
              padding: EdgeInsets.only(bottom: 10),
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

  _PaceStep({
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
      children: [
        ...paces.map((pace) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _PaceCard(
                selected: selected == pace.value,
                icon: pace.icon,
                name: pace.name,
                detail: detailFor(pace.value),
                isLose: isLose,
                onTap: () => onSelect(pace.value),
              ),
            )),
        SizedBox(height: 4),
        // Live summary of what the selected pace means
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'At this pace, you\'ll $action about '
                '${currentDetail['totalKg']} kg in ${currentDetail['time']}, '
                'eating ${currentDetail['kcal']} kcal/day '
                '(~${currentDetail['weekly']} kg ${action == 'lose' ? 'lost' : 'gained'} '
                'per week).',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.4),
              ),
              // Honest floor: a faster pace isn't safe, so faster options are
              // the same plan. Matches how mainstream apps clamp + explain.
              if (currentDetail['floor'] == '1') ...[
                SizedBox(height: 6),
                Text(
                  '${currentDetail['kcal']} kcal/day is your safe minimum, '
                  'so a faster pace isn\'t safe — the faster options give the '
                  'same plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black45,
                      height: 1.4),
                ),
              ],
            ],
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

  _PaceCard({
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
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  SizedBox(height: 2),
                  Text(
                    '${detail['kcal']} kcal/day · ~${detail['weekly']} kg '
                        '${isLose ? 'lost' : 'gained'} per week',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(detail['time'] ?? '',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            SizedBox(width: 8),
            if (selected)
              Icon(Icons.check_circle,
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

  _SelectableCard({
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
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            SizedBox(width: 14),
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
              Icon(Icons.check_circle,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ---------------- Height step (cm OR feet/inches) ----------------
class _HeightStep extends StatefulWidget {
  final double heightCm;
  final ValueChanged<double> onChangedCm;

  _HeightStep({
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
      children: [
        // Unit toggle
        Container(
          padding: EdgeInsets.all(4),
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
        SizedBox(height: 28),
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
              SizedBox(width: 20),
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

  _UnitButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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

  _PickerWheel({
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
                physics: FixedExtentScrollPhysics(),
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
        SizedBox(height: 8),
        Text(widget.label,
            style: TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}

// A labeled picker wheel showing friendly labels (e.g. "1 month", "6 months").

// ---------------- Weight step (kg or lbs) ----------------
class _WeightStep extends StatefulWidget {
  final double weightKg;
  final ValueChanged<double> onChangedKg;

  _WeightStep({
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
      children: [
        Container(
          padding: EdgeInsets.all(4),
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
        SizedBox(height: 28),
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

  _TargetWeightStep({
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
      children: [
        Container(
          padding: EdgeInsets.all(4),
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
        SizedBox(height: 28),
        SizedBox(
          height: 200,
          child: widget.disabled
              ? SizedBox.shrink()
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

  _NoTargetCard({
    required this.noTarget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!noTarget),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            SizedBox(width: 14),
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
              Icon(Icons.check_circle,
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

  _BuildingPlanScreen({required this.onDone});

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
      await Future.delayed(Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _visible = i + 1);
    }
    if (!mounted) return;
    setState(() => _finished = true);
    await Future.delayed(Duration(milliseconds: 700));
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _finished ? 'Your goal is ready!' : 'Setting your goal...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 32),
              ...List.generate(_items.length, (i) {
                final show = i < _visible;
                return AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: show ? 1 : 0,
                  child: AnimatedPadding(
                    duration: Duration(milliseconds: 300),
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
                        SizedBox(width: 14),
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

  _PlanSummaryScreen({
    required this.profile,
    required this.onGetStarted,
    required this.onBack,
    required this.onEditAge,
    required this.onEditHeight,
    required this.onEditWeight,
    required this.onEditTarget,
    required this.onEditCalories,
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
              padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal greeting
                    Center(
                      child: Text(
                        'Hi ${profile.name.split(' ').first}!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                      ),
                    ),
                    ),
                    SizedBox(height: 10),
                    // Main heading — full-width CENTER (matches greeting)
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        _headline(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: -0.5),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Representational weight progress graph (or maintain card)
                    if (profile.targetWeightKg == null) ...[
                      _MaintainCard(profile: profile),
                    ] else ...[
                      _WeightGraph(profile: profile),
                    ],
                    SizedBox(height: 24),

                    // Daily recommendation
                    Text('Your daily recommendation',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    SizedBox(height: 10),
                    _CalorieCard(
                      profile: profile,
                      onEdit: widget.onEditCalories,
                    ),
                    SizedBox(height: 20),

                    // Macros (not editable — part of the locked plan)
                    Text('Your daily macros',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroChip(
                              label: 'Protein',
                              grams: profile.proteinGrams,
                              color: Color(0xFFE53935)),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _MacroChip(
                              label: 'Carbs',
                              grams: profile.carbsGrams,
                              color: Color(0xFF43A047)),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _MacroChip(
                              label: 'Fat',
                              grams: profile.fatGrams,
                              color: Color(0xFFFB8C00)),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Body Mass Index — category label is the hero, number
                    // is secondary.
                    Text('Your BMI',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    SizedBox(height: 10),
                    _BmiCard(profile: profile),
                    SizedBox(height: 24),

                    // Why Cal Matters
                    Text('Why Cal Matters',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.3)),
                    SizedBox(height: 10),
                    _HowCard(
                      icon: Icons.auto_awesome,
                      title: 'Made for you',
                      subtitle:
                          'A plan built around your body, goal and workouts.',
                    ),
                    _HowCard(
                      icon: Icons.trending_up,
                      title: 'Simple & honest',
                      subtitle:
                          'Realistic targets and clear progress — no shortcuts.',
                    ),
                    SizedBox(height: 24),

                    // AI disclosure
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 22, color: Colors.black54),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cal Matters uses AI to analyze your food photos '
                              'and estimate calories and macros. Estimates may '
                              'vary — always listen to your body.',
                              style: TextStyle(
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
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: StadiumBorder(),
                      ),
                      onPressed: widget.onGetStarted,
                      child: Text(
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
}

// ---------------- Maintain card (for users with no target) ----------------
class _MaintainCard extends StatelessWidget {
  final Profile profile;

  _MaintainCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance, size: 28, color: Colors.black),
          SizedBox(height: 10),
          Text('Keep your weight steady',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(
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

  _WeightGraph({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weeks = profile.weeksToGoal ?? 10;
    final start = profile.weightKg;
    final end = profile.targetWeightKg ?? start;
    final isLoss = end < start;

    // Representative points: week 0 = start, week N = end.
    final weeksToShow = weeks.clamp(1, 12);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
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
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text('→ ${end.toStringAsFixed(0)} kg',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 12),
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
                  ),                );
              },
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Week 1',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text('Week $weeks',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          SizedBox(height: 4),
          Center(
            child: Text(
              profile.weeklyChangeKg == 0
                  ? 'Maintain your weight'
                  : '${profile.weeklyChangeKg < 0 ? 'Losing' : 'Gaining'} '
                      '~${profile.weeklyChangeKg.abs().toStringAsFixed(1)} kg per week',
              style: TextStyle(fontSize: 12, color: Colors.black38),
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

    final gain = endWeight > startWeight;

    // Curve goes DOWN for weight loss, UP for weight gain.
    final path = Path();
    final startX = size.width * 0.1;
    final endX = size.width * 0.9;
    final topY = size.height * 0.15;
    final bottomY = size.height * 0.85;

    for (var i = 0; i <= weeks; i++) {
      final t = i / weeks;
      final x = startX + (endX - startX) * t;
      // smooth ease between start and end Y
      final eased = t * t * (3 - 2 * t);
      final y = gain
          ? bottomY + (topY - bottomY) * eased
          : topY + (bottomY - topY) * eased;
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
    canvas.drawCircle(Offset(startX, gain ? bottomY : topY), 4, dotPaint);
    canvas.drawCircle(Offset(endX, gain ? topY : bottomY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- Calorie card ----------------
class _CalorieCard extends StatelessWidget {
  final Profile profile;
  final Future<void> Function() onEdit;

  _CalorieCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final goal = profile.calorieGoal;
    // Maintenance = current-weight burn (what a maintain user would get).
    final tdee = (profile.currentBmr * profile.activityMultiplier).floor();
    final adjustment = goal - tdee;

    return Container(
      padding: EdgeInsets.all(24),
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
              Text('Calories',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      letterSpacing: -0.3)),
              GestureDetector(
                onTap: onEdit,
                child: Row(
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
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$goal',
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -1)),
              SizedBox(width: 8),
              Text('kcal / day',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            adjustment == 0
                ? 'Your maintenance calories — eat this to stay on track.'
                : adjustment < 0
                    ? 'That\'s a ${adjustment.abs()} kcal/day deficit from your '
                        'maintenance of $tdee kcal.'
                    : 'That\'s a ${adjustment.abs()} kcal/day surplus over your '
                        'maintenance of $tdee kcal.',
            style: TextStyle(
                fontSize: 14, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ---------------- BMI card ----------------
class _BmiCard extends StatelessWidget {
  final Profile profile;

  _BmiCard({required this.profile});

  /// BMI categories (WHO): <18.5 under, 18.5-24.9 healthy,
  /// 25-29.9 overweight, 30+ obese.
  static String _category(double bmi) {
    if (bmi < 18.5) return 'under';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'over';
    return 'obese';
  }

  static (String label, String message) _info(double bmi) {
    switch (_category(bmi)) {
      case 'under':
        return ('Underweight',
            'You\'re below the healthy range — fueling up will help.');
      case 'over':
        return ('Overweight',
            'You\'re slightly above the healthy range — your plan adjusts for this.');
      case 'obese':
        return ('Obese',
            'You\'re above the healthy range — your plan is tuned for a safe pace.');
      default:
        return ('Normal',
            'You\'re within the healthy range — keep it up!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final weight = profile.weightKg;
    final heightM = profile.heightCm / 100.0;
    final bmi = heightM > 0 ? (weight / (heightM * heightM)).toDouble() : 0.0;
    final (label, message) = _info(bmi);
    final category = _category(bmi);

    final categoryColor = switch (category) {
      'under' => Color(0xFF4DABF7),
      'over' => Color(0xFFFB8C00),
      'obese' => Color(0xFFE53935),
      _ => Color(0xFF43A047),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // THE label — biggest thing on the card, tells the story
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  switch (category) {
                    'under' => Icons.trending_down,
                    'over' || 'obese' => Icons.trending_up,
                    _ => Icons.check_circle,
                  },
                  size: 22,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: categoryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Number secondary — small, quiet under the headline
          Text(
            'BMI $bmi • ${_categoryRange(category)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
                fontSize: 13.5, color: Colors.black54, height: 1.4),
          ),
          SizedBox(height: 12),
          // Category scale (4 segments)
          Row(
            children: [
              _segment('Under', Color(0xFF4DABF7),
                  category == 'under'),
              SizedBox(width: 6),
              _segment('Normal', Color(0xFF43A047),
                  category == 'normal'),
              SizedBox(width: 6),
              _segment('Over', Color(0xFFFB8C00),
                  category == 'over'),
              SizedBox(width: 6),
              _segment('Obese', Color(0xFFE53935),
                  category == 'obese'),
            ],
          ),
        ],
      ),
    );
  }

  static String _categoryRange(String category) => switch (category) {
        'under' => 'below 18.5',
        'over' => '25 – 29.9',
        'obese' => '30 or higher',
        _ => '18.5 – 24.9',
      };

  Widget _segment(String label, Color color, bool active) {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : color,
          ),
        ),
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

  _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, color: Colors.black54)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          if (onEdit != null) ...[
            SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_outlined,
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

  _HowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.black),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
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
class PricingScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onPaid;

  PricingScreen({
    required this.storage,
    required this.onPaid,
  });

  @override
  State<PricingScreen> createState() => PricingScreenState();
}

class PricingScreenState extends State<PricingScreen> {
  bool _yearly = true; // yearly selected by default
  bool _processing = false;
  bool _approved = false;
  late final BillingService _billing;

  static const _monthlyPrice = 100;
  static const _yearlyPrice = 1000;

  /// "₹1,000" style — symbol + thousands separator.
  static String _inr(int amount) {
    final s = amount.toString();
    return '₹${s.length > 3 ? s.substring(0, s.length - 3) + ',' + s.substring(s.length - 3) : s}';
  }

  List<ProductDetails> _products = [];

  int get _savingsPercent {
    final annualIfMonthly = _monthlyPrice * 12;
    return ((annualIfMonthly - _yearlyPrice) / annualIfMonthly * 100).round();
  }

  @override
  void initState() {
    super.initState();
    _billing = BillingService(widget.storage);
    _billing.onStatusChanged = _handleStatus;
    _loadProducts();
  }

  /// The purchase stream flips billing.status asynchronously (after the
  /// Play flow closes), so react to it here — otherwise a completed payment
  /// would leave the user stuck on the payment wall until relaunch.
  void _handleStatus() {
    if (!mounted) return;
    setState(() {});
    if (_billing.status == BillingStatus.subscribed && !_approved) {
      setState(() => _approved = true);
      Future.delayed(Duration(milliseconds: 1200), () {
        if (!mounted) return;
        widget.onPaid();
      });
    }
  }

  Future<void> _loadProducts() async {
    final products = await _billing.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _processing = false;
    });
  }

  /// Prefer the free-trial OFFER entry (Google Play returns one
  /// ProductDetails per offer; the trial one has rawPrice <= 0).
  /// Falling back to the base plan if no offer is available.
  ProductDetails? get _monthlyProduct =>
      _billing.productFor(_products, BillingService.monthlyId,
          preferTrial: true);
  ProductDetails? get _yearlyProduct =>
      _billing.productFor(_products, BillingService.yearlyId,
          preferTrial: true);

  Future<void> _continue() async {
    final product = _yearly ? _yearlyProduct : _monthlyProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Products unavailable — set them up in Google Play Console.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _processing = true);
    await _billing.buyUnit(product);
    if (!mounted) return;
    setState(() => _processing = false);

    // Purchase flow returns; stream handles final status.
    // If status became subscribed (immediate), finish.
    if (_billing.status == BillingStatus.subscribed) {
      _handleStatus();
    }
    setState(() {});
  }

  Future<void> _restore() async {
    setState(() => _processing = true);
    await _billing.restore();
    if (!mounted) return;
    setState(() => _processing = false);
    // Restore completes via the purchase stream (restored purchases fire
    // purchaseStream with PurchaseStatus.restored), which sets paid=true.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restoring your purchases...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) {
      return _PaymentApprovedScreen();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No back button: once at the payment page the only way is
            // forward (pay or restore an existing purchase).
            SizedBox(height: 6),
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
                            color: Color(0xFFF7F7F7),
                            child: Center(
                              child: _PricingHeroMock(),
                            ),
                          ),
                          // Bottom fade so the heading is readable
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 150,
                              decoration: BoxDecoration(
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
                          Align(
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

                    SizedBox(height: 28),

                    // Plan options
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Yearly (default selected)
                          _PlanOptionCard(
                            selected: _yearly,
                            badge: '3 days free',
                            left: 'Start for free & save $_savingsPercent%',
                            right: '${_inr(_yearlyPrice)}/year',
                            sub: 'About ${_inr(_monthlyPrice)}/month · ${_inr(_yearlyPrice)} billed annually',
                            onTap: () => setState(() => _yearly = true),
                          ),
                          SizedBox(height: 14),
                          // Monthly
                          _PlanOptionCard(
                            selected: !_yearly,
                            badge: '3 days free',
                            left: 'Monthly',
                            right: '${_inr(_monthlyPrice)}/month',
                            sub: '3 days free, then ${_inr(_monthlyPrice)}/month',
                            onTap: () => setState(() => _yearly = false),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
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
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: StadiumBorder(),
                          ),
                          onPressed: _processing ? null : _continue,
                          child: _processing
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Continue',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.5),
                                ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _yearly
                                ? '3 days free, then ${_inr(_yearlyPrice)} per year. '
                                : '3 days free, then ${_inr(_monthlyPrice)} per month. ',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black38),
                          ),
                          TextButton(
                            onPressed: _processing ? null : _restore,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Restore purchases',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        _yearly
                            ? 'Billed annually and renews automatically unless cancelled.'
                            : 'Billed monthly and renews automatically unless cancelled.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
  _PricingHeroMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black12, width: 3),
        boxShadow: [
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
            Container(height: 28, color: Color(0xFFF6F6F6)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's calories",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('1520',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    Text('of 1829 kcal goal',
                        style: TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: 0.83,
                        minHeight: 8,
                        color: Colors.black,
                        backgroundColor: Color(0xFFEEEEEE),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMacro('Protein', '68g'),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _HeroMacro('Carbs', '190g'),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _HeroMacro('Fat', '55g'),
                        ),
                      ],
                    ),
                    Spacer(),
                    Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Log a meal',
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

  _HeroMacro(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
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

  _PlanOptionCard({
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
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.all(16),
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
                padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(left,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                ),
                SizedBox(width: 12),
                Text(right,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(width: 8),
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
              SizedBox(height: 6),
              Text(sub!,
                  style: TextStyle(
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
  _PaymentApprovedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(Icons.check_circle,
                    color: Colors.green, size: 80),
              ),
              SizedBox(height: 20),
              Text('Payment approved!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5)),
              SizedBox(height: 8),
              Text('Welcome to Cal Matters.',
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

  _MacroChip({
    required this.label,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text('$grams g',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}


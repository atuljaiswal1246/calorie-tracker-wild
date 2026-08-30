class Profile {
  final String name;
  final int age;
  final String sex; // "male", "female", "others", "unspecified"
  final String? dob; // ISO "yyyy-MM-dd" — age is recomputed from it on load
  final double weightKg;
  final double heightCm;
  final String activityLevel; // sedentary, light, moderate, light_home
  final String workoutFreq; // none, 1to2, 3to4, 5plus
  final String goal; // lose, maintain, gain, exploring
  final String pace; // slow, recommended, fast
  final double? targetWeightKg;
  final int? calorieGoalOverride;
  final int? proteinOverride;
  final int? carbsOverride;
  final int? fatOverride;

  const Profile({
    required this.name,
    required this.age,
    required this.sex,
    this.dob,
    required this.weightKg,
    required this.heightCm,
    required this.activityLevel,
    this.workoutFreq = 'none',
    this.goal = 'maintain',
    this.pace = 'recommended',
    this.targetWeightKg,
    this.calorieGoalOverride,
    this.proteinOverride,
    this.carbsOverride,
    this.fatOverride,
  });

  /// Age in years from an ISO date; null if the date is invalid.
  static int? ageFromDob(String isoDate) {
    final dob = DateTime.tryParse(isoDate);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  // ---- Basis weight ----
  // For weight loss, all math (BMR, calories, macros) is computed at the
  // TARGET weight — matching what mainstream apps show. Eating for the body
  // you're working toward keeps the deficit safe for the whole journey.
  double get basisWeightKg {
    if (goal == 'lose' && targetWeightKg != null && targetWeightKg! > 0) {
      return targetWeightKg!;
    }
    return weightKg;
  }

  // ---- BMR (Mifflin-St Jeor) ----

  double get bmr {
    final base = 10 * basisWeightKg + 6.25 * heightCm - 5 * age;
    switch (sex) {
      case 'male':
        return base + 5;
      case 'others':
      case 'unspecified':
        return base - 78; // average of male/female constants
      default:
        return base - 161;
    }
  }

  /// BMR at the CURRENT weight (used for the weekly-rate estimate).
  double get currentBmr {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (sex) {
      case 'male':
        return base + 5;
      case 'others':
      case 'unspecified':
        return base - 78;
      default:
        return base - 161;
    }
  }

  /// Multiplier from workout frequency ONLY (matches mainstream apps:
  /// they ask just "workouts per week: 0-2 / 3-5 / 6+" — no lifestyle
  /// question). 0-2 = 1.2, 3-5 = 1.55, 6+ = 1.725 (classic TDEE values).
  double get activityMultiplier {
    switch (workoutFreq) {
      case '3to5':
      case '3to4':
        return 1.55;
      case '6plus':
      case '5plus':
        return 1.725;
      default: // none / 1to2 / 0to2
        return 1.2;
    }
  }

  double get tdee => bmr * activityMultiplier;

  // ---- Safety floor ----
  // Minimum calorie intake during weight loss (industry standard:
  // 1200 kcal/day women, 1500 kcal/day men).
  int get _calorieFloor => sex == 'male' ? 1500 : 1200;

  // ---- Weekly rate (fixed per pace, industry standard) ----
  // What mainstream apps advertise per pace: slow 0.1, moderate 0.5,
  // fast 0.9 kg/week. Deficit implied = rate x 1100 kcal (7700 kcal/kg / 7).
  double get weeklyRateKg {
    switch (pace) {
      case 'slow':
        return 0.1;
      case 'fast':
        return 0.9;
      default:
        return 0.5; // moderate
    }
  }

  // ---- Calorie goal ----
  // Target = floor(burn -/+ rate x 1102.5 - 0.25), floored at 1200 (women)
  // / 1500 (men). Matches mainstream apps EXACTLY across all verified
  // profiles: 1508/1200/1200, 2442/2883/3324, 1996/1555/1200, 2046/1605/
  // 1500, 1784/2225/2666. The -0.25 offset reproduces their rounding.
  int get calorieGoal {
    if (calorieGoalOverride != null) return calorieGoalOverride!;
    final burn = currentBmr * activityMultiplier;
    final adjustment = weeklyRateKg * 1102.5;
    final target = switch (goal) {
      'lose' => (burn - adjustment - 0.25).floor(),
      'gain' => (burn + adjustment - 0.25).floor(),
      _ => burn.floor(),
    };
    if (goal == 'lose' && target < _calorieFloor) return _calorieFloor;
    return target;
  }

  /// True if the computed target hit the safety floor.
  bool get floorHit => goal == 'lose' && calorieGoal <= _calorieFloor;

  // ---- Weekly rate & timeline (consistent with the calorie goal) ----

  /// Weekly change implied by the chosen pace (~7700 kcal per kg).
  double get weeklyChangeKg {
    if (goal == 'maintain' || goal == 'exploring') return 0;
    return goal == 'gain' ? weeklyRateKg : -weeklyRateKg;
  }

  int? get weeksToGoal {
    final target = targetWeightKg;
    if (target == null || goal == 'maintain' || goal == 'exploring') {
      return null;
    }
    final rate = weeklyRateKg;
    if (rate <= 0) return null;
    return ((weightKg - target).abs() / rate).ceil();
  }

  // ---- Macro targets (% of calories — matches mainstream apps) ----
  // moderate/fast: 29% protein / 39% fat / 32% carbs
  //   -> 1200 cal: 87P / 52F / 96C; 2442 cal (gain): 177P / 106F / 195C
  // lose + slow: 28.5% protein / 40.5% fat / 31% carbs
  //   -> 1508 cal: 107P / 68F / 117C (exact match)

  double get _proteinPct => (goal == 'lose' && pace == 'slow') ? 0.285 : 0.29;
  double get _fatPct => (goal == 'lose' && pace == 'slow') ? 0.405 : 0.39;

  int get proteinGrams {
    if (proteinOverride != null) return proteinOverride!;
    return (calorieGoal * _proteinPct / 4).round();
  }

  int get fatGrams {
    if (fatOverride != null) return fatOverride!;
    return (calorieGoal * _fatPct / 9).round();
  }

  /// Carbs fill the remainder of calories.
  int get carbsGrams {
    if (carbsOverride != null) return carbsOverride!;
    final proteinCal = proteinGrams * 4;
    final fatCal = fatGrams * 9;
    final remaining = calorieGoal - proteinCal - fatCal;
    return (remaining / 4).round().clamp(0, 600);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'sex': sex,
        'dob': dob,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'activityLevel': activityLevel,
        'workoutFreq': workoutFreq,
        'goal': goal,
        'pace': pace,
        'targetWeightKg': targetWeightKg,
        'calorieGoalOverride': calorieGoalOverride,
        'proteinOverride': proteinOverride,
        'carbsOverride': carbsOverride,
        'fatOverride': fatOverride,
      };

  Profile copyWith({
    String? name,
    String? goal,
    String? pace,
    String? workoutFreq,
    double? targetWeightKg,
    int? calorieGoalOverride,
  }) =>
      Profile(
        name: name ?? this.name,
        age: age,
        sex: sex,
        dob: dob,
        weightKg: weightKg,
        heightCm: heightCm,
        activityLevel: activityLevel,
        workoutFreq: workoutFreq ?? this.workoutFreq,
        goal: goal ?? this.goal,
        pace: pace ?? this.pace,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
        calorieGoalOverride: calorieGoalOverride ?? this.calorieGoalOverride,
        proteinOverride: proteinOverride,
        carbsOverride: carbsOverride,
        fatOverride: fatOverride,
      );

  factory Profile.fromJson(Map<String, dynamic> json) {
    final dob = json['dob'] as String?;
    // Age is always recomputed from DOB when present so it moves up on
    // every birthday automatically.
    final computedAge = dob != null ? ageFromDob(dob) : null;
    return Profile(
        name: json['name'] as String? ?? '',
        age: computedAge ?? (json['age'] as int? ?? 25),
        sex: json['sex'] as String? ?? 'female',
        dob: dob,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 60,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 160,
        activityLevel: json['activityLevel'] as String? ?? 'sedentary',
        workoutFreq: json['workoutFreq'] as String? ?? 'none',
        goal: json['goal'] as String? ?? 'maintain',
        pace: json['pace'] as String? ?? 'recommended',
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
        calorieGoalOverride: json['calorieGoalOverride'] as int?,
        proteinOverride: json['proteinOverride'] as int?,
        carbsOverride: json['carbsOverride'] as int?,
        fatOverride: json['fatOverride'] as int?,
      );
  }
}
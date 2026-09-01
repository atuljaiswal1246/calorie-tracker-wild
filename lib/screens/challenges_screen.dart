import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class ChallengesScreen extends StatefulWidget {
  final StorageService storage;
  ChallengesScreen({super.key, required this.storage});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<_Challenge> _challenges = [];

  @override
  void initState() {
    super.initState();
    _computeChallenges();
  }

  void _computeChallenges() {
    final entries = widget.storage.entries;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int loggedDaysThisWeek = 0;
    int loggedDaysThisMonth = 0;
    int currentStreak = 0;
    int onTargetDays = 0;
    final goal = widget.storage.profile?.calorieGoal ?? 1500;

    // Current week (Sun–Sat)
    final weekStart = today.subtract(Duration(days: today.weekday % 7));
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (day.isAfter(today)) break;
      final dayCal = entries.where((e) => e.isOn(day)).fold(0, (s, e) => s + e.totalCalories);
      if (dayCal > 0) loggedDaysThisWeek++;
      if (dayCal >= goal * 0.8) onTargetDays++;
    }

    // Current month
    final monthStart = DateTime(now.year, now.month, 1);
    for (int i = 0; i < today.day; i++) {
      final day = monthStart.add(Duration(days: i));
      if (entries.any((e) => e.isOn(day))) loggedDaysThisMonth++;
    }

    // Streak
    var streakDay = today;
    if (!entries.any((e) => e.isOn(streakDay))) {
      streakDay = streakDay.subtract(Duration(days: 1));
    }
    while (entries.any((e) => e.isOn(streakDay))) {
      currentStreak++;
      streakDay = streakDay.subtract(Duration(days: 1));
    }

    // Water
    final waterMl = widget.storage.waterMlForDay(today);
    final waterGoal = widget.storage.waterGoalMl;

    _challenges = [
      _Challenge(
        title: 'Log 5 days this week',
        subtitle: 'Consistency builds habits',
        progress: (loggedDaysThisWeek / 5).clamp(0.0, 1.0),
        target: 5,
        current: loggedDaysThisWeek,
        icon: Icons.edit_note,
        color: AppColors.accentOrange,
      ),
      _Challenge(
        title: '7-day streak',
        subtitle: 'Log every day for a week',
        progress: (currentStreak / 7).clamp(0.0, 1.0),
        target: 7,
        current: currentStreak,
        icon: Icons.local_fire_department,
        color: AppColors.accentOrange,
      ),
      _Challenge(
        title: 'Hit your goal 3 days',
        subtitle: 'Stay within 80% of calorie target',
        progress: (onTargetDays / 3).clamp(0.0, 1.0),
        target: 3,
        current: onTargetDays,
        icon: Icons.check_circle_outline,
        color: AppColors.green,
      ),
      _Challenge(
        title: 'Log 20 days this month',
        subtitle: 'Build a monthly habit',
        progress: (loggedDaysThisMonth / 20).clamp(0.0, 1.0),
        target: 20,
        current: loggedDaysThisMonth,
        icon: Icons.calendar_month,
        color: AppColors.ink,
      ),
      _Challenge(
        title: 'Drink 8 glasses today',
        subtitle: 'Stay hydrated throughout the day',
        progress: (waterMl / waterGoal).clamp(0.0, 1.0),
        target: 8,
        current: (waterMl / 250).round(),
        icon: Icons.water_drop,
        color: AppColors.fat,
      ),
      _Challenge(
        title: 'Log breakfast 5 days',
        subtitle: 'Never skip the morning meal',
        progress: (_loggedMealType(entries, 'breakfast', today) / 5).clamp(0.0, 1.0),
        target: 5,
        current: _loggedMealType(entries, 'breakfast', today),
        icon: Icons.wb_sunny,
        color: AppColors.accentOrange,
      ),
    ];
  }

  int _loggedMealType(List<FoodEntry> entries, String type, DateTime today) {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final has = entries.where((e) => e.isOn(day) && e.mealType == type).isNotEmpty;
      if (has) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _challenges.where((c) => c.current >= c.target).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadowLight,
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Challenges',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '$completed of ${_challenges.length} completed',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            SizedBox(height: 24),
            ..._challenges.map((c) => _challengeCard(c)),
          ],
        ),
      ),
    );
  }

  Widget _challengeCard(_Challenge c) {
    final isComplete = c.current >= c.target;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(c.icon, size: 24, color: c.color),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${c.current} / ${c.target}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.progress,
                    backgroundColor: AppColors.track,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? AppColors.green : c.color,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          if (isComplete) ...[
            SizedBox(width: 10),
            Icon(Icons.check_circle, size: 24, color: AppColors.green),
          ],
        ],
      ),
    );
  }
}

class _Challenge {
  final String title;
  final String subtitle;
  final double progress;
  final int target;
  final int current;
  final IconData icon;
  final Color color;

  _Challenge({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.target,
    required this.current,
    required this.icon,
    required this.color,
  });
}

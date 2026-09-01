import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/achievements_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'achievements_screen.dart';
import 'asha_screen.dart';
import 'challenges_screen.dart';
import 'high_protein_meals_screen.dart';
import 'meal_plan_screen.dart';
import 'nutrition_tips_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final StorageService storage;
  const DiscoverScreen({super.key, required this.storage});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _streak = 0;
  List<Achievement> _achievements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final entries = widget.storage.entries;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Streak
    var day = today;
    if (!entries.any((e) => e.isOn(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (entries.any((e) => e.isOn(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // Achievements
    final svc = AchievementsService(widget.storage);
    final all = svc.getAll();

    setState(() {
      _streak = streak;
      _achievements = all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.unlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        const Text(
          'Discover',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Explore tips, challenges, and meal ideas',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),

        // Asha — AI nutrition assistant (hero card)
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AshaScreen(storage: widget.storage),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 26, color: Colors.white),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Asha',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Your AI nutrition assistant. Knows your goal, '
                        'reads today\'s log, answers in seconds.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Streak + Achievements summary
        Row(
          children: [
            _summaryPill(
              emoji: '🔥',
              value: _streak,
              label: _streak == 1 ? 'day streak' : 'day streak',
              color: AppColors.accentOrange,
            ),
            const SizedBox(width: 10),
            _summaryPill(
              emoji: '🏆',
              value: unlocked,
              label: 'achievements',
              color: AppColors.green,
            ),
          ],
        ),
        const SizedBox(height: 24),

        _navCard(
          context,
          emoji: '🎯',
          title: 'Challenges',
          subtitle: 'Weekly goals based on your progress',
          color: AppColors.accentOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChallengesScreen(storage: widget.storage)),
          ),
        ),
        _navCard(
          context,
          emoji: '🏆',
          title: 'Achievements',
          subtitle: '$unlocked of ${_achievements.length} unlocked',
          color: AppColors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AchievementsScreen(storage: widget.storage)),
          ),
        ),
        _navCard(
          context,
          emoji: '💡',
          title: 'Nutrition Tips',
          subtitle: 'Smart eating advice for Indian food',
          color: AppColors.accentOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NutritionTipsScreen()),
          ),
        ),
        _navCard(
          context,
          emoji: '🥩',
          title: 'High Protein Meals',
          subtitle: 'Indian meals ranked by protein content',
          color: AppColors.protein,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HighProteinMealsScreen()),
          ),
        ),
        _navCard(
          context,
          emoji: '📋',
          title: 'Meal Plans',
          subtitle: 'Pre-built plans for your goals',
          color: AppColors.ink,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MealPlanScreen(storage: widget.storage)),
          ),
        ),
      ],
    );
  }

  Widget _summaryPill({
    required String emoji,
    required int value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

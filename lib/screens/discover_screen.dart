import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../config/features.dart';
import 'package:flutter/services.dart';

import '../services/achievements_service.dart';
import '../services/social_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'achievements_screen.dart';
import 'asha_screen.dart';
import 'challenges_screen.dart';
import 'high_protein_meals_screen.dart';
import 'meal_plan_screen.dart';
import 'nutrition_tips_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final StorageService storage;
  DiscoverScreen({super.key, required this.storage});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _streak = 0;
  List<Achievement> _achievements = [];
  final _friendCtrl = TextEditingController();
  List<({String uid, String name, int kcal})> _leaderboard = [];
  bool _boardLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshLeaderboard();
  }

  @override
  void dispose() {
    _friendCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final entries = widget.storage.entries;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    // Streak
    var day = today;
    if (!entries.any((e) => e.isOn(day))) {
      day = day.subtract(Duration(days: 1));
    }
    int streak = 0;
    while (entries.any((e) => e.isOn(day))) {
      streak++;
      day = day.subtract(Duration(days: 1));
    }

    // Achievements
    final svc = AchievementsService(widget.storage);
    final all = svc.getAll();

    setState(() {
      _streak = streak;
      _achievements = all;
    });
  }

  // ---- Friends / leaderboard ----

  Future<void> _refreshLeaderboard() async {
    setState(() => _boardLoading = true);
    try {
      final board = await SocialService(widget.storage).weeklyLeaderboard();
      if (mounted) setState(() => _leaderboard = board);
    } catch (_) {
      // Keep last known table.
    } finally {
      if (mounted) setState(() => _boardLoading = false);
    }
  }

  Future<void> _addFriendByCode() async {
    final code = _friendCtrl.text.trim();
    if (code.isEmpty) return;
    final svc = SocialService(widget.storage);
    final found = await svc.lookupUser(code);
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with that code.')),
      );
      return;
    }
    if (widget.storage.friends.any((f) => f.uid == found['uid'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already friends with them.')),
      );
      return;
    }
    await widget.storage
        .addFriend(found['uid'] as String, found['name'] as String);
    _friendCtrl.clear();
    setState(() {});
    await _refreshLeaderboard();
  }

  Widget _friendsCard() {
    final svc = SocialService(widget.storage);
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤝', style: TextStyle(fontSize: AppType.bodyStrong)),
              const SizedBox(width: 7),
              Text(
                'Friends',
                style: TextStyle(
                  fontSize: AppType.bodyStrong,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your code: ${svc.myCode?.substring(0, 8) ?? '—'}',
                  style: TextStyle(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final code = svc.myCode ?? '';
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Code copied — share it with a friend'),
                          duration: Duration(seconds: 2)),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendCtrl,
                  style: const TextStyle(fontSize: AppType.body),
                  decoration: InputDecoration(
                    hintText: 'Friend\'s code',
                    hintStyle: TextStyle(
                        fontSize: AppType.body, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _addFriendByCode,
                child: const Text('Add',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_leaderboard.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'This week (kcal logged)',
              style: TextStyle(
                fontSize: AppType.small,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            ..._leaderboard.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final medal =
                  i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '';
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Row(
                  children: [
                    if (medal.isNotEmpty)
                      Text(medal, style: const TextStyle(fontSize: AppType.bodyStrong))
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${row.kcal} kcal',
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? AppColors.green : AppColors.muted,
                      ),
                    ),
                    if (row.uid != svc.myCode)
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 15, color: AppColors.faint),
                        onPressed: () async {
                          await widget.storage.removeFriend(row.uid);
                          setState(() {});
                          await _refreshLeaderboard();
                        },
                      ),
                  ],
                ),
              );
            }),
          ] else if (!_boardLoading) ...[
            const SizedBox(height: 10),
            Text(
              'No friends yet — add a code, or share yours!',
              style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
            ),
          ],
          if (_boardLoading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: AppColors.track,
              color: AppColors.ink,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.unlocked).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        Text(
          'Discover',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Explore tips, challenges, and meal ideas',
          style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
        ),
        SizedBox(height: 20),

        if (Features.asha) ...[
        // Asha — AI nutrition assistant (hero card)
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AshaScreen(storage: widget.storage),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Icon(Icons.auto_awesome,
                      size: 26, color: Colors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Asha',
                        style: TextStyle(
                          fontSize: AppType.title,
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
                          fontSize: AppType.body,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        ],

        // Friends + weekly leaderboard
        _friendsCard(),
        SizedBox(height: 20),

        // Streak + Achievements summary
        Row(
          children: [
            _summaryPill(
              emoji: '🔥',
              value: _streak,
              label: _streak == 1 ? 'day streak' : 'day streak',
              color: AppColors.accentOrange,
            ),
            SizedBox(width: 10),
            _summaryPill(
              emoji: '🏆',
              value: unlocked,
              label: 'achievements',
              color: AppColors.green,
            ),
          ],
        ),
        SizedBox(height: 24),

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
            MaterialPageRoute(builder: (_) => NutritionTipsScreen()),
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
            MaterialPageRoute(builder: (_) => HighProteinMealsScreen()),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: AppType.title,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
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
      padding: EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
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
                  child: Text(emoji, style: TextStyle(fontSize: 24)),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppType.bodyStrong,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
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

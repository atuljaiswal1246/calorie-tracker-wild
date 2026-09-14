import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../services/gamification_controller.dart';
import '../theme/app_colors.dart';
import 'shop_screen.dart';

/// Gamification hub — the level/points/streak dashboard plus today's quests.
/// Reached from the Home quest card ("View all").
class GamificationHubScreen extends StatefulWidget {
  const GamificationHubScreen({super.key});

  @override
  State<GamificationHubScreen> createState() => _GamificationHubScreenState();
}

class _GamificationHubScreenState extends State<GamificationHubScreen> {
  GamificationController? get _gami => GamificationController.instance;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _gami?.revision.addListener(_onChanged);
  }

  @override
  void dispose() {
    _gami?.revision.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gami = _gami;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          'Your progress',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Shop',
            icon: const Text('🛍️', style: TextStyle(fontSize: 18)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
          ),
        ],
      ),
      body: gami == null
          ? Center(
              child: Text(
                'Gamification is off.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _levelCard(gami),
                SizedBox(height: 14),
                _statRow(gami),
                SizedBox(height: 24),
                Text(
                  "Today's quests",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                ...gami.activeQuests.map(_questTile),
                SizedBox(height: 8),
                Text(
                  'Quests reset at midnight. Completing all three pays a bonus.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
    );
  }

  Widget _levelCard(GamificationController gami) {
    return Container(
      padding: EdgeInsets.all(18),
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
              Text('🌱', style: TextStyle(fontSize: 26)),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${gami.level} · ${gami.levelTitle}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    '${gami.calPoints} Cal Points',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: gami.levelProgress,
              minHeight: 8,
              backgroundColor: AppColors.cardAlt,
              valueColor: AlwaysStoppedAnimation(AppColors.ink),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${gami.pointsToNextLevel} points to the next level',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _statRow(GamificationController gami) {
    return Row(
      children: [
        _statChip('🔥', '${gami.streak}', 'streak'),
        SizedBox(width: 8),
        _statChip('⚡', '${gami.weeklyPoints}', 'this week'),
        SizedBox(width: 8),
        _statChip('🪙', '${gami.nutriCoins}', 'coins'),
        SizedBox(width: 8),
        _statChip('❄️', '${gami.freezes}', 'freezes'),
      ],
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: 15)),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _questTile(ActiveQuest q) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: q.completed ? AppColors.green : AppColors.cardAlt,
            ),
            child: Icon(
              q.completed ? Icons.check_rounded : Icons.circle_outlined,
              size: 16,
              color: q.completed ? Colors.white : AppColors.faint,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.template.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: q.completed ? AppColors.muted : AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${q.template.category} · ${q.current}/${q.target}',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                if (!q.completed) ...[
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: q.progress,
                      minHeight: 5,
                      backgroundColor: AppColors.cardAlt,
                      valueColor: AlwaysStoppedAnimation(AppColors.ink),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '+${q.calPoints}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: q.completed ? AppColors.green : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/quest.dart';
import '../services/gamification_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'league_screen.dart';
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
            tooltip: 'League',
            icon: const Icon(Symbols.emoji_events_rounded, size: 20),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LeagueScreen())),
          ),
          IconButton(
            tooltip: 'Shop',
            icon: const Icon(Symbols.shopping_bag_rounded, size: 20),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ShopScreen())),
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
                    fontSize: AppType.bodyStrong,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                ...gami.activeQuests.map(_questTile),
                SizedBox(height: 8),
                Text(
                  'Quests reset at midnight. Completing all three pays a bonus.',
                  style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
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
              Icon(Symbols.eco_rounded,
                  size: 28, color: AppColors.green),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${gami.level} · ${gami.levelTitle}',
                    style: TextStyle(
                      fontSize: AppType.title,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    '${gami.calPoints} Cal Points',
                    style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
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
            style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _statRow(GamificationController gami) {
    return Row(
      children: [
        _statChip(Symbols.local_fire_department_rounded, AppColors.accentOrange,
            '${gami.streak}', 'streak'),
        SizedBox(width: 8),
        _statChip(Symbols.bolt_rounded, AppColors.warningOrange,
            '${gami.weeklyPoints}', 'this week'),
        SizedBox(width: 8),
        _statChip(Symbols.monetization_on_rounded, AppColors.gold,
            '${gami.nutriCoins}', 'coins'),
        SizedBox(width: 8),
        _statChip(Symbols.ac_unit_rounded, AppColors.water,
            '${gami.freezes}', 'freezes'),
      ],
    );
  }

  Widget _statChip(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Label first, then the number — the reading order the rest of the
            // app now uses.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppType.micro,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questTile(ActiveQuest q) {
    return Semantics(
      label:
          '${q.template.title}, ${q.current} of ${q.target}'
          '${q.completed ? ', completed' : ''}, worth ${q.calPoints} Cal Points',
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
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
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w600,
                      color: q.completed ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${q.template.category} · ${q.current}/${q.target}',
                    style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
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
                fontSize: AppType.body,
                fontWeight: FontWeight.w800,
                color: q.completed ? AppColors.green : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

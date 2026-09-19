import 'package:flutter/material.dart';

import '../services/achievements_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AchievementsScreen extends StatefulWidget {
  final StorageService storage;

  AchievementsScreen({super.key, required this.storage});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late AchievementsService _service;
  late List<Achievement> _achievements;

  @override
  void initState() {
    super.initState();
    _service = AchievementsService(widget.storage);
    _achievements = _service.getAll();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.unlocked).length;
    final total = _achievements.length;
    final progress = total > 0 ? unlocked / total : 0.0;

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
                  'Achievements',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.cardShadowLight,
              ),
              child: Column(
                children: [
                  Text(
                    '$unlocked / $total',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'badges unlocked',
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.track,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          unlocked == total ? AppColors.gold : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            ..._categorySections(),
          ],
        ),
      ),
    );
  }

  /// Achievements grouped by category (definition order), each with its own
  /// header and 3-column grid.
  List<Widget> _categorySections() {
    final groups = <String, List<Achievement>>{};
    for (final a in _achievements) {
      groups.putIfAbsent(a.category, () => []).add(a);
    }
    final widgets = <Widget>[];
    groups.forEach((category, items) {
      final done = items.where((a) => a.unlocked).length;
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(
              category,
              style: TextStyle(
                fontSize: AppType.bodyStrong,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Spacer(),
            Text(
              '$done/${items.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ));
      widgets.add(GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // Fixed height instead of an aspect ratio: the tiles overflowed
          // their cells (emoji + 2-line title + 2-line description + progress
          // bar) at common phone widths.
          mainAxisExtent: 142,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _achievementBadge(items[index]),
      ));
      widgets.add(SizedBox(height: 24));
    });
    return widgets;
  }

  Widget _achievementBadge(Achievement achievement) {
    final unlocked = achievement.unlocked;

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.card : AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: unlocked
            ? Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            achievement.emoji,
            style: TextStyle(
              fontSize: AppType.hero,
              color: unlocked ? null : Colors.grey.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 6),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.ink : AppColors.muted.withValues(alpha: 0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: unlocked ? AppColors.muted : AppColors.muted.withValues(alpha: 0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!unlocked && achievement.progress > 0) ...[
            SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 5,
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  backgroundColor: AppColors.track,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.muted.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/achievements_service.dart';
import '../services/storage_service.dart';

class AchievementsScreen extends StatefulWidget {
  final StorageService storage;

  const AchievementsScreen({super.key, required this.storage});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _gold = Color(0xFFFFD60A);

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
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '$unlocked / $total',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'badges unlocked',
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFECECE7),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          unlocked == total ? _gold : _ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Achievement grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                return _achievementBadge(_achievements[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementBadge(Achievement achievement) {
    final unlocked = achievement.unlocked;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: unlocked
            ? Border.all(color: _gold.withOpacity(0.3), width: 2)
            : null,
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: _gold.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
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
              fontSize: 32,
              color: unlocked ? null : Colors.grey.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: unlocked ? _ink : _muted.withOpacity(0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: unlocked ? _muted : _muted.withOpacity(0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!unlocked && achievement.progress > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 5,
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  backgroundColor: const Color(0xFFECECE7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _muted.withOpacity(0.5),
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

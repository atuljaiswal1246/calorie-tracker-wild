import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

import '../services/gamification_controller.dart';
import '../services/health_path_service.dart';
import '../services/lesson_service.dart';
import '../models/health_path.dart';
import '../widgets/path_node_widget.dart';
import '../widgets/path_connector_painter.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/xp_bar.dart';
import '../widgets/streak_badge.dart';
import 'lesson_screen.dart';

class HealthPathScreen extends StatefulWidget {
  const HealthPathScreen({super.key});

  @override
  State<HealthPathScreen> createState() => _HealthPathScreenState();
}

class _HealthPathScreenState extends State<HealthPathScreen> {
  late HealthPathService _pathService;
  final HealthPathState _pathState = HealthPathState();

  @override
  void initState() {
    super.initState();
    _initPathService();
  }

  void _initPathService() {
    final controller = GamificationController.instance!;
    _pathService = HealthPathService(
      controller.state,
      _pathState,
    );
  }

  void _onNodeTap(PathNode node) async {
    final state = _pathService.pathState.getStateFor(
      node.id,
      _pathService.currentNode?.id,
    );
    
    if (state != PathNodeState.current) return;
    
    HapticFeedback.mediumImpact();
    
    final lessons = LessonService.generateLessonsForPath(_pathService.path);
    final lesson = lessons.firstWhere((l) => l.nodeId == node.id);
    
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: lesson,
          node: node,
          onComplete: () {
            _pathService.completeNode(node.id);
            setState(() {});
          },
        ),
      ),
    );
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = GamificationController.instance!;
    final nodesByLevel = _pathService.nodesByLevel;
    final currentNode = _pathService.currentNode;
    
    // Calculate daily goal - complete current node + maybe other actions
    final dailyCompleted = controller.state.todayActions.length.clamp(0, 3);
    const dailyTotal = 3;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with XP, Streak, Daily Goal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  XPBar(
                    currentXP: controller.state.calPoints,
                    onTap: () {},
                  ),
                  Row(
                    children: [
                      DailyGoalRing(
                        completed: dailyCompleted,
                        total: dailyTotal,
                        size: 60,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      StreakBadge(
                        streak: controller.state.streak.current,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Path title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'YOUR HEALTH PATH',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_pathService.completedCount}/${_pathService.totalCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Path content
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: nodesByLevel.keys.length,
                itemBuilder: (context, levelIndex) {
                  final levels = nodesByLevel.keys.toList()..sort();
                  final level = levels[levelIndex];
                  final levelNodes = nodesByLevel[level]!;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Level header
                      Container(
                        margin: EdgeInsets.only(bottom: 24, top: levelIndex == 0 ? 0 : 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'UNIT $level',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      // Nodes in this level
                      ...levelNodes.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final node = entry.value;
                        final state = _pathService.pathState.getStateFor(
                          node.id,
                          currentNode?.id,
                        );
                        final isOffset = idx % 2 == 1;
                        final showConnector = idx < levelNodes.length - 1;
                        
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: isOffset ? 60 : 0,
                                right: isOffset ? 0 : 60,
                              ),
                              child: PathNodeWidget(
                                node: node,
                                state: state,
                                onTap: () => _onNodeTap(node),
                                isOffset: isOffset,
                              ),
                            ),
                            if (showConnector)
                              SizedBox(
                                height: 60,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: PathConnectorPainter(
                                    isCompleted: state == PathNodeState.completed,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

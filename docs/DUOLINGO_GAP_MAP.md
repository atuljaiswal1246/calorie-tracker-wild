# Duolingo Gap Map - Exact Files to Modify/Create

## Current State Analysis

### What exists
- `lib/screens/home_screen.dart` - Current home (bento style)
- `lib/screens/gamification_hub_screen.dart` - Hub with quests/achievements
- `lib/services/gamification_service.dart` - Core engine
- `lib/services/gamification_controller.dart` - Wiring
- `lib/widgets/celebration_overlay.dart` - Celebrations
- `lib/services/quest_service.dart` - Quests
- `lib/services/league_service.dart` - Leagues

### What's missing (Duolingo-like)
- Health Path/Map screen/component
- Path node model
- Daily goal prominent UI
- Path-based home screen
- Enhanced micro-animations
- Path progress persistence

## Files to CREATE

| File | Purpose | Priority |
|---|---|---|
| `lib/models/health_path.dart` | Path nodes, levels, unlock logic | P0 |
| `lib/services/health_path_service.dart` | Generate path, track progress, award on completion | P0 |
| `lib/screens/health_path_screen.dart` | Main path/map screen (Duolingo style) | P0 |
| `lib/widgets/path_node_widget.dart` | Individual node with states (locked/current/completed) | P0 |
| `lib/widgets/path_connector_painter.dart` | Curved connector lines between nodes | P0 |
| `lib/widgets/daily_goal_ring.dart` | Prominent daily goal ring like Duolingo's daily goal | P0 |
| `lib/widgets/xp_bar.dart` | Animated XP bar with level | P0 |
| `lib/widgets/streak_badge.dart` | Animated streak badge | P0 |
| `lib/widgets/animated_reward.dart` | XP/coin fly animation | P1 |
| `lib/widgets/node_unlock_animation.dart` | Celebration on node unlock | P1 |
| `docs/DUOLINGO_IMPLEMENTATION_LOG.md` | Track progress | P0 |

## Files to MODIFY

| File | Changes | Priority |
|---|---|---|
| `lib/screens/home_screen.dart` | Option A: Replace with path-based home. Option B: Add path as primary tab/view. Need to see best fit. | P0 |
| `lib/main.dart` | Wire up HealthPathService, maybe change default route | P0 |
| `lib/services/storage_service.dart` | Persist path progress (nodes completed, current node) | P0 |
| `lib/services/gamification_controller.dart` | Hook path rewards into controller | P1 |
| `lib/config/app_colors.dart` | Add Duolingo-like vibrant colors (greens, yellows, blues) if needed | P1 |
| `pubspec.yaml` | Add packages if needed (flutter_animate, confetti - check if already there) | P1 |

## Design Decisions

### Path Structure
For health app, a logical path could be:
- Level 1: Getting Started (log first meal, set up profile)
- Level 2: Hydration (log water)
- Level 3: Consistency (build streak)
- Level 4: Nutrition Awareness (scan meals)
- Level 5: Movement (log exercise)
- etc. - Progressive difficulty

Or simpler: Daily habit loop - each "lesson" is a habit action.

### Home Integration
Duolingo has path as home. We need to decide:
1. **Replace Home completely** with HealthPathScreen
2. **Make Path the main tab** and keep other tabs
3. **Show Path prominently on current Home**

Looking at current home, it has lots of info. Duolingo-style would be cleaner - focus on path + daily goal.

### Node States
- `locked` - Not yet accessible
- `current` - Next to do (pulsing/animated)
- `completed` - Done, shows checkmark
- `skipped` - Not used, or for flexibility

### Rewards
- Completing node: +XP, maybe coins
- Completing daily goal: Big celebration
- Streak milestone: Special celebration

## Testing Strategy
- Add widget tests for new widgets
- Update goldens if UI changes significantly
- Run `flutter analyze` frequently
- Run relevant tests, not full suite per standing orders

# Duolingo-for-Health: Analysis & Translation Plan

Created: $(date)
Repo: calorie_tracker_wild (parallel copy for experimentation)

## Goal
Make this health app feel like Duolingo - habit-forming, rewarding micro-wins, and make users want to come back tomorrow. We are NOT copying Duolingo's language learning content. We are translating Duolingo's *psychology + UX* to calorie/habit tracking.

## Core Duolingo Loop
1. **Open app** - See a clear path of what's next (or "continue lesson")
2. **Do bite-sized task** (1-3 min) - Complete with minimal friction
3. **Get immediate reward** - XP, progress, sound/haptic, celebration
4. **See momentum** - Streak updated, progress on goal, level progress
5. **Want to return** - "Come back tomorrow for streak" / next node unlocked

## Mechanic Translation Matrix
| Duolingo | Why it works | Cal Matters Translation | Priority | Status |
| --- | --- | --- | --- | --- |
| Skill Tree / Learning Path | Creates journey, reduces choice paralysis, shows "what's next" | Vertical "Health Path" with nodes (Log Meal, Hydrate, Move, Weigh-in). Unlock as you progress. | P0 | Missing |
| XP System | Tangible reward for effort, level progression | Already have Cal Points. Make XP bar prominent, show "+XP" on every log, level up celebrations. | P0 | Partial |
| Streak (with freezes) | Daily commitment, loss aversion | Already have multi-action streak + freezes. Improve UI: flame, calendar, comeback screen, freeze explanation. | P0 | Partial |
| Daily Goal | Achievable target, completion satisfaction | "Daily Quest" ring - complete 3 healthy actions today. Simple > perfect. | P0 | Missing (has quests but not as "daily goal ring") |
| Hearts/Lives | Gentle pressure, prevents burnout | Optional "Energy" system - refills over time. Or use as "mistake forgiveness". Can test later. | P2 | Missing |
| Leagues | Friendly competition, weekly motivation | Already have leagues. Add podium animation, promotion/relegation moments, "You moved up!" celebration. | P1 | Partial |
| Quests/Challenges | Short-term goals beyond daily | Already have quests. Reframe as "Missions", better cards, claim animation, progress bars. | P1 | Partial |
| Achievements/Badges | Collectible, status | Already have achievements. Better showcase, rarity feel, unlock animations. | P1 | Partial |
| Shop/Rewards | Earned rewards feel meaningful | Already have shop. Make coins more visible, highlight "can afford" items, preview. | P1 | Partial |
| Celebrations/Confetti | Dopamine hit on completion | Already have celebration overlay. Use more often (level up, streak milestone, quest complete, path node). | P0 | Partial |
| Micro-animations | Makes app feel alive/responsive | Spring animations on buttons, node unlock scale/bounce, XP fly to bar, card transitions. | P0 | Weak |
| Haptics | Tactile feedback | Use HapticFeedback.light/medium/heavy at key moments (tap, complete, level up). | P0 | Weak |
| Nudges/Reminders | Bring back without guilt | Streak reminder, "Don't break your streak!", comeback nudges. Keep kind. | P1 | Partial |
| Mascot/Personality | Emotional connection | Friendly character that cheers you on, celebrates wins, nudges kindly. Keep original, don't copy Duolingo owl exactly. | P2 | Missing |

## Key UX Principles from Duolingo
- **One clear action** - Home shows ONE thing to do next
- **Bite-sized** - Any action should take < 10 seconds
- **Immediate feedback** - Reward within milliseconds
- **Progress visible** - Always show streak, XP, goal progress
- **Positive reinforcement** - Celebrate wins, be kind on misses
- **Momentum** - Hard to stop after starting (just one more)
- **FOMO without guilt** - Streak creates gentle pull, not shame

## What We Already Have (Strengths)
- Multi-action streak with freeze forgiveness (smart)
- Cal Points system with daily caps & anti-exploit
- Quests with daily generation
- Leagues with promotion/demotion
- Shop with coins
- Achievements system
- Gamification controller wiring everything
- Celebration overlay exists
- Good foundation

## Biggest Gaps to Fill
1. **Health Path/Map UI** - The journey visualization
2. **Daily Goal Ring on Home** - Prominent completion target
3. **Path Node Rewards** - XP/coins on completing path steps
4. **Micro-interaction polish** - Animations, haptics everywhere
5. **Celebration moments** - More frequent, more delightful
6. **"Continue" flow** - Clear next action from home

## Implementation Strategy
- **Keep existing services intact** - Don't break gamification logic
- **Add new UI layer** - New home screen variant or replace home with path-based
- **Use CustomPainter** for curved path (like Duolingo)
- **Leverage existing GamificationController** for rewards
- **Test with goldens** - Use existing test infrastructure
- **Iterate visually** - Mock first, then code

## References to Study
Will clone and study:
- Flutter Duolingo clone implementations
- Custom path/tree UIs in Flutter
- Gamification UI patterns
- Lottie/Rive integration patterns

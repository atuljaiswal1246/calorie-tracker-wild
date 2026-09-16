import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gamification_service.dart';
import '../widgets/celebration_overlay.dart';
import 'gamification_controller.dart';
import 'sound_service.dart';

/// How a reward moment should be presented.
class CelebrationPresentation {
  final String emoji;
  final String title;
  final String subtitle;
  final bool fullScreen;

  const CelebrationPresentation({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.fullScreen,
  });
}

/// Turns queued [CelebrationEvent]s into UI moments (plan §4.8).
///
/// Big moments (level-up, streak milestone) get a full-screen celebration with
/// haptics; everything else is a lightweight toast. All motion respects the
/// OS "reduce motion" setting (plan §3.1 accessibility).
class CelebrationService {
  CelebrationService._();

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static CelebrationPresentation describe(CelebrationEvent event) {
    switch (event.kind) {
      case 'level':
        return CelebrationPresentation(
          emoji: '🌱',
          title: 'Level ${event.amount}!',
          subtitle: GamificationService.titleForLevel(event.amount),
          fullScreen: true,
        );
      case 'milestone':
        return CelebrationPresentation(
          emoji: '🎉',
          title: '${event.amount}-day streak!',
          subtitle: 'Keep the fire alive 🔥',
          fullScreen: true,
        );
      case 'streak':
        return CelebrationPresentation(
          emoji: '🔥',
          title: event.message,
          subtitle: "Log again tomorrow to keep it going",
          fullScreen: false,
        );
      case 'quest':
        return CelebrationPresentation(
          emoji: '📋',
          title: 'Quest complete',
          subtitle: event.message,
          fullScreen: false,
        );
      default:
        return CelebrationPresentation(
          emoji: '✨',
          title: event.message,
          subtitle: 'Cal Points earned',
          fullScreen: false,
        );
    }
  }

  /// Present [event]. Full-screen moments push an overlay; the rest become
  /// floating toasts.
  static void celebrate(BuildContext context, CelebrationEvent event) {
    final p = describe(event);
    if (p.fullScreen) {
      HapticFeedback.heavyImpact();
      SoundService.success();
      CelebrationOverlay.show(
        context,
        emoji: p.emoji,
        title: p.title,
        subtitle: p.subtitle,
      );
      return;
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(
        '${p.emoji} ${p.title}',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating pill-shaped bottom navigation bar.
class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final String avatarInitials;

  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    required this.avatarInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              index: 1,
              icon: Icons.bar_chart_rounded,
              label: 'Progress',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onCenterTap,
              child: Semantics(
                label: 'Scan',
                button: true,
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.center_focus_strong,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _NavItem(
              index: 2,
              icon: Icons.explore,
              label: 'Discover',
              active: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavAvatar(
              index: 3,
              active: currentIndex == 3,
              initials: avatarInitials,
              onTap: () => onTap(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: label,
        selected: active,
        button: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.cardHover : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? AppColors.ink : AppColors.faint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.ink : AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavAvatar extends StatelessWidget {
  final int index;
  final bool active;
  final String initials;
  final VoidCallback onTap;

  const _NavAvatar({
    required this.index,
    required this.active,
    required this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Profile',
        selected: active,
        button: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chipBlue,
                shape: BoxShape.circle,
                border:
                    active ? Border.all(color: AppColors.ink, width: 1.6) : null,
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.ink : AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

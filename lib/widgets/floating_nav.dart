import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Floating pill-shaped bottom navigation bar.
class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final String avatarInitials;
  final String? avatarPhotoPath;

  FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    required this.avatarInitials,
    this.avatarPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: EdgeInsets.symmetric(horizontal: AppSpace.xs),
      padding: EdgeInsets.symmetric(horizontal: 10),
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
                    decoration: BoxDecoration(
                      color: AppColors.inkButton,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
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
            child: _NavAvatar(
              index: 2,
              active: currentIndex == 2,
              initials: avatarInitials,
              photoPath: avatarPhotoPath,
              onTap: () => onTap(2),
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

  _NavItem({
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
              padding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 5),
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
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: AppType.micro,
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
  final String? photoPath;
  final VoidCallback onTap;

  _NavAvatar({
    required this.index,
    required this.active,
    required this.initials,
    required this.onTap,
    this.photoPath,
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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardSelected,
                shape: BoxShape.circle,
                border:
                    active ? Border.all(color: AppColors.ink, width: 1.6) : null,
              ),
              child: photoPath != null && File(photoPath!).existsSync()
                  ? Image.file(
                      File(photoPath!),
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    )
                  : Text(
                      initials,
                      style: TextStyle(
                        fontSize: AppType.small,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
            ),
            SizedBox(height: 2),
            Text(
              'Profile',
              style: TextStyle(
                fontSize: AppType.micro,
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

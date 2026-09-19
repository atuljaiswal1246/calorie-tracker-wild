import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import 'pricing_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Dedicated Settings screen: reminders (proper switches), data export,
/// account actions (reset goals, sign out) and app info. Pulled out of the
/// Profile page so that page stays scannable.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onResetGoals;
  final VoidCallback onSignOut;

  SettingsScreen({
    super.key,
    required this.storage,
    required this.onResetGoals,
    required this.onSignOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _water = true;
  bool _meal = false;
  bool _dark = false;
  bool _sounds = true;

  @override
  void initState() {
    super.initState();
    _water = widget.storage.remindersEnabled;
    _meal = widget.storage.mealRemindersEnabled;
    _dark = AppColors.dark;
    _sounds = widget.storage.soundsEnabled;
  }

  Future<void> _toggleDark(bool enabled) async {
    HapticFeedback.selectionClick();
    setState(() => _dark = enabled);
    AppColors.darkNotifier.value = enabled;
    await widget.storage.saveDarkMode(enabled);
  }

  /// Fires a real notification immediately so the chime can be heard without
  /// waiting for a scheduled slot.
  Future<void> _testNotificationSound() async {
    HapticFeedback.selectionClick();
    await NotificationService.requestPermissions();
    await NotificationService.showNow(
      title: 'Cal Matters',
      body: 'This is how a reminder will sound.',
      id: 9100,
    );
  }

  Future<void> _toggleSounds(bool on) async {
    HapticFeedback.selectionClick();
    setState(() => _sounds = on);
    await widget.storage.setSoundsEnabled(on);
    // Play it once so the choice is audible, not just a label.
    if (on) SoundService.pip();
  }

  Future<void> _toggleWater(bool enabled) async {
    HapticFeedback.selectionClick();
    if (!enabled) {
      await NotificationService.requestPermissions();
    }
    setState(() => _water = enabled);
    await widget.storage.saveRemindersEnabled(enabled);
    if (!enabled) {
      await NotificationService.cancelAll();
    } else {
      await NotificationService.scheduleAll(
        water: true,
        meal: widget.storage.mealRemindersEnabled,
      );
    }
    await _resync();
  }

  Future<void> _toggleMeal(bool enabled) async {
    HapticFeedback.selectionClick();
    if (!enabled) {
      await NotificationService.requestPermissions();
    }
    setState(() => _meal = enabled);
    await widget.storage.saveMealRemindersEnabled(enabled);
    await _resync();
  }

  Future<void> _resync() async {
    await NotificationService.resync(
      water: widget.storage.remindersEnabled,
      meal: widget.storage.mealRemindersEnabled,
    );
  }

  Future<void> _exportData() async {
    final data = widget.storage.exportJson();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/cal_matters_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(data);
    if (file.existsSync()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    }
  }

  Future<void> _confirmResetGoals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset goals?'),
        content: Text(
          'This clears your profile and takes you back to the '
          'questionnaire to set new goals.\n\n'
          'Your meal logs, water, weight and fasting history are kept. '
          'Payment and trial status are NOT affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onResetGoals();
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?'),
        content: Text('Your data stays on this device and in your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out', style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: AppType.headline,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 40),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // ------- Reminders -------
                  _SectionLabel('Reminders'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        _SwitchRow(
                          icon: Icons.water_drop_outlined,
                          iconColor: AppColors.chipBlue,
                          label: 'Water reminders',
                          subtitle: _water
                              ? '6 daily nudges between 9 AM and 10 PM'
                              : 'Off',
                          value: _water,
                          onChanged: _toggleWater,
                        ),
                        Divider(height: 1, color: AppColors.divider),
                        _SwitchRow(
                          icon: Icons.restaurant_outlined,
                          iconColor: AppColors.protein,
                          label: 'Meal reminders',
                          subtitle: _meal
                              ? 'Prompts at lunch, dinner & evening'
                              : 'Off',
                          value: _meal,
                          onChanged: _toggleMeal,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // ------- Appearance -------
                  _SectionLabel('Appearance'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: _SwitchRow(
                      icon: Icons.dark_mode_outlined,
                      iconColor: AppColors.muted,
                      label: 'Dark mode',
                      subtitle: _dark
                          ? 'Easy on the eyes at night'
                          : 'Off',
                      value: _dark,
                      onChanged: _toggleDark,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: _SwitchRow(
                      icon: Icons.volume_up_outlined,
                      iconColor: AppColors.accentOrange,
                      label: 'Sounds',
                      subtitle: _sounds
                          ? 'A small sound when you log'
                          : 'Off',
                      value: _sounds,
                      onChanged: _toggleSounds,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: _TapRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: AppColors.accentOrange,
                      label: 'Test notification sound',
                      subtitle: 'Hear the reminder chime now',
                      onTap: _testNotificationSound,
                    ),
                  ),
                  SizedBox(height: 20),

                  // ------- Data -------
                  _SectionLabel('Data'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: _TapRow(
                      icon: Icons.ios_share_outlined,
                      iconColor: AppColors.green,
                      label: 'Export data',
                      subtitle: 'Share your logs as a JSON file',
                      onTap: _exportData,
                    ),
                  ),
                  SizedBox(height: 20),

                  // ------- Developer (debug/profile builds only) -------
                  if (!kReleaseMode) ...[
                    _SectionLabel('Developer'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: _TapRow(
                        icon: Icons.credit_card,
                        iconColor: AppColors.carbs,
                        label: 'Preview payment screen',
                        subtitle: 'Open the paywall without signing up',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PricingScreen(
                              storage: widget.storage,
                              onPaid: () => Navigator.of(context).pop(),
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  // ------- Account -------
                  _SectionLabel('Account'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        _TapRow(
                          icon: Icons.restart_alt,
                          iconColor: AppColors.muted,
                          label: 'Reset goals',
                          subtitle: 'Re-answer the questionnaire',
                          onTap: _confirmResetGoals,
                        ),
                        Divider(height: 1, color: AppColors.divider),
                        _TapRow(
                          icon: Icons.logout,
                          iconColor: AppColors.missedRed,
                          label: 'Sign out',
                          subtitle: 'This device only',
                          onTap: _confirmSignOut,
                          labelColor: AppColors.missedRed,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Cal Matters v0.9.6',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Cal Matters tracks food and activity. It is not medical '
                      'advice — talk to a doctor or dietitian before changing '
                      'your diet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.muted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppSpace.xs, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppType.body,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        children: [
          _RowIcon(icon: icon, color: iconColor),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 14, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppType.bodyStrong,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.ink,
            activeTrackColor: AppColors.ink.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Color? labelColor;
  final VoidCallback onTap;

  _TapRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Row(
          children: [
            _RowIcon(icon: icon, color: iconColor),
            SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 14, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppType.bodyStrong,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: labelColor ?? AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  _RowIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'sound_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzInit = false;

  static Future<void> init() async {
    if (!_tzInit) {
      try {
        tz_data.initializeTimeZones();
        _tzInit = true;
      } catch (_) {
        // Timezone data unavailable — reminders simply won't be scheduled.
        return;
      }
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    // Never let a notifications-plugin failure take down the app.
    try {
      await _plugin.initialize(settings: settings);
    } catch (_) {}
  }

  static Future<void> requestPermissions() async {
    try {
      await _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Water nudges across the day (approx times, staggered).
  static const waterTimes = [
    (9, 0),
    (11, 30),
    (14, 0),
    (16, 30),
    (19, 0),
    (21, 30),
  ];

  /// Schedule configured reminders: N water nudges + meal logging prompts.
  static Future<void> scheduleAll({bool water = true, bool meal = true}) async {
    try {
      await _scheduleAll(water: water, meal: meal);
    } catch (_) {}
  }

  static Future<void> _scheduleAll({
    required bool water,
    required bool meal,
  }) async {
    await _plugin.cancelAll();

    if (water) {
      var id = 1000;
      for (final (hour, minute) in waterTimes) {
        await _scheduleDaily(
          id: id++,
          hour: hour,
          minute: minute,
          title: '💧 Hydration reminder',
          body: 'Time for a glass of water — stay on track!',
        );
      }
    }

    if (meal) {
      // Meal-time prompts (log what you ate).
      await _scheduleDaily(
        id: 2001,
        hour: 12,
        minute: 30,
        title: '🍽️ Lunch time',
        body: 'Have you logged your lunch yet?',
      );
      await _scheduleDaily(
        id: 2002,
        hour: 19,
        minute: 30,
        title: '🍽️ Dinner time',
        body: 'Log your dinner when you\'re done eating.',
      );
      // Evening nudge — one last chance before the day resets.
      await _scheduleDaily(
        id: 2003,
        hour: 21,
        minute: 45,
        title: '🌙 Almost done for today',
        body: 'Quick nudge: did you log everything you ate today?',
      );
    }
  }

  /// Schedule a single one-off nudge for the notification engine, timed around
  /// the user's learned session hour and clamped out of silent hours.
  static Future<void> scheduleEngineNudge({
    required int preferredHour,
    required String title,
    required String body,
    int id = 9000,
  }) async {
    var hour = preferredHour >= 0 ? preferredHour - 1 : 9;
    if (hour < 8) hour = 8;
    if (hour >= 21) hour = 20;
    try {
      await _scheduleOnce(
        id: id,
        hour: hour,
        minute: 0,
        title: title,
        body: body,
      );
    } catch (_) {}
  }

  /// Show a notification immediately.
  static Future<void> showNow({
    required String title,
    required String body,
    int id = 9001,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_chime',
        'Reminders',
        channelDescription: 'App reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('cal_notify'),
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        sound: SoundService.notificationSoundName,
      ),
    );
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  static Future<void> _scheduleOnce({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_chime',
        'Reminders',
        channelDescription: 'App reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('cal_notify'),
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        sound: SoundService.notificationSoundName,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Re-schedule with the current water+meal settings (after a change).
  static Future<void> resync({required bool water, required bool meal}) =>
      scheduleAll(water: water, meal: meal);

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_chime',
        'Reminders',
        channelDescription: 'App reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('cal_notify'),
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        sound: SoundService.notificationSoundName,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

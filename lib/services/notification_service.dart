import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzInit = false;

  static Future<void> init() async {
    if (!_tzInit) {
      tz_data.initializeTimeZones();
      _tzInit = true;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings: settings);
  }

  static Future<void> requestPermissions() async {
    await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
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

  static Future<void> cancelAll() => _plugin.cancelAll();

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
        'reminders',
        'Reminders',
        channelDescription: 'App reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
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
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

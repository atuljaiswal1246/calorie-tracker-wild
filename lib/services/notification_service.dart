import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
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

  static Future<void> scheduleWaterReminder() async {
    await _cancel(1001);
    await _scheduleDaily(
      id: 1001,
      title: '💧 Hydration reminder',
      body: 'Have a glass of water — you got this!',
    );
  }

  static Future<void> scheduleMealReminder() async {
    await _cancel(1002);
    await _scheduleDaily(
      id: 1002,
      title: '🍽️ Meal time',
      body: 'Don\'t forget to log your next meal!',
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> _cancel(int id) => _plugin.cancel(id: id);

  static Future<void> _scheduleDaily({
    required int id,
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
    await _plugin.periodicallyShowWithDuration(
      id: id,
      title: title,
      body: body,
      repeatDurationInterval: const Duration(days: 1),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

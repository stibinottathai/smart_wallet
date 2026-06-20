import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _noonId = 1001;
  static const _nightId = 1002;
  static const _channelId = 'reminder_channel';
  static const _channelName = 'Reminders';

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Daily transaction reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> scheduleReminders() async {
    await initialize();
    await _cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final noon = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12, 0);
    final night = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);

    final noonSchedule = noon.isBefore(now) ? noon.add(const Duration(days: 1)) : noon;
    final nightSchedule = night.isBefore(now) ? night.add(const Duration(days: 1)) : night;

    await _plugin.zonedSchedule(
      _noonId,
      'Record your expenses',
      'Don\'t forget to log your midday spending',
      noonSchedule,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          icon: '@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      _nightId,
      'Review your day',
      'Log any remaining expenses before bedtime',
      nightSchedule,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          icon: '@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminders() async {
    await _cancelAll();
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      9999,
      'Test Reminder',
      'This is a test notification. Reminders are working correctly!',
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          icon: '@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _cancelAll() async {
    await _plugin.cancel(_noonId);
    await _plugin.cancel(_nightId);
  }
}

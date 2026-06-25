import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _reminderChannelId = 'reminder_channel';
  static const _reminderChannelName = 'Reminders';
  static const _budgetChannelId = 'budget_alert_channel';
  static const _budgetChannelName = 'Budget Alerts';

  // Reserved notification id ranges so we can cancel/reschedule cleanly.
  // Daily reminders: rolling window of [_reminderDays] days × 2 slots.
  static const _reminderBaseId = 1100; // 1100..1127
  static const _reminderDays = 14;
  static const _reminderHours = [12, 20]; // noon & 8 PM
  // Budget alerts: 4 fixed slots per day.
  static const _budgetBaseId = 1200; // 1200..1203
  static const _budgetHours = [9, 13, 17, 21]; // 9AM, 1PM, 5PM, 9PM
  static const _testId = 9999;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      // Required for reliable, on-time delivery on Android 12+ (otherwise
      // alarms are batched by Doze and may be delayed for hours or skipped).
      await androidPlugin.requestExactAlarmsPermission();
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: 'Daily transaction reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _budgetChannelId,
          _budgetChannelName,
          description: 'Alerts when category spending nears its monthly limit',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// (Re)schedules the daily "log your expenses" reminders for the next
  /// [_reminderDays] days at noon and 8 PM. When [loggedToday] is true, today's
  /// remaining slots are skipped so the user isn't nagged after they've already
  /// recorded an expense for the day.
  ///
  /// A rolling window of explicit one-shot alarms is used (rather than a single
  /// repeating alarm) so that "skip today once logged" is possible and so the
  /// schedule is refreshed every time the app is opened.
  Future<void> scheduleDailyReminders({bool loggedToday = false}) async {
    await initialize();
    await cancelDailyReminders();

    final now = tz.TZDateTime.now(tz.local);

    for (var day = 0; day < _reminderDays; day++) {
      if (day == 0 && loggedToday) continue;
      final date = now.add(Duration(days: day));
      for (var slot = 0; slot < _reminderHours.length; slot++) {
        final hour = _reminderHours[slot];
        final fire =
            tz.TZDateTime(tz.local, date.year, date.month, date.day, hour);
        if (!fire.isAfter(now)) continue;
        final isNoon = hour == 12;
        await _plugin.zonedSchedule(
          _reminderBaseId + day * _reminderHours.length + slot,
          isNoon ? 'Record your expenses' : 'Review your day',
          isNoon
              ? "Don't forget to log today's spending in Smart Wallet."
              : 'Log any remaining expenses before bedtime.',
          fire,
          _details(_reminderChannelId, _reminderChannelName),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelDailyReminders() async {
    final last = _reminderBaseId + _reminderDays * _reminderHours.length;
    for (var id = _reminderBaseId; id < last; id++) {
      await _plugin.cancel(id);
    }
  }

  /// (Re)schedules up to 4 daily budget-limit alerts (9 AM, 1 PM, 5 PM, 9 PM)
  /// that repeat every day. Pass null [title]/[body] (i.e. no at-risk
  /// categories) to clear them.
  ///
  /// The message is evaluated at schedule time, so callers should re-invoke this
  /// whenever spending changes (e.g. on app launch and after each expense edit).
  Future<void> scheduleBudgetAlerts({String? title, String? body}) async {
    await initialize();
    await cancelBudgetAlerts();
    if (title == null || body == null) return;

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _budgetHours.length; i++) {
      final hour = _budgetHours[i];
      var fire = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
      if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _budgetBaseId + i,
        title,
        body,
        fire,
        _details(_budgetChannelId, _budgetChannelName),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
  }

  Future<void> cancelBudgetAlerts() async {
    for (var i = 0; i < _budgetHours.length; i++) {
      await _plugin.cancel(_budgetBaseId + i);
    }
  }

  /// Backwards-compatible alias kept for existing callers.
  Future<void> scheduleReminders() => scheduleDailyReminders();

  Future<void> cancelReminders() => cancelDailyReminders();

  Future<void> cancelAll() async {
    await cancelDailyReminders();
    await cancelBudgetAlerts();
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      _testId,
      'Test Reminder',
      'This is a test notification. Reminders are working correctly!',
      _details(_reminderChannelId, _reminderChannelName),
    );
  }
}

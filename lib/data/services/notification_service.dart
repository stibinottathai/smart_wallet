import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
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
  static const _tipChannelId = 'daily_tip_channel';
  static const _tipChannelName = 'Daily Insights';

  // Reserved notification id ranges so we can cancel/reschedule cleanly.
  // Daily reminders: rolling window of [_reminderDays] days × 2 slots.
  static const _reminderBaseId = 1100; // 1100..1127
  static const _reminderDays = 14;
  static const _reminderHours = [12, 20]; // noon & 8 PM
  // Budget alerts: 4 fixed slots per day.
  static const _budgetBaseId = 1200; // 1200..1203
  static const _budgetHours = [9, 13, 17, 21]; // 9AM, 1PM, 5PM, 9PM
  // Daily insight / savings tip: one repeating notification each day.
  static const _tipBaseId = 1300;
  static const _tipHour = 18; // 6:40 PM daily
  static const _tipMinute = 40;
  static const _testId = 9999;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    // Bind tz.local to the device's actual timezone. Without this it defaults to
    // UTC, which makes every scheduled notification (reminders, budget alerts,
    // daily insight) fire at the wrong wall-clock time — i.e. appear broken.
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Fall back to UTC if the platform can't report a timezone; better than
      // crashing during init.
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_launcher_foreground');
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
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _tipChannelId,
          _tipChannelName,
          description: 'A daily summary of your finances and a savings tip',
          importance: Importance.defaultImportance,
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
          // Status-bar (small) icon: Android draws this using only the alpha
          // channel, so it must be a transparent silhouette — the colored
          // launcher icon would render as a blank white square. The adaptive
          // foreground (logo on transparent) renders correctly as the app's
          // white silhouette.
          icon: '@drawable/ic_launcher_foreground',
          // Large icon shown in the notification body — full-colour app icon.
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Schedules a zoned notification, choosing an alarm mode that won't silently
  /// fail.
  ///
  /// On Android 12+ an *exact* alarm requires the SCHEDULE_EXACT_ALARM
  /// permission; if it isn't granted, [zonedSchedule] with an exact mode throws
  /// and the notification is never registered — which is why the instant "Test"
  /// works but nothing fires automatically. We use exact only when the OS
  /// reports it as allowed, and otherwise fall back to an inexact (still
  /// while-idle) alarm so the notification always gets scheduled; it may just
  /// fire a few minutes late.
  Future<void> _zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime fire,
    NotificationDetails details, {
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? true;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        fire,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (_) {
      // Some OEM ROMs report exact alarms as allowed but still reject them.
      // Retry once with an inexact alarm so scheduling never fails outright.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        fire,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  /// (Re)schedules the daily "log your expenses" reminders at noon and 8 PM as
  /// truly repeating alarms, so they fire every day indefinitely — even if the
  /// app is never reopened (and they survive a reboot via the boot receiver).
  ///
  /// [loggedToday] is accepted for backwards-compatibility but no longer skips
  /// today's reminder: a repeating alarm can't drop a single occurrence, and a
  /// guaranteed daily nudge is more useful than one that silently stops after a
  /// couple of weeks.
  Future<void> scheduleDailyReminders({bool loggedToday = false}) async {
    await initialize();
    await cancelDailyReminders();

    final now = tz.TZDateTime.now(tz.local);
    for (var slot = 0; slot < _reminderHours.length; slot++) {
      final hour = _reminderHours[slot];
      var fire = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
      if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
      final isNoon = hour == 12;
      await _zonedSchedule(
        _reminderBaseId + slot,
        isNoon ? 'Record your expenses' : 'Review your day',
        isNoon
            ? "Don't forget to log today's spending in Smart Wallet."
            : 'Log any remaining expenses before bedtime.',
        fire,
        _details(_reminderChannelId, _reminderChannelName),
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily forever
      );
    }
  }

  Future<void> cancelDailyReminders() async {
    // Cancel the 2 current repeating reminders, plus the full id range used by
    // the previous rolling-window implementation, so one-shots scheduled by
    // older app versions don't keep firing after this update.
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
      await _zonedSchedule(
        _budgetBaseId + i,
        title,
        body,
        fire,
        _details(_budgetChannelId, _budgetChannelName),
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
  }

  Future<void> cancelBudgetAlerts() async {
    for (var i = 0; i < _budgetHours.length; i++) {
      await _plugin.cancel(_budgetBaseId + i);
    }
  }

  /// (Re)schedules a single daily insight notification at [_tipHour]:[_tipMinute]
  /// that repeats every day, carrying a status summary + savings tip derived
  /// from the user's data. Pass null [title]/[body] to clear it.
  ///
  /// The message is computed at schedule time, so callers should re-invoke this
  /// whenever data changes (e.g. on app launch and after each edit) to keep the
  /// tip fresh.
  Future<void> scheduleDailyDigest({String? title, String? body}) async {
    await initialize();
    await cancelDailyDigest();
    if (title == null || body == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var fire = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, _tipHour, _tipMinute);
    if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
    await _zonedSchedule(
      _tipBaseId,
      title,
      body,
      fire,
      _details(_tipChannelId, _tipChannelName),
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  Future<void> cancelDailyDigest() async {
    await _plugin.cancel(_tipBaseId);
  }

  /// Backwards-compatible alias kept for existing callers.
  Future<void> scheduleReminders() => scheduleDailyReminders();

  Future<void> cancelReminders() => cancelDailyReminders();

  Future<void> cancelAll() async {
    await cancelDailyReminders();
    await cancelBudgetAlerts();
    await cancelDailyDigest();
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

  /// Immediately shows a sample budget alert so the user can confirm the channel
  /// works, independent of whether any category is currently over its limit.
  Future<void> showTestBudgetAlert() async {
    await initialize();
    await _plugin.show(
      _testId,
      '⚠️ Budget Alert (test)',
      'This is a test alert. Budget notifications are working correctly!',
      _details(_budgetChannelId, _budgetChannelName),
    );
  }

  /// Immediately shows a sample daily insight so the user can confirm the
  /// channel works without waiting for the scheduled 8 AM delivery.
  Future<void> showTestDailyInsight() async {
    await initialize();
    await _plugin.show(
      _testId,
      'Daily Insight (test)',
      'This is a test insight. Daily insights are working correctly!',
      _details(_tipChannelId, _tipChannelName),
    );
  }

  /// Asks the OS for everything required for *background* delivery to be
  /// reliable: notification permission, exact-alarm permission (Android 12+),
  /// and — crucially on aggressive OEMs (Xiaomi, Samsung, Oppo, Vivo …) — an
  /// exemption from battery optimization, which is the usual reason scheduled
  /// alarms never fire once the app is swiped away.
  ///
  /// Returns true if battery-optimization is (now) disabled for the app.
  Future<bool> requestBackgroundDeliveryPermissions() async {
    await initialize();

    // Notifications (Android 13+ / iOS).
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Exact alarms (Android 12+). Opens the system screen if not yet allowed.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? true;
    if (!canExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }

    // Battery optimization exemption — the big one for "fires when closed".
    if (await Permission.ignoreBatteryOptimizations.isGranted) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// True if the app is exempt from battery optimization. Used by the UI to show
  /// whether background delivery is in a healthy state.
  Future<bool> isBatteryOptimizationDisabled() async {
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Schedules a real (not instant) notification [delay] from now via the exact
  /// same alarm pipeline the daily features use. Let the user close the app and
  /// confirm it still fires — proving background delivery end-to-end and
  /// isolating device battery-killing from app bugs.
  Future<void> scheduleSelfTest(
      {Duration delay = const Duration(minutes: 1)}) async {
    await initialize();
    final fire = tz.TZDateTime.now(tz.local).add(delay);
    await _zonedSchedule(
      _testId,
      'Scheduled test ⏰',
      'If you see this with the app closed, background notifications work!',
      fire,
      _details(_reminderChannelId, _reminderChannelName),
    );
  }

  /// Schedules a notification on the daily-insight channel [delay] from now with
  /// the real computed [title]/[body], so the user can verify the *actual* daily
  /// insight path (not just a generic test) without waiting for 6:40 PM.
  Future<void> scheduleTipSelfTest({
    required String title,
    required String body,
    Duration delay = const Duration(minutes: 1),
  }) async {
    await initialize();
    final fire = tz.TZDateTime.now(tz.local).add(delay);
    await _zonedSchedule(
      _testId,
      title,
      body,
      fire,
      _details(_tipChannelId, _tipChannelName),
    );
  }

  /// Schedules a real reminder on the reminder channel [delay] from now, so the
  /// user can verify the reminder path end-to-end with the app closed.
  Future<void> scheduleReminderSelfTest({
    Duration delay = const Duration(minutes: 1),
  }) async {
    await initialize();
    final fire = tz.TZDateTime.now(tz.local).add(delay);
    await _zonedSchedule(
      _testId,
      'Record your expenses',
      "Don't forget to log today's spending in Smart Wallet.",
      fire,
      _details(_reminderChannelId, _reminderChannelName),
    );
  }

  /// Schedules a real budget alert on the budget channel [delay] from now with
  /// the given [title]/[body], so the user can verify the budget-alert path.
  Future<void> scheduleBudgetSelfTest({
    required String title,
    required String body,
    Duration delay = const Duration(minutes: 1),
  }) async {
    await initialize();
    final fire = tz.TZDateTime.now(tz.local).add(delay);
    await _zonedSchedule(
      _testId,
      title,
      body,
      fire,
      _details(_budgetChannelId, _budgetChannelName),
    );
  }

  /// Number of notifications currently registered with the OS. A quick way to
  /// confirm scheduling actually happened (should be > 0 when features are on).
  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }
}

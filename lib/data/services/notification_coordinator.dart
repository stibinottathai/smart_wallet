import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/models.dart';
import 'notification_service.dart';

/// Central place that decides what notifications should currently be scheduled,
/// based on the latest data and the user's preferences. Safe to call often
/// (e.g. on every app launch and whenever expenses or categories change) — it
/// always cancels and re-schedules to reflect the current state.
class NotificationCoordinator {
  static const remindersPrefKey = 'reminders_enabled';
  static const budgetAlertsPrefKey = 'budget_alerts_enabled';
  static const dailyTipPrefKey = 'daily_tip_enabled';

  /// Fires a budget alert once a category has used at least this fraction of its
  /// monthly limit (i.e. is within 20% of, or over, the limit).
  static const _budgetThreshold = 0.8;

  static Future<void> sync({
    required List<Expense> expenses,
    required List<Category> categories,
    required String currencySymbol,
    List<Income> incomes = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool(remindersPrefKey) ?? true;
    final budgetAlertsEnabled = prefs.getBool(budgetAlertsPrefKey) ?? true;
    final dailyTipEnabled = prefs.getBool(dailyTipPrefKey) ?? true;

    final service = NotificationService();

    // ── Daily "log your expenses" reminders ──────────────────────────────
    if (remindersEnabled) {
      final now = DateTime.now();
      final loggedToday = expenses.any((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day);
      await service.scheduleDailyReminders(loggedToday: loggedToday);
    } else {
      await service.cancelDailyReminders();
    }

    // ── Monthly budget-limit alerts ──────────────────────────────────────
    if (budgetAlertsEnabled) {
      final alert = _buildBudgetAlert(expenses, categories);
      await service.scheduleBudgetAlerts(title: alert?.title, body: alert?.body);
    } else {
      await service.cancelBudgetAlerts();
    }

    // ── Daily insight / savings tip ──────────────────────────────────────
    if (dailyTipEnabled) {
      final tip = _buildDailyTip(
        expenses: expenses,
        incomes: incomes,
        categories: categories,
        currencySymbol: currencySymbol,
      );
      await service.scheduleDailyDigest(title: tip.title, body: tip.body);
    } else {
      await service.cancelDailyDigest();
    }
  }

  /// Public preview of the current daily insight (title + body), built from the
  /// same logic used for the scheduled notification. Used by the Settings
  /// "test in 1 minute" action to exercise the real path.
  static ({String title, String body}) dailyTipPreview({
    required List<Expense> expenses,
    required List<Income> incomes,
    required List<Category> categories,
    required String currencySymbol,
  }) {
    final tip = _buildDailyTip(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      currencySymbol: currencySymbol,
    );
    return (title: tip.title, body: tip.body);
  }

  /// Public preview of the current budget alert (title + body). Falls back to a
  /// sample when no category is near its limit, so the Settings "test in 1
  /// minute" action always has something to deliver.
  static ({String title, String body}) budgetAlertPreview(
    List<Expense> expenses,
    List<Category> categories,
  ) {
    final alert = _buildBudgetAlert(expenses, categories);
    if (alert != null) return (title: alert.title, body: alert.body);
    return (
      title: '⚠️ Budget Alert (sample)',
      body: 'No category is near its limit yet — this is a sample alert so you '
          'can confirm budget notifications are delivered.',
    );
  }

  /// Analyses the user's current-month finances and produces a single,
  /// personalised status + savings tip to deliver once a day. Runs entirely on
  /// local data so it works offline and is safe to schedule ahead of time.
  static _DailyTip _buildDailyTip({
    required List<Expense> expenses,
    required List<Income> incomes,
    required List<Category> categories,
    required String currencySymbol,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    String money(num v) => '$currencySymbol${v.round()}';

    // No data yet — nudge the user to start tracking.
    if (expenses.isEmpty && incomes.isEmpty) {
      return const _DailyTip(
        'Start your savings journey',
        'Add your income and a few expenses so Smart Wallet can tailor a daily '
            'savings tip just for you.',
      );
    }

    // Current-month totals + per-category spend.
    var monthIncome = 0.0;
    var monthExpense = 0.0;
    final spendByCat = <String, double>{};
    for (final i in incomes) {
      if (!i.date.isBefore(monthStart)) monthIncome += i.amount;
    }
    for (final e in expenses) {
      if (!e.date.isBefore(monthStart)) {
        monthExpense += e.amount;
        spendByCat[e.categoryId] = (spendByCat[e.categoryId] ?? 0) + e.amount;
      }
    }

    // No-spend streak, counting back from today (today's spend resets it).
    final expenseDays = expenses
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
    var streak = 0;
    var day = today;
    while (!expenseDays.contains(day) && streak < 30) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // 1. Celebrate a no-spend streak first — positive reinforcement.
    if (streak >= 3) {
      return _DailyTip(
        '$streak-day no-spend streak 🎉',
        "You haven't logged an expense in $streak days. Move what you'd "
            'normally spend into a savings goal to lock in the win.',
      );
    }

    // 2. Savings-rate based status when income is known for the month.
    if (monthIncome > 0) {
      final saved = monthIncome - monthExpense;
      final rate = (saved / monthIncome * 100).round();
      if (saved < 0) {
        return _DailyTip(
          'Spending is ahead of income',
          'This month you have spent ${money(monthExpense)} against '
              '${money(monthIncome)} income. Trimming your top category could '
              'bring you back into balance.',
        );
      }
      if (rate >= 20) {
        return _DailyTip(
          "You're saving well this month",
          'You have kept ${money(saved)} (about $rate%) of your '
              '${money(monthIncome)} income. Consider parking it in a savings '
              'goal before it gets spent.',
        );
      }
      return _DailyTip(
        'Your money this month',
        'Saved ${money(saved)} of ${money(monthIncome)} income so far '
            '($rate%). Small cuts to your biggest category can lift that rate.',
      );
    }

    // 3. Highlight the top spending category and an easy 10% saving.
    if (spendByCat.isNotEmpty) {
      final catNames = {for (final c in categories) c.id: c.name};
      final top =
          spendByCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final name = catNames[top.key] ?? 'your top category';
      return _DailyTip(
        'Where your money is going',
        '$name is your biggest spend at ${money(top.value)} this month. '
            'Cutting it by 10% would save about ${money(top.value * 0.1)}.',
      );
    }

    // 4. Fallback status summary.
    return _DailyTip(
      'Your money, at a glance',
      '${money(monthExpense)} spent so far this month. Open Smart Wallet to '
          'review and spot easy savings.',
    );
  }

  static _BudgetAlert? _buildBudgetAlert(
    List<Expense> expenses,
    List<Category> categories,
  ) {
    final now = DateTime.now();

    // Current-month spend per category.
    final spend = <String, double>{};
    for (final e in expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        spend[e.categoryId] = (spend[e.categoryId] ?? 0) + e.amount;
      }
    }

    final atRisk = <String>[];
    var anyOver = false;
    for (final c in categories) {
      final limit = c.budgetLimit;
      if (limit == null || limit <= 0) continue;
      final used = spend[c.id] ?? 0;
      final ratio = used / limit;
      if (ratio >= _budgetThreshold) {
        atRisk.add('${c.name} (${(ratio * 100).round()}%)');
        if (ratio >= 1.0) anyOver = true;
      }
    }

    if (atRisk.isEmpty) return null;

    final title =
        anyOver ? '⚠️ Budget limit exceeded' : '⚠️ Approaching budget limit';
    final body = atRisk.length == 1
        ? '${atRisk.first} of your monthly limit used. Tap to review your spending.'
        : '${atRisk.length} categories near their monthly limit: ${atRisk.join(', ')}.';
    return _BudgetAlert(title, body);
  }
}

class _BudgetAlert {
  final String title;
  final String body;
  const _BudgetAlert(this.title, this.body);
}

class _DailyTip {
  final String title;
  final String body;
  const _DailyTip(this.title, this.body);
}

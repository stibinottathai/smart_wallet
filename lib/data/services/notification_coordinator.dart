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

  /// Fires a budget alert once a category has used at least this fraction of its
  /// monthly limit (i.e. is within 20% of, or over, the limit).
  static const _budgetThreshold = 0.8;

  static Future<void> sync({
    required List<Expense> expenses,
    required List<Category> categories,
    required String currencySymbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool(remindersPrefKey) ?? true;
    final budgetAlertsEnabled = prefs.getBool(budgetAlertsPrefKey) ?? true;

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

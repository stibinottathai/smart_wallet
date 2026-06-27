import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/income_repository.dart';
import '../../domain/repositories/recurring_rule_repository.dart';

/// Summary of what a [RecurringTransactionService.processDue] run posted.
class RecurringPostResult {
  final int expenseCount;
  final int incomeCount;
  final double expenseTotal;
  final double incomeTotal;

  const RecurringPostResult({
    this.expenseCount = 0,
    this.incomeCount = 0,
    this.expenseTotal = 0,
    this.incomeTotal = 0,
  });

  int get total => expenseCount + incomeCount;
  bool get isEmpty => total == 0;
}

/// Evaluates recurring rules and auto-creates the expenses/incomes that have
/// come due, advancing each rule's next-due date. Designed to be run on every
/// app launch (a "catch-up" model) since background Dart execution isn't
/// reliable — opening the app posts everything missed since last time.
class RecurringTransactionService {
  static const _uuid = Uuid();

  /// Safety cap on occurrences posted per rule in a single run, so a rule whose
  /// next-due date is far in the past can't flood the ledger.
  static const int _maxCatchUpPerRule = 60;

  Future<RecurringPostResult> processDue({
    required RecurringRuleRepository ruleRepository,
    required ExpenseRepository expenseRepository,
    required IncomeRepository incomeRepository,
    DateTime? now,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final rules = await ruleRepository.getAllRules();

    var expenseCount = 0, incomeCount = 0;
    var expenseTotal = 0.0, incomeTotal = 0.0;

    for (final rule in rules) {
      if (!rule.isActive) continue;

      var due = rule.nextDueDate;
      DateTime? lastPosted = rule.lastPostedDate;
      var posted = 0;

      while (posted < _maxCatchUpPerRule &&
          !_dateOnly(due).isAfter(today) &&
          (rule.endDate == null || !_dateOnly(due).isAfter(_dateOnly(rule.endDate!)))) {
        if (rule.type == domain.RecurringType.expense) {
          await expenseRepository.addExpense(domain.Expense(
            id: _uuid.v4(),
            amount: rule.amount,
            categoryId: rule.categoryId ?? 'cat_uncategorized',
            date: due,
            note: (rule.note != null && rule.note!.trim().isNotEmpty) ? rule.note : rule.title,
            accountId: rule.accountId,
          ));
          expenseCount++;
          expenseTotal += rule.amount;
        } else {
          await incomeRepository.addIncome(domain.Income(
            id: _uuid.v4(),
            amount: rule.amount,
            source: (rule.source != null && rule.source!.trim().isNotEmpty) ? rule.source! : rule.title,
            date: due,
            isRecurring: true,
            frequency: _incomeFrequency(rule.frequency),
            accountId: rule.accountId,
          ));
          incomeCount++;
          incomeTotal += rule.amount;
        }
        lastPosted = due;
        due = advanceDate(due, rule.frequency, rule.intervalCount);
        posted++;
      }

      if (posted > 0) {
        // Deactivate rules whose schedule has run past their end date.
        final exhausted = rule.endDate != null &&
            _dateOnly(due).isAfter(_dateOnly(rule.endDate!));
        await ruleRepository.updateRule(rule.copyWith(
          nextDueDate: due,
          lastPostedDate: lastPosted,
          isActive: !exhausted,
        ));
      }
    }

    return RecurringPostResult(
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      expenseTotal: expenseTotal,
      incomeTotal: incomeTotal,
    );
  }

  /// Advances [from] by [interval] periods of [freq]. Monthly/yearly steps clamp
  /// the day to the target month's length (e.g. Jan 31 + 1 month → Feb 28).
  static DateTime advanceDate(DateTime from, domain.RecurrenceFrequency freq, int interval) {
    final n = interval < 1 ? 1 : interval;
    switch (freq) {
      case domain.RecurrenceFrequency.daily:
        return from.add(Duration(days: n));
      case domain.RecurrenceFrequency.weekly:
        return from.add(Duration(days: 7 * n));
      case domain.RecurrenceFrequency.monthly:
        return _addMonths(from, n);
      case domain.RecurrenceFrequency.yearly:
        return _addMonths(from, 12 * n);
    }
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(year, month, day);
  }

  static domain.IncomeFrequency _incomeFrequency(domain.RecurrenceFrequency f) {
    switch (f) {
      case domain.RecurrenceFrequency.weekly:
        return domain.IncomeFrequency.weekly;
      case domain.RecurrenceFrequency.monthly:
        return domain.IncomeFrequency.monthly;
      default:
        return domain.IncomeFrequency.oneOff;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

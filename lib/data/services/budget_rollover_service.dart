import '../../domain/models/models.dart' as domain;

/// One category's envelope for the current month: its monthly allocation, any
/// budget rolled over from previous months, what's been spent, and what's left.
class CategoryEnvelope {
  final domain.Category category;
  final double monthlyLimit;

  /// Unspent budget carried in from previous months (0 when rollover is off).
  final double rolloverIn;

  /// Spend recorded against this category in the current month.
  final double spentThisMonth;

  const CategoryEnvelope({
    required this.category,
    required this.monthlyLimit,
    required this.rolloverIn,
    required this.spentThisMonth,
  });

  /// Total available to spend this month.
  double get effectiveBudget => monthlyLimit + rolloverIn;

  /// What's left in the envelope (negative if overspent).
  double get remaining => effectiveBudget - spentThisMonth;

  /// Spend as a fraction of the effective budget (0..1+).
  double get percent => effectiveBudget > 0 ? spentThisMonth / effectiveBudget : 0.0;

  bool get isOverBudget => spentThisMonth > effectiveBudget;
  bool get hasRollover => rolloverIn.abs() > 0.005;
}

/// Computes per-category envelopes (with rollover) for [reference]'s month.
///
/// Rollover is cumulative across the months the category has actually been
/// active — for each prior month we allocate the (current) monthly limit, drop
/// what was spent, and floor the running balance at zero so an overspent month
/// doesn't bury future budgets. Lookback is capped at 12 months to keep the
/// carried amount tied to recent behaviour. Only categories with a positive
/// limit are returned.
class BudgetRolloverService {
  /// How many months back to accumulate rollover from, at most.
  static const int lookbackMonths = 12;

  static List<CategoryEnvelope> computeEnvelopes({
    required List<domain.Category> categories,
    required List<domain.Expense> expenses,
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final currentKey = _monthKey(now.year, now.month);

    // Bucket spend by category and month once.
    final spendByCatMonth = <String, Map<String, double>>{};
    for (final e in expenses) {
      final key = _monthKey(e.date.year, e.date.month);
      final byMonth = spendByCatMonth.putIfAbsent(e.categoryId, () => {});
      byMonth[key] = (byMonth[key] ?? 0) + e.amount;
    }

    final envelopes = <CategoryEnvelope>[];
    for (final category in categories) {
      if (category.id == 'cat_income') continue;
      final limit = category.budgetLimit;
      if (limit == null || limit <= 0) continue;

      final byMonth = spendByCatMonth[category.id] ?? const {};
      final spentThisMonth = byMonth[currentKey] ?? 0.0;

      double rolloverIn = 0.0;
      if (category.rolloverEnabled) {
        rolloverIn = _computeRollover(
          monthlyLimit: limit,
          spendByMonth: byMonth,
          now: now,
        );
      }

      envelopes.add(CategoryEnvelope(
        category: category,
        monthlyLimit: limit,
        rolloverIn: rolloverIn,
        spentThisMonth: spentThisMonth,
      ));
    }

    return envelopes;
  }

  static double _computeRollover({
    required double monthlyLimit,
    required Map<String, double> spendByMonth,
    required DateTime now,
  }) {
    // Earliest month this category saw activity, capped to the lookback window.
    DateTime? earliest;
    for (final key in spendByMonth.keys) {
      final parts = key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    if (earliest == null) return 0.0; // never used → nothing to carry

    final cap = DateTime(now.year, now.month - (lookbackMonths - 1), 1);
    var cursor = earliest.isBefore(cap) ? cap : earliest;
    final lastFullMonth = DateTime(now.year, now.month, 1); // exclusive (current month)

    double balance = 0.0;
    while (cursor.isBefore(lastFullMonth)) {
      final key = _monthKey(cursor.year, cursor.month);
      final spent = spendByMonth[key] ?? 0.0;
      balance += monthlyLimit - spent;
      if (balance < 0) balance = 0.0; // don't carry a deficit forward
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return balance;
  }

  static String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';
}

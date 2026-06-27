import '../../domain/models/models.dart' as domain;

/// A merchant that charges on a regular cadence, inferred from expense history.
class Subscription {
  final String merchant;
  final String? categoryId;
  final double amount; // most recent charge
  final int periodDays; // median gap between charges
  final int occurrences;
  final DateTime firstChargeDate;
  final DateTime lastChargeDate;
  final DateTime nextExpectedDate;
  final bool isActive;

  /// Set when the latest charge is meaningfully higher than the first.
  final double? previousAmount;

  const Subscription({
    required this.merchant,
    required this.categoryId,
    required this.amount,
    required this.periodDays,
    required this.occurrences,
    required this.firstChargeDate,
    required this.lastChargeDate,
    required this.nextExpectedDate,
    required this.isActive,
    this.previousAmount,
  });

  /// Average days per month (365.25 / 12) used to normalise any cadence.
  static const double _daysPerMonth = 30.44;

  /// Charge normalised to a per-month figure.
  double get monthlyCost => amount * (_daysPerMonth / periodDays);

  double get yearlyCost => monthlyCost * 12;

  bool get hasPriceHike => previousAmount != null && amount > previousAmount! + 0.005;

  double get priceHikePercent =>
      previousAmount == null || previousAmount! <= 0 ? 0 : (amount - previousAmount!) / previousAmount! * 100;

  /// Human label for the cadence, derived from [periodDays].
  String get cadenceLabel {
    if (periodDays <= 10) return 'Weekly';
    if (periodDays <= 18) return 'Every 2 weeks';
    if (periodDays <= 45) return 'Monthly';
    if (periodDays <= 100) return 'Quarterly';
    if (periodDays <= 200) return 'Every 6 months';
    return 'Yearly';
  }
}

/// Finds likely subscriptions by grouping expenses by merchant (the note field)
/// and looking for a consistent charging cadence. Purely heuristic and local —
/// no network, no AI required.
class SubscriptionDetectionService {
  /// A subscription is "active" if its last charge is within this many cadence
  /// lengths of today (plus a few days of grace); older ones are treated as
  /// lapsed/cancelled.
  static const double _activeGraceCadences = 1.6;
  static const int _activeGraceDays = 5;

  static List<Subscription> detect({
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());

    // Group by normalised merchant note. Expenses without a note can't be
    // attributed to a merchant, so they're skipped.
    final groups = <String, List<domain.Expense>>{};
    for (final e in expenses) {
      final note = e.note?.trim();
      if (note == null || note.isEmpty) continue;
      final key = note.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      groups.putIfAbsent(key, () => []).add(e);
    }

    final subs = <Subscription>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.date.compareTo(b.date));

      final gaps = <int>[];
      for (var i = 1; i < group.length; i++) {
        gaps.add(group[i].date.difference(group[i - 1].date).inDays);
      }
      final period = _median(gaps);
      if (period < 6 || period > 400) continue; // not a sub-like cadence

      if (!_looksPeriodic(gaps, period, occurrences: group.length)) continue;

      final first = group.first;
      final last = group.last;
      final graceDays = (period * _activeGraceCadences).round() + _activeGraceDays;
      final isActive = !today.isAfter(_dateOnly(last.date).add(Duration(days: graceDays)));

      subs.add(Subscription(
        merchant: (last.note ?? '').trim(),
        categoryId: last.categoryId,
        amount: last.amount,
        periodDays: period,
        occurrences: group.length,
        firstChargeDate: first.date,
        lastChargeDate: last.date,
        nextExpectedDate: last.date.add(Duration(days: period)),
        isActive: isActive,
        previousAmount: (last.amount > first.amount + 0.005) ? first.amount : null,
      ));
    }

    subs.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    return subs;
  }

  /// Total normalised monthly spend across the active subscriptions.
  static double monthlyTotal(List<Subscription> subs) =>
      subs.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.monthlyCost);

  // ── Heuristics ─────────────────────────────────────────────────────────────

  /// With 3+ charges we accept a cadence whose gaps are mostly consistent. With
  /// only 2 charges we require the single gap to land in a typical subscription
  /// band (weekly / monthly / yearly) to avoid false positives.
  static bool _looksPeriodic(List<int> gaps, int period, {required int occurrences}) {
    if (occurrences >= 3) {
      final within = gaps.where((g) => (g - period).abs() <= period * 0.35).length;
      return within >= (gaps.length / 2).ceil();
    }
    final g = gaps.first;
    const bands = [[6, 10], [13, 16], [24, 38], [85, 95], [330, 400]];
    return bands.any((b) => g >= b[0] && g <= b[1]);
  }

  static int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/animated_section.dart';
import 'package:smart_wallet/ui/providers.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class _ForecastEntry {
  final String title;
  final double amount; // positive = inflow, negative = outflow
  final IconData icon;

  const _ForecastEntry({
    required this.title,
    required this.amount,
    required this.icon,
  });

  bool get isInflow => amount > 0;
}

class _DayForecast {
  final DateTime date;
  final double balance;
  final List<_ForecastEntry> entries;

  const _DayForecast({
    required this.date,
    required this.balance,
    required this.entries,
  });
}

// ─── Main view ────────────────────────────────────────────────────────────────

class ForecastView extends ConsumerStatefulWidget {
  const ForecastView({super.key});

  @override
  ConsumerState<ForecastView> createState() => _ForecastViewState();
}

class _ForecastViewState extends ConsumerState<ForecastView> {
  int _horizon = 90;

  static const _horizons = [
    (label: '30 Days', days: 30),
    (label: '3 Months', days: 90),
    (label: '6 Months', days: 180),
  ];

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(accountBalancesProvider);
    final rulesAsync = ref.watch(allRecurringRulesProvider);
    final billsAsync = ref.watch(allBillsProvider);
    final debtsAsync = ref.watch(allDebtsProvider);
    final code = ref.watch(currencyCodeProvider);
    final sym = currencySymbol(code);

    if (rulesAsync.isLoading || billsAsync.isLoading || debtsAsync.isLoading) {
      return const Scaffold(
        appBar: _ForecastAppBar(),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final rules = rulesAsync.value ?? [];
    final bills = billsAsync.value ?? [];
    final debts = debtsAsync.value ?? [];
    final currentBalance = balances.values.fold(0.0, (s, v) => s + v);

    final forecast = _computeForecast(
      currentBalance: currentBalance,
      rules: rules,
      bills: bills,
      debts: debts,
      days: _horizon,
    );

    double totalIn = 0;
    double totalOut = 0;
    double lowestBalance = currentBalance;
    for (final day in forecast) {
      for (final e in day.entries) {
        if (e.isInflow) {
          totalIn += e.amount;
        } else {
          totalOut += e.amount.abs();
        }
      }
      if (day.balance < lowestBalance) lowestBalance = day.balance;
    }

    final activeDays = forecast.where((d) => d.entries.isNotEmpty).toList();

    return Scaffold(
      appBar: const _ForecastAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSection(
              index: 0,
              child: _HorizonChips(
                horizons: _horizons,
                selected: _horizon,
                onSelect: (d) => setState(() => _horizon = d),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSection(
              index: 1,
              child: _ChartCard(
                forecast: forecast,
                currentBalance: currentBalance,
                symbol: sym,
                horizon: _horizon,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSection(
              index: 2,
              child: _SummaryRow(
                totalIn: totalIn,
                totalOut: totalOut,
                lowestBalance: lowestBalance,
                symbol: sym,
              ),
            ),
            const SizedBox(height: 20),
            if (activeDays.isEmpty)
              AnimatedSection(
                index: 3,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 52,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No scheduled transactions found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add recurring rules or bills to see your forecast.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              AnimatedSection(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 12),
                  child: Text(
                    'UPCOMING TRANSACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < activeDays.length; i++)
                AnimatedSection(
                  index: (4 + i) % 12,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DayCard(day: activeDays[i], symbol: sym),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Horizon chips ─────────────────────────────────────────────────────────────

class _HorizonChips extends StatelessWidget {
  final List<({String label, int days})> horizons;
  final int selected;
  final ValueChanged<int> onSelect;

  const _HorizonChips({
    required this.horizons,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < horizons.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(horizons[i].days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == horizons[i].days
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  horizons[i].label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected == horizons[i].days
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (i < horizons.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ─── Chart card ────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<_DayForecast> forecast;
  final double currentBalance;
  final String symbol;
  final int horizon;

  const _ChartCard({
    required this.forecast,
    required this.currentBalance,
    required this.symbol,
    required this.horizon,
  });

  String _fmt(double v) {
    if (v.abs() >= 100000) return '$symbol${(v / 1000).toStringAsFixed(0)}K';
    if (v.abs() >= 1000) return '$symbol${(v / 1000).toStringAsFixed(1)}K';
    return '$symbol${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    // Downsample to ≤60 points for chart performance
    final step = math.max(1, forecast.length ~/ 60);
    final sampled = <_DayForecast>[];
    for (int i = 0; i < forecast.length; i += step) {
      sampled.add(forecast[i]);
    }
    if (sampled.last != forecast.last) sampled.add(forecast.last);

    final spots = sampled
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.balance))
        .toList();

    final allBalances = forecast.map((d) => d.balance).toList();
    final minB = allBalances.fold(double.infinity, math.min);
    final maxB = allBalances.fold(double.negativeInfinity, math.max);
    final range = (maxB - minB).abs().clamp(1.0, double.infinity);

    final endBalance = forecast.last.balance;
    final lineColor =
        endBalance >= currentBalance ? AppColors.primary : AppColors.secondary;
    final xLabelEvery =
        math.max(1, (sampled.length / 4).floor()).toDouble();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected Balance',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'End of period: ${_fmt(endBalance)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: endBalance >= currentBalance
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        endBalance >= currentBalance
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: lineColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        endBalance >= currentBalance ? 'Surplus' : 'Deficit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: lineColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minB - range * 0.15,
                  maxY: maxB + range * 0.15,
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (minB < 0)
                        HorizontalLine(
                          y: 0,
                          color: AppColors.divider,
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                            labelResolver: (_) => '0',
                          ),
                        ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: range / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.divider.withValues(alpha: 0.25),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: xLabelEvery,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= sampled.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('d MMM').format(sampled[i].date),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: lineColor,
                      barWidth: 2.5,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            lineColor.withValues(alpha: 0.18),
                            lineColor.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.text.withValues(alpha: 0.92),
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                        final i = spot.x.toInt();
                        if (i < 0 || i >= sampled.length) return null;
                        return LineTooltipItem(
                          '${DateFormat('d MMM').format(sampled[i].date)}\n${_fmt(spot.y)}',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double totalIn;
  final double totalOut;
  final double lowestBalance;
  final String symbol;

  const _SummaryRow({
    required this.totalIn,
    required this.totalOut,
    required this.lowestBalance,
    required this.symbol,
  });

  String _fmt(double v) {
    if (v.abs() >= 100000) return '$symbol${(v / 1000).toStringAsFixed(0)}K';
    if (v.abs() >= 1000) return '$symbol${(v / 1000).toStringAsFixed(1)}K';
    return '$symbol${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Expected In',
            value: _fmt(totalIn),
            icon: Icons.south_west_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Expected Out',
            value: _fmt(totalOut),
            icon: Icons.north_east_rounded,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Lowest Point',
            value: _fmt(lowestBalance),
            icon: Icons.vertical_align_bottom_rounded,
            color: lowestBalance < 0
                ? AppColors.secondary
                : AppColors.text.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final _DayForecast day;
  final String symbol;

  const _DayCard({required this.day, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day.date == today;
    final isTomorrow = day.date == today.add(const Duration(days: 1));

    final dateLabel = isToday
        ? 'Today'
        : isTomorrow
            ? 'Tomorrow'
            : DateFormat('d MMM, EEE').format(day.date);

    final dayNet = day.entries.fold<double>(0.0, (s, e) => s + e.amount);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Balance: $symbol${day.balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: day.balance >= 0
                        ? AppColors.primary
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final e in day.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: (e.isInflow
                                ? AppColors.primary
                                : AppColors.secondary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        e.icon,
                        size: 16,
                        color: e.isInflow
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.isInflow ? '+' : '-'}$symbol${e.amount.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: e.isInflow
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (day.entries.length > 1) ...[
              const Divider(height: 4),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Net: ${dayNet >= 0 ? '+' : ''}$symbol${dayNet.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dayNet >= 0
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── AppBar (const-able) ───────────────────────────────────────────────────────

class _ForecastAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ForecastAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Cash Flow Forecast'));
}

// ─── Forecast computation ──────────────────────────────────────────────────────

bool _ruleHitsDay(domain.RecurringRule rule, DateTime day) {
  final base = DateTime(
      rule.nextDueDate.year, rule.nextDueDate.month, rule.nextDueDate.day);
  if (day.isBefore(base)) return false;
  if (rule.endDate != null) {
    final end = DateTime(
        rule.endDate!.year, rule.endDate!.month, rule.endDate!.day);
    if (day.isAfter(end)) return false;
  }
  final n = math.max(1, rule.intervalCount);
  switch (rule.frequency) {
    case domain.RecurrenceFrequency.daily:
      return day.difference(base).inDays % n == 0;
    case domain.RecurrenceFrequency.weekly:
      return day.difference(base).inDays % (7 * n) == 0;
    case domain.RecurrenceFrequency.monthly:
      if (day.day != base.day) return false;
      final months =
          (day.year - base.year) * 12 + (day.month - base.month);
      return months % n == 0;
    case domain.RecurrenceFrequency.yearly:
      if (day.day != base.day || day.month != base.month) return false;
      return (day.year - base.year) % n == 0;
  }
}

bool _billHitsDay(domain.Bill bill, DateTime day) {
  final base =
      DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
  switch (bill.frequency) {
    case domain.BillFrequency.oneOff:
      return !bill.isPaid && day == base;
    case domain.BillFrequency.daily:
      return !day.isBefore(base);
    case domain.BillFrequency.weekly:
      if (day.isBefore(base)) return false;
      return day.difference(base).inDays % 7 == 0;
    case domain.BillFrequency.monthly:
      if (day.isBefore(base) || day.day != base.day) return false;
      return true;
    case domain.BillFrequency.yearly:
      if (day.isBefore(base) || day.day != base.day || day.month != base.month) {
        return false;
      }
      return true;
  }
}

bool _debtEmiHitsDay(domain.Debt debt, DateTime day) {
  if (debt.isClosed || (debt.emiAmount ?? 0) <= 0) return false;
  if (debt.type != domain.DebtType.borrowed) return false;
  final start = DateTime(
      debt.startDate.year, debt.startDate.month, debt.startDate.day);
  if (day.isBefore(start) || day.day != start.day) return false;
  if (debt.dueDate != null) {
    final end =
        DateTime(debt.dueDate!.year, debt.dueDate!.month, debt.dueDate!.day);
    if (day.isAfter(end)) return false;
  }
  final months =
      (day.year - start.year) * 12 + (day.month - start.month);
  return months > 0;
}

List<_DayForecast> _computeForecast({
  required double currentBalance,
  required List<domain.RecurringRule> rules,
  required List<domain.Bill> bills,
  required List<domain.Debt> debts,
  required int days,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final activeRules = rules.where((r) => r.isActive).toList();

  final result = <_DayForecast>[];
  double running = currentBalance;

  for (int i = 0; i <= days; i++) {
    final day = today.add(Duration(days: i));
    final entries = <_ForecastEntry>[];

    for (final rule in activeRules) {
      if (_ruleHitsDay(rule, day)) {
        final isIncome = rule.type == domain.RecurringType.income;
        entries.add(_ForecastEntry(
          title: rule.title,
          amount: isIncome ? rule.amount : -rule.amount,
          icon: isIncome
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
        ));
      }
    }

    for (final bill in bills) {
      if (_billHitsDay(bill, day)) {
        entries.add(_ForecastEntry(
          title: bill.name,
          amount: -bill.amount,
          icon: Icons.receipt_long_rounded,
        ));
      }
    }

    for (final debt in debts) {
      if (_debtEmiHitsDay(debt, day)) {
        entries.add(_ForecastEntry(
          title: 'EMI · ${debt.name}',
          amount: -(debt.emiAmount!),
          icon: Icons.account_balance_rounded,
        ));
      }
    }

    final delta = entries.fold<double>(0.0, (s, e) => s + e.amount);
    running += delta;
    result.add(_DayForecast(date: day, balance: running, entries: entries));
  }

  return result;
}

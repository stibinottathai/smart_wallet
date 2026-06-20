import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: incomesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (incomes) {
          return expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('$err')),
            data: (expenses) {
              return categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('$err')),
                data: (categories) {
                  final now = DateTime.now();

                  final currentMonthExpenses = expenses
                      .where((e) => e.date.month == now.month && e.date.year == now.year)
                      .fold<double>(0.0, (s, e) => s + e.amount);

                  final lastMonthDate = DateTime(now.year, now.month - 1);
                  final lastMonthExpenses = expenses
                      .where((e) => e.date.month == lastMonthDate.month && e.date.year == lastMonthDate.year)
                      .fold<double>(0.0, (s, e) => s + e.amount);

                  final momDiff = currentMonthExpenses - lastMonthExpenses;
                  final momPct = lastMonthExpenses > 0
                      ? (momDiff / lastMonthExpenses) * 100
                      : (currentMonthExpenses > 0 ? 100.0 : 0.0);

                  final monthlyData = <String, _MonthlySum>{};
                  for (int i = 5; i >= 0; i--) {
                    final d = DateTime(now.year, now.month - i);
                    final key = DateFormat('MMM yy').format(d);
                    monthlyData[key] = _MonthlySum(0, 0);
                  }
                  for (final inc in incomes) {
                    final key = DateFormat('MMM yy').format(inc.date);
                    monthlyData[key]?.income += inc.amount;
                  }
                  for (final exp in expenses) {
                    final key = DateFormat('MMM yy').format(exp.date);
                    monthlyData[key]?.expense += exp.amount;
                  }

                  final categorySpend = <String, double>{};
                  for (final exp in expenses) {
                    categorySpend[exp.categoryId] = (categorySpend[exp.categoryId] ?? 0) + exp.amount;
                  }
                  final catMap = {for (var c in categories) c.id: c};

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MoMCard(current: currentMonthExpenses, last: lastMonthExpenses, pct: momPct),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Income vs Expense',
                          child: _BarChart(monthlyData: monthlyData),
                        ),
                        const SizedBox(height: 16),
                        if (categorySpend.isNotEmpty)
                          _SectionCard(
                            title: 'Category Breakdown',
                            child: _CategoryPie(spend: categorySpend, catMap: catMap),
                          )
                        else
                          _EmptyState(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthlySum {
  double income;
  double expense;
  _MonthlySum(this.income, this.expense);
}

class _MoMCard extends StatelessWidget {
  final double current;
  final double last;
  final double pct;

  const _MoMCard({required this.current, required this.last, required this.pct});

  @override
  Widget build(BuildContext context) {
    final sign = pct >= 0 ? '+' : '';
    final isUp = pct > 0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MONTH OVER MONTH',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${current.toStringAsFixed(2)}',
                        style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text('This month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${last.toStringAsFixed(2)}',
                      style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('Last month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Spend Trend', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isUp ? AppColors.secondary : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sign${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isUp ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, _MonthlySum> monthlyData;

  const _BarChart({required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    final keys = monthlyData.keys.toList();
    final groups = keys.asMap().entries.map((e) {
      final val = monthlyData[e.value]!;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: val.income,
            color: AppColors.primary,
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: val.expense,
            color: AppColors.secondary,
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxY,
                barGroups: groups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i >= 0 && i < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(keys[i], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.primary, label: 'Income'),
              const SizedBox(width: 20),
              _LegendDot(color: AppColors.secondary, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  double get _maxY {
    double m = 100;
    for (final v in monthlyData.values) {
      if (v.income > m) m = v.income;
      if (v.expense > m) m = v.expense;
    }
    return m * 1.2;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _CategoryPie extends StatelessWidget {
  final Map<String, double> spend;
  final Map<String, domain.Category> catMap;

  const _CategoryPie({required this.spend, required this.catMap});

  @override
  Widget build(BuildContext context) {
    final total = spend.values.fold(0.0, (a, b) => a + b);
    final entries = spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      AppColors.primary, AppColors.secondary,
      AppColors.primary.withValues(alpha: 0.7), AppColors.secondary.withValues(alpha: 0.7),
      AppColors.primary.withValues(alpha: 0.5), AppColors.secondary.withValues(alpha: 0.5),
      AppColors.primary.withValues(alpha: 0.35), AppColors.secondary.withValues(alpha: 0.35),
    ];

    final sections = entries.asMap().entries.map((e) {
      return PieChartSectionData(
        value: e.value.value,
        color: colors[e.key % colors.length],
        radius: 32,
        showTitle: false,
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(PieChartData(
            sections: sections,
            centerSpaceRadius: 28,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: entries.take(6).map((e) {
              final name = catMap[e.key]?.name ?? 'Unknown';
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors[entries.indexOf(e) % colors.length]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                    Text('\$${e.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                    const SizedBox(width: 4),
                    Text('(${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.analytics_rounded, size: 28, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('No expense data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Add some expenses to see analysis', style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
      ),
      body: incomesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading incomes: $err')),
        data: (incomes) {
          return expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading expenses: $err')),
            data: (expenses) {
              return categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading categories: $err')),
                data: (categories) {
                  // Calculations
                  final now = DateTime.now();

                  // Month-over-Month calculations
                  final currentMonthExpenses = expenses
                      .where((e) => e.date.month == now.month && e.date.year == now.year)
                      .fold<double>(0.0, (sum, item) => sum + item.amount);

                  final lastMonthDate = DateTime(now.year, now.month - 1);
                  final lastMonthExpenses = expenses
                      .where((e) => e.date.month == lastMonthDate.month && e.date.year == lastMonthDate.year)
                      .fold<double>(0.0, (sum, item) => sum + item.amount);

                  final momDifference = currentMonthExpenses - lastMonthExpenses;
                  final momChangePercent = lastMonthExpenses > 0
                      ? (momDifference / lastMonthExpenses) * 100
                      : (currentMonthExpenses > 0 ? 100.0 : 0.0);

                  // Group by month (last 6 months) for Income vs Expense progression
                  final Map<String, _MonthlySum> monthlyData = {};
                  for (int i = 5; i >= 0; i--) {
                    final d = DateTime(now.year, now.month - i);
                    final key = DateFormat('MMM yy').format(d);
                    monthlyData[key] = _MonthlySum(0.0, 0.0);
                  }

                  for (final inc in incomes) {
                    final key = DateFormat('MMM yy').format(inc.date);
                    if (monthlyData.containsKey(key)) {
                      monthlyData[key]!.income += inc.amount;
                    }
                  }

                  for (final exp in expenses) {
                    final key = DateFormat('MMM yy').format(exp.date);
                    if (monthlyData.containsKey(key)) {
                      monthlyData[key]!.expense += exp.amount;
                    }
                  }

                  // Group by category for donut chart
                  final Map<String, double> categorySpendMap = {};
                  for (final exp in expenses) {
                    categorySpendMap[exp.categoryId] = (categorySpendMap[exp.categoryId] ?? 0.0) + exp.amount;
                  }
                  final categoryMap = {for (var c in categories) c.id: c};

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // MoM Card block
                        _buildMoMCard(currentMonthExpenses, lastMonthExpenses, momChangePercent),
                        const SizedBox(height: 28.0),

                        // Income vs Expense Chart header
                        const Text(
                          'Income vs Expense Over Time',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                        ),
                        const SizedBox(height: 16.0),
                        _buildBarChart(monthlyData),
                        const SizedBox(height: 28.0),

                        // Category Breakdown header
                        if (categorySpendMap.isNotEmpty) ...[
                          const Text(
                            'Category Breakdown',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                          ),
                          const SizedBox(height: 16.0),
                          _buildDonutChartWithLegends(categorySpendMap, categoryMap),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Center(
                              child: Text(
                                'No expense data to analyze.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ]
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

  Widget _buildMoMCard(double current, double last, double percentChange) {
    final sign = percentChange >= 0 ? '+' : '';
    final isIncrease = percentChange > 0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS MONTH VS. LAST MONTH',
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: AppColors.text.withValues(alpha: 0.5),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${current.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
                  ),
                  const Text('This Month', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${last.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 20.0, color: AppColors.text.withValues(alpha: 0.8)),
                  ),
                  const Text('Last Month', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const Divider(height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Spend Trend', style: TextStyle(fontSize: 13.0)),
              Text(
                '$sign${percentChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: isIncrease ? AppColors.secondary : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, _MonthlySum> monthlyData) {
    final keys = monthlyData.keys.toList();
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final val = monthlyData[key]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val.income,
              color: AppColors.primary,
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: val.expense,
              color: AppColors.secondary,
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxY(monthlyData),
          barGroups: barGroups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        keys[idx],
                        style: const TextStyle(fontSize: 10.0, color: Colors.grey),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getMaxY(Map<String, _MonthlySum> data) {
    double maxVal = 100.0;
    for (final val in data.values) {
      if (val.income > maxVal) maxVal = val.income;
      if (val.expense > maxVal) maxVal = val.expense;
    }
    return maxVal * 1.15;
  }

  Widget _buildDonutChartWithLegends(Map<String, double> categorySpendMap, Map<String, domain.Category> categoryMap) {
    final List<PieChartSectionData> sections = [];
    final List<Widget> legends = [];
    int index = 0;

    final baseColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.primary.withValues(alpha: 0.7),
      AppColors.secondary.withValues(alpha: 0.7),
      AppColors.primary.withValues(alpha: 0.5),
      AppColors.secondary.withValues(alpha: 0.5),
      AppColors.primary.withValues(alpha: 0.3),
      AppColors.secondary.withValues(alpha: 0.3),
    ];

    categorySpendMap.forEach((catId, amount) {
      final name = categoryMap[catId]?.name ?? 'Uncategorized';
      final color = baseColors[index % baseColors.length];

      sections.add(
        PieChartSectionData(
          value: amount,
          title: name,
          radius: 35,
          showTitle: false,
          color: color,
        ),
      );

      legends.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12.0),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      index++;
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 120,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: legends,
          ),
        ),
      ],
    );
  }
}

class _MonthlySum {
  double income;
  double expense;
  _MonthlySum(this.income, this.expense);
}

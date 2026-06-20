import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'legend_dot.dart';

class IncomeExpenseBarChart extends StatelessWidget {
  final List<domain.Income> incomes;
  final List<domain.Expense> expenses;
  final DateTime start;
  final DateTime end;

  const IncomeExpenseBarChart({
    super.key,
    required this.incomes,
    required this.expenses,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyData = <String, _MonthlySum>{};

    final startMonth = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);
    int monthCount = ((endMonth.year - startMonth.year) * 12 + (endMonth.month - startMonth.month)).clamp(1, 24);

    for (int i = monthCount; i >= 0; i--) {
      final d = DateTime(end.year, end.month - i);
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
                maxY: _maxY(monthlyData),
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
              const LegendDot(color: AppColors.primary, label: 'Income'),
              const SizedBox(width: 20),
              const LegendDot(color: AppColors.secondary, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  double _maxY(Map<String, _MonthlySum> data) {
    double m = 100;
    for (final v in data.values) {
      if (v.income > m) m = v.income;
      if (v.expense > m) m = v.expense;
    }
    return m * 1.2;
  }
}

class _MonthlySum {
  double income;
  double expense;
  _MonthlySum(this.income, this.expense);
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class WeekdaySpendingChart extends StatelessWidget {
  final List<domain.Expense> expenses;

  const WeekdaySpendingChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final dayTotals = <int, double>{};
    final dayCounts = <int, int>{};
    for (int i = 1; i <= 7; i++) {
      dayTotals[i] = 0;
      dayCounts[i] = 0;
    }

    for (final exp in expenses) {
      final wd = exp.date.weekday;
      dayTotals[wd] = (dayTotals[wd] ?? 0) + exp.amount;
      dayCounts[wd] = (dayCounts[wd] ?? 0) + 1;
    }

    final averages = dayTotals.entries.map((e) {
      final count = dayCounts[e.key] ?? 1;
      return (value: e.value / count.clamp(1, 99999), weekday: e.key);
    }).toList()..sort((a, b) => a.weekday.compareTo(b.weekday));

    final maxVal = averages.fold(0.0, (a, v) => v.value > a ? v.value : a);

    final groups = averages.asMap().entries.map((e) {
      final intensity = maxVal > 0 ? (e.value.value / maxVal).clamp(0.2, 1.0) : 0.3;
      final color = Color.lerp(AppColors.primary.withValues(alpha: 0.3), AppColors.primary, intensity)!;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value,
            color: color,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
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
                  if (i >= 0 && i < _weekdayLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_weekdayLabels[i], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '\$${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

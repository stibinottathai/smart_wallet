import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';

class NetWorthLineChart extends StatelessWidget {
  final List<domain.Income> incomes;
  final List<domain.Expense> expenses;

  const NetWorthLineChart({
    super.key,
    required this.incomes,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyMap = <String, double>{};

    final now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      monthlyMap[DateFormat('MMM yy').format(d)] = 0;
    }

    for (final inc in incomes) {
      final key = DateFormat('MMM yy').format(inc.date);
      monthlyMap[key] = (monthlyMap[key] ?? 0) + inc.amount;
    }
    for (final exp in expenses) {
      final key = DateFormat('MMM yy').format(exp.date);
      monthlyMap[key] = (monthlyMap[key] ?? 0) - exp.amount;
    }

    final keys = monthlyMap.keys.toList();
    double cumulative = 0;
    final spots = keys.map((k) {
      cumulative += monthlyMap[k]!;
      return FlSpot(keys.indexOf(k).toDouble(), cumulative);
    }).toList();

    final minY = spots.fold(0.0, (a, s) => s.y < a ? s.y : a);
    final maxY = spots.fold(0.0, (a, s) => s.y > a ? s.y : a);
    final range = (maxY - minY).abs().clamp(1, double.infinity);
    final color = spots.last.y >= 0 ? AppColors.primary : AppColors.secondary;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: range / 4),
          borderData: FlBorderData(show: false),
          minY: minY - range * 0.1,
          maxY: maxY + range * 0.1,
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
                  if (i >= 0 && i < keys.length && (keys.length > 6 ? i % 3 == 0 : true)) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(keys[i], style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0)),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
              isCurved: true,
              preventCurveOverShooting: true,
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

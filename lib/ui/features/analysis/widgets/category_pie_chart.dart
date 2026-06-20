import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';


class CategoryPieChart extends StatelessWidget {
  final Map<String, double> spend;
  final Map<String, domain.Category> catMap;
  final List<domain.Expense> expenses;
  final DateTime start;
  final DateTime end;

  const CategoryPieChart({
    super.key,
    required this.spend,
    required this.catMap,
    required this.expenses,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final total = spend.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: GestureDetector(
            onTapDown: (details) => _onTapPie(context, details, entries, colors),
            child: PieChart(PieChartData(
              sections: sections,
              centerSpaceRadius: 28,
              sectionsSpace: 2,
            )),
          ),
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

  void _onTapPie(BuildContext context, TapDownDetails details, List<MapEntry<String, double>> entries, List<Color> colors) {
    if (entries.isEmpty) return;
    final e = entries.first;
    final name = catMap[e.key]?.name ?? 'Unknown';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryDrillDown(
        categoryName: name,
        categoryColor: colors[0],
        expenses: expenses.where((x) => x.categoryId == e.key).toList(),
        start: start,
        end: end,
      ),
    );
  }
}

class _CategoryDrillDown extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final List<domain.Expense> expenses;
  final DateTime start;
  final DateTime end;

  const _CategoryDrillDown({
    required this.categoryName,
    required this.categoryColor,
    required this.expenses,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final monthlyTotals = <String, double>{};
    final startMonth = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);
    int monthCount = ((endMonth.year - startMonth.year) * 12 + (endMonth.month - startMonth.month)).clamp(1, 24);

    for (int i = monthCount; i >= 0; i--) {
      final d = DateTime(end.year, end.month - i);
      monthlyTotals[DateFormat('MMM yy').format(d)] = 0;
    }
    for (final exp in expenses) {
      final key = DateFormat('MMM yy').format(exp.date);
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + exp.amount;
    }

    final keys = monthlyTotals.keys.toList();
    final values = keys.map((k) => monthlyTotals[k]!).toList();
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(
                        '$categoryName Trend',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: values.every((v) => v == 0)
                        ? const Center(child: Text('No data for this period', style: TextStyle(color: AppColors.textSecondary)))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxVal > 0 ? maxVal / 4 : 1),
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
                                      if (i >= 0 && i < keys.length && (keys.length > 6 ? i % (keys.length ~/ 4 + 1) == 0 : true)) {
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
                                  spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                  color: categoryColor,
                                  barWidth: 2.5,
                                  dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: categoryColor, strokeWidth: 0)),
                                  belowBarData: BarAreaData(show: true, color: categoryColor.withValues(alpha: 0.15)),
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

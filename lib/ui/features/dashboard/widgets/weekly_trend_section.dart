import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'section_header.dart';

/// Bar chart of daily expense totals over the last 7 days. The bars grow up
/// from the baseline on first appearance — like a progress bar filling.
class WeeklyTrendSection extends StatefulWidget {
  final List<domain.Expense> expenses;
  final String symbol;

  const WeeklyTrendSection({
    super.key,
    required this.expenses,
    required this.symbol,
  });

  @override
  State<WeeklyTrendSection> createState() => _WeeklyTrendSectionState();
}

class _WeeklyTrendSectionState extends State<WeeklyTrendSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _barCount = 7;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Eased grow factor (0→1) for the bar at [index]. Each bar gets its own
  /// staggered slice of the timeline so they rise left-to-right, one after
  /// another, rather than all at once.
  double _barFactor(int index) {
    // Each bar's window starts a little after the previous one's and overlaps,
    // so the cascade stays smooth.
    final start = (index / (_barCount + 2)).clamp(0.0, 1.0);
    const window = 0.45; // fraction of the timeline each bar takes to fill
    final t = ((_controller.value - start) / window).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.expenses;
    final symbol = widget.symbol;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    final dailyTotals = <DateTime, double>{};
    for (final day in last7Days) {
      dailyTotals[day] = 0.0;
    }

    for (final exp in expenses) {
      final expDay = DateTime(exp.date.year, exp.date.month, exp.date.day);
      if (dailyTotals.containsKey(expDay)) {
        dailyTotals[expDay] = (dailyTotals[expDay] ?? 0.0) + exp.amount;
      }
    }

    final maxSpend = dailyTotals.values.fold<double>(0.0, (max, val) => val > max ? val : max);
    final yAxisLimit = maxSpend > 0 ? (maxSpend * 1.25) : 10.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Weekly Spending Trend',
                subtitle: 'Daily expenses over the last 7 days',
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 150,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => BarChart(
                  // We drive the grow-up ourselves via [_grow], so disable
                  // fl_chart's own implicit tween to avoid fighting it.
                  duration: Duration.zero,
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: yAxisLimit,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.text,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '$symbol${rod.toY.toStringAsFixed(2)}',
                            GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= 7) return const SizedBox.shrink();
                            final day = last7Days[index];
                            final label = DateFormat('E').format(day)[0];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final day = last7Days[index];
                      final total = dailyTotals[day] ?? 0.0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: total * _barFactor(index),
                            color: AppColors.secondary,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: yAxisLimit,
                              color: AppColors.divider.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'section_header.dart';

/// Donut chart + legend showing all-time spend split by category.
class SpendingBreakdownSection extends StatelessWidget {
  final Map<String, double> spendMap;
  final Map<String, domain.Category> categoryMap;

  const SpendingBreakdownSection({
    super.key,
    required this.spendMap,
    required this.categoryMap,
  });

  @override
  Widget build(BuildContext context) {
    final total = spendMap.values.fold(0.0, (a, b) => a + b);
    final entries = spendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Spending Breakdown'),
              const SizedBox(height: 18),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sections: entries.asMap().entries.map((e) {
                          final colors = [
                            AppColors.primary,
                            AppColors.secondary,
                            AppColors.primary.withValues(alpha: 0.7),
                            AppColors.secondary.withValues(alpha: 0.7),
                            AppColors.primary.withValues(alpha: 0.5),
                            AppColors.secondary.withValues(alpha: 0.5),
                            AppColors.primary.withValues(alpha: 0.35),
                            AppColors.secondary.withValues(alpha: 0.35),
                          ];
                          return PieChartSectionData(
                            value: e.value.value,
                            color: colors[e.key % colors.length],
                            radius: 28,
                            showTitle: false,
                          );
                        }).toList(),
                        centerSpaceRadius: 28,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: entries.take(5).map((e) {
                        final name = categoryMap[e.key]?.name ?? 'Unknown';
                        final pct = total > 0 ? (e.value / total * 100) : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(alpha: 0.5 + (e.value / (total > 0 ? total : 1)) * 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

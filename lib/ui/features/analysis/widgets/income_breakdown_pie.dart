import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';


class IncomeBreakdownPie extends StatelessWidget {
  final List<domain.Income> incomes;

  const IncomeBreakdownPie({super.key, required this.incomes});

  @override
  Widget build(BuildContext context) {
    final sourceMap = <String, double>{};
    for (final inc in incomes) {
      sourceMap[inc.source] = (sourceMap[inc.source] ?? 0) + inc.amount;
    }

    if (sourceMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No income data', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      );
    }

    final total = sourceMap.values.fold(0.0, (a, b) => a + b);
    final entries = sourceMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [AppColors.primary, AppColors.secondary, AppColors.primary.withValues(alpha: 0.7), AppColors.secondary.withValues(alpha: 0.7)];

    final sections = entries.asMap().entries.map((e) {
      return PieChartSectionData(
        value: e.value.value,
        color: colors[e.key % colors.length],
        radius: 28,
        showTitle: false,
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(PieChartData(
            sections: sections,
            centerSpaceRadius: 22,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: entries.map((e) {
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors[entries.indexOf(e) % colors.length]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
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

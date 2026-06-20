import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';


class ExpenseSourcePie extends StatelessWidget {
  final List<domain.Expense> expenses;

  const ExpenseSourcePie({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    double manualTotal = 0;
    double aiTotal = 0;
    int manualCount = 0;
    int aiCount = 0;

    for (final exp in expenses) {
      if (exp.source == domain.ExpenseSource.aiScan) {
        aiTotal += exp.amount;
        aiCount++;
      } else {
        manualTotal += exp.amount;
        manualCount++;
      }
    }

    final total = manualTotal + aiTotal;
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No expense data', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      );
    }

    final sections = [
      PieChartSectionData(
        value: manualTotal,
        color: AppColors.primary,
        radius: 28,
        showTitle: false,
      ),
      PieChartSectionData(
        value: aiTotal,
        color: AppColors.secondary.withValues(alpha: 0.6),
        radius: 28,
        showTitle: false,
      ),
    ];

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
            children: [
              _sourceRow('Manual', manualTotal, total, manualCount, AppColors.primary),
              const SizedBox(height: 6),
              _sourceRow('AI Scan', aiTotal, total, aiCount, AppColors.secondary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceRow(String label, double amount, double total, int count, Color color) {
    final pct = total > 0 ? (amount / total * 100) : 0.0;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Text('\$${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(width: 4),
        Text('(${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

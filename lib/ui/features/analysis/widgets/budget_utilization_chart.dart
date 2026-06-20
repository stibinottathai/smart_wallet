import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';

class BudgetUtilizationChart extends ConsumerWidget {
  final Map<String, double> spend;
  final List<domain.Category> categories;

  const BudgetUtilizationChart({
    super.key,
    required this.spend,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final withBudget = categories.where((c) => c.budgetLimit != null && c.budgetLimit! > 0).toList();

    if (withBudget.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Set budget limits on categories in Settings to see utilization',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: withBudget.map((cat) {
        final actual = spend[cat.id] ?? 0;
        final budget = cat.budgetLimit!;
        final ratio = (actual / budget).clamp(0.0, 1.0);
        final isOver = actual > budget;
        final catColor = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(cat.name, style: const TextStyle(fontSize: 12, color: AppColors.text), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(isOver ? AppColors.error : AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text(
                  '${currencySymbol(code)}${actual.toStringAsFixed(0)} / ${currencySymbol(code)}${budget.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOver ? AppColors.error : AppColors.textSecondary,
                    fontWeight: isOver ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

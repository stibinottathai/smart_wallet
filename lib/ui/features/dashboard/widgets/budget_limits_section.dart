import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import '../views/budget_form_dialog.dart';
import 'section_header.dart';

class _BudgetItem {
  final domain.Category category;
  final double spend;
  final double limit;

  _BudgetItem({
    required this.category,
    required this.spend,
    required this.limit,
  });

  double get percent => limit > 0 ? (spend / limit) : 0.0;
}

/// Monthly budget-limit progress bars for categories that have a cap set.
class BudgetLimitsSection extends StatelessWidget {
  final Map<String, double> monthlySpendMap;
  final List<domain.Category> categories;
  final String symbol;

  const BudgetLimitsSection({
    super.key,
    required this.monthlySpendMap,
    required this.categories,
    required this.symbol,
  });

  void _showManageBudgetsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetFormDialog(categories: categories),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_BudgetItem>[];
    for (final category in categories) {
      if (category.id == 'cat_income') continue;
      final limit = category.budgetLimit;
      if (limit != null && limit > 0) {
        final spend = monthlySpendMap[category.id] ?? 0.0;
        items.add(_BudgetItem(
          category: category,
          spend: spend,
          limit: limit,
        ));
      }
    }

    items.sort((a, b) => b.percent.compareTo(a.percent));

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Monthly Budget Limits',
                  action: AddIconButton(
                    icon: Icons.edit_rounded,
                    onTap: () => _showManageBudgetsDialog(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Track your spending caps',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set monthly budget limits for categories like Dining, Groceries, and Rent to avoid overspending.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showManageBudgetsDialog(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Set Monthly Budgets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Monthly Budget Limits',
                subtitle: 'Spending progress against category caps',
                action: AddIconButton(
                  icon: Icons.edit_rounded,
                  onTap: () => _showManageBudgetsDialog(context),
                ),
              ),
              const SizedBox(height: 20),
              ...items.map((item) {
                final catColor = Color(int.parse(item.category.color.replaceAll('#', '0xFF')));
                final percentLabel = '${(item.percent * 100).toStringAsFixed(0)}%';
                final isOverBudget = item.spend > item.limit;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                getCategoryIcon(item.category.icon),
                                size: 14,
                                color: catColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.category.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$symbol${item.spend.toStringAsFixed(0)} / $symbol${item.limit.toStringAsFixed(0)} ($percentLabel)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOverBudget ? AppColors.secondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.percent.clamp(0.0, 1.0),
                          backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget ? AppColors.secondary : catColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

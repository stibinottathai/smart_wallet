import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/data/services/budget_rollover_service.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import '../views/budget_form_dialog.dart';
import '../../budget/views/envelope_view.dart';
import 'section_header.dart';

/// Monthly budget-limit progress bars for categories that have a cap set.
/// Rollover-enabled categories are measured against their effective budget
/// (monthly limit + carried-over balance).
class BudgetLimitsSection extends StatelessWidget {
  final List<domain.Expense> expenses;
  final List<domain.Category> categories;
  final String symbol;

  const BudgetLimitsSection({
    super.key,
    required this.expenses,
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

  void _openEnvelopes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EnvelopeView()),
    );
  }

  /// Header actions: open the envelope view + edit budgets.
  Widget _headerActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AddIconButton(
          icon: Icons.mail_outline_rounded,
          onTap: () => _openEnvelopes(context),
        ),
        const SizedBox(width: 8),
        AddIconButton(
          icon: Icons.edit_rounded,
          onTap: () => _showManageBudgetsDialog(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = BudgetRolloverService.computeEnvelopes(
      categories: categories,
      expenses: expenses,
    );

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
                  action: _headerActions(context),
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
                action: _headerActions(context),
              ),
              const SizedBox(height: 20),
              ...items.map((item) {
                final catColor = Color(int.parse(item.category.color.replaceAll('#', '0xFF')));
                final percentLabel = '${(item.percent * 100).toStringAsFixed(0)}%';
                final isOverBudget = item.isOverBudget;

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
                              if (item.hasRollover) ...[
                                const SizedBox(width: 5),
                                Icon(Icons.refresh_rounded, size: 12, color: AppColors.primary),
                              ],
                            ],
                          ),
                          Text(
                            '$symbol${item.spentThisMonth.toStringAsFixed(0)} / $symbol${item.effectiveBudget.toStringAsFixed(0)} ($percentLabel)',
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
                      if (item.hasRollover) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Includes $symbol${item.rolloverIn.toStringAsFixed(0)} rolled over',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.primary),
                        ),
                      ],
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

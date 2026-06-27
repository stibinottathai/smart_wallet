import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'recurring_form_dialog.dart';

/// Manage recurring expense/income rules. Active rules auto-post their entries
/// when the app is opened on or after their due date.
class RecurringView extends ConsumerWidget {
  const RecurringView({super.key});

  void _openForm(BuildContext context, {domain.RecurringRule? rule}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecurringFormDialog(initialRule: rule),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(allRecurringRulesProvider);
    final categories = {for (final c in (ref.watch(allCategoriesProvider).value ?? [])) c.id: c};
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recurring',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring_fab',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (rules) {
          if (rules.isEmpty) return _empty(context);
          final active = rules.where((r) => r.isActive).toList();
          final paused = rules.where((r) => !r.isActive).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              _InfoBanner(),
              const SizedBox(height: 16),
              if (active.isNotEmpty) ...[
                _label('Active'),
                const SizedBox(height: 8),
                ...active.map((r) => _RuleTile(
                      rule: r,
                      category: r.categoryId == null ? null : categories[r.categoryId],
                      symbol: symbol,
                      onTap: () => _openForm(context, rule: r),
                      onToggle: (v) => ref.read(recurringRuleRepositoryProvider).updateRule(r.copyWith(isActive: v)),
                    )),
              ],
              if (paused.isNotEmpty) ...[
                const SizedBox(height: 16),
                _label('Paused'),
                const SizedBox(height: 8),
                ...paused.map((r) => _RuleTile(
                      rule: r,
                      category: r.categoryId == null ? null : categories[r.categoryId],
                      symbol: symbol,
                      onTap: () => _openForm(context, rule: r),
                      onToggle: (v) => ref.read(recurringRuleRepositoryProvider).updateRule(r.copyWith(isActive: v)),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.text.withValues(alpha: 0.5),
          letterSpacing: 0.3,
        ),
      );

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.repeat_rounded, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No recurring transactions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 6),
            const Text(
              'Schedule rent, subscriptions or salary once and Smart Wallet will add them automatically when they fall due.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _openForm(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Add a recurring rule', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Due entries are added automatically each time you open the app — including any you missed while it was closed.',
              style: TextStyle(fontSize: 12, color: AppColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final domain.RecurringRule rule;
  final domain.Category? category;
  final String symbol;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _RuleTile({
    required this.rule,
    required this.category,
    required this.symbol,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = rule.type == domain.RecurringType.expense;
    final accent = isExpense ? AppColors.secondary : AppColors.primary;
    final color = category != null
        ? Color(int.parse(category!.color.replaceAll('#', '0xFF')))
        : accent;
    final icon = isExpense ? getCategoryIcon(category?.icon) : Icons.attach_money_rounded;
    final dueLabel = DateFormat('MMM d, yyyy').format(rule.nextDueDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rule.frequency.displayName} • ${rule.isActive ? "next $dueLabel" : "paused"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isExpense ? '-' : '+'}$symbol${rule.amount.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: accent),
                    ),
                    SizedBox(
                      height: 26,
                      child: Transform.scale(
                        scale: 0.72,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: rule.isActive,
                          activeThumbColor: AppColors.primary,
                          onChanged: onToggle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

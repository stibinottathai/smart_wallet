import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/data/services/budget_rollover_service.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/dashboard/views/budget_form_dialog.dart';

/// Envelope budgeting screen: each budgeted category is an "envelope" showing
/// its monthly allocation plus any rolled-over balance, what's been spent, and
/// what's left for the current month.
class EnvelopeView extends ConsumerWidget {
  const EnvelopeView({super.key});

  void _openBudgetForm(BuildContext context, List<domain.Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetFormDialog(categories: categories),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envelopes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text),
            ),
            Text(
              monthLabel,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Edit budgets',
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
              onPressed: () => _openBudgetForm(ctx, categoriesAsync.value ?? []),
            ),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (expenses) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (categories) {
            final envelopes = BudgetRolloverService.computeEnvelopes(
              categories: categories,
              expenses: expenses,
            );

            if (envelopes.isEmpty) {
              return _EmptyState(onSetup: () => _openBudgetForm(context, categories));
            }

            envelopes.sort((a, b) => b.percent.compareTo(a.percent));

            final totalBudget = envelopes.fold<double>(0, (s, e) => s + e.effectiveBudget);
            final totalSpent = envelopes.fold<double>(0, (s, e) => s + e.spentThisMonth);
            final totalRollover = envelopes.fold<double>(0, (s, e) => s + e.rolloverIn);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _SummaryCard(
                  totalBudget: totalBudget,
                  totalSpent: totalSpent,
                  totalRollover: totalRollover,
                  symbol: symbol,
                ),
                const SizedBox(height: 18),
                ...envelopes.map((e) => _EnvelopeCard(envelope: e, symbol: symbol)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalRollover;
  final String symbol;

  const _SummaryCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRollover,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalBudget - totalSpent;
    final percent = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6F5E), Color(0xFF1E463C)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEFT TO SPEND THIS MONTH',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${remaining.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? AppColors.secondaryLight : const Color(0xFFD4E8E2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Budget', '$symbol${totalBudget.toStringAsFixed(0)}'),
              _miniStat('Spent', '$symbol${totalSpent.toStringAsFixed(0)}'),
              if (totalRollover > 0.005) _miniStat('Rolled over', '$symbol${totalRollover.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  final CategoryEnvelope envelope;
  final String symbol;

  const _EnvelopeCard({required this.envelope, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final cat = envelope.category;
    final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
    final over = envelope.isOverBudget;
    final remaining = envelope.remaining;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(getCategoryIcon(cat.icon), color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                        if (envelope.hasRollover) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 11, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '$symbol${envelope.monthlyLimit.toStringAsFixed(0)} + $symbol${envelope.rolloverIn.toStringAsFixed(0)} rolled over',
                                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$symbol${remaining.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: over ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                      Text(
                        over ? 'over' : 'left',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: envelope.percent.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(over ? AppColors.secondary : color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$symbol${envelope.spentThisMonth.toStringAsFixed(0)} spent of $symbol${envelope.effectiveBudget.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyState({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.mail_outline_rounded, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No envelopes yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set monthly budget limits for your categories, then turn on rollover to carry unspent budget forward.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Set up budgets', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

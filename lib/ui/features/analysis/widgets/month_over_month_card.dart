import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';

class MonthOverMonthCard extends ConsumerWidget {
  final List<domain.Expense> expenses;
  final DateTime start;
  final DateTime end;

  const MonthOverMonthCard({
    super.key,
    required this.expenses,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final now = end.isBefore(DateTime.now()) ? end : DateTime.now();

    final currentMonthExpenses = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0.0, (s, e) => s + e.amount);

    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonthExpenses = expenses
        .where((e) => e.date.month == lastMonthDate.month && e.date.year == lastMonthDate.year)
        .fold<double>(0.0, (s, e) => s + e.amount);

    final diff = currentMonthExpenses - lastMonthExpenses;
    final pct = lastMonthExpenses > 0
        ? (diff / lastMonthExpenses) * 100
        : (currentMonthExpenses > 0 ? 100.0 : 0.0);

    final sign = pct >= 0 ? '+' : '';
    final isUp = pct > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MONTH OVER MONTH',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currencySymbol(code)}${currentMonthExpenses.toStringAsFixed(2)}',
                        style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text('This month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${currencySymbol(code)}${lastMonthExpenses.toStringAsFixed(2)}',
                      style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('Last month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Spend Trend', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isUp ? AppColors.secondary : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sign${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isUp ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

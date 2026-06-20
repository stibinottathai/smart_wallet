import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';

class SavingsRateCard extends ConsumerWidget {
  final double totalIncome;
  final double totalExpense;
  final double lastIncome;
  final double lastExpense;

  const SavingsRateCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.lastIncome,
    required this.lastExpense,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final rate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome) * 100 : 0.0;
    final lastRate = lastIncome > 0 ? ((lastIncome - lastExpense) / lastIncome) * 100 : 0.0;
    final delta = rate - lastRate;

    Color rateColor;
    if (rate >= 20) {
      rateColor = AppColors.success;
    } else if (rate >= 0) {
      rateColor = AppColors.secondary;
    } else {
      rateColor = AppColors.error;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SAVINGS RATE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: rateColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.text),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 14,
                        color: delta >= 0 ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${delta.abs().toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: delta >= 0 ? AppColors.success : AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${rate >= 0 ? 'Saving' : 'Spending beyond'} ${currencySymbol(code)}${(totalIncome - totalExpense).abs().toStringAsFixed(2)} ${rate >= 0 ? 'this period' : 'over income'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0, 100) / 100,
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

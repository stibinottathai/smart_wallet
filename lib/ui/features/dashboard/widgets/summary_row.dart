import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';

/// Income / expenses pair of summary cards shown under the balance header.
class SummaryRow extends StatelessWidget {
  final double income;
  final double expense;
  final String symbol;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  const SummaryRow({
    super.key,
    required this.income,
    required this.expense,
    required this.symbol,
    this.onIncomeTap,
    this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: 'Income',
              amount: income,
              color: AppColors.primary,
              icon: Icons.south_west_rounded,
              prefix: '+',
              symbol: symbol,
              onTap: onIncomeTap,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SummaryCard(
              label: 'Expenses',
              amount: expense,
              color: AppColors.secondary,
              icon: Icons.north_east_rounded,
              prefix: '-',
              symbol: symbol,
              onTap: onExpenseTap,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final String prefix;
  final String symbol;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.prefix,
    required this.symbol,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$prefix$symbol${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

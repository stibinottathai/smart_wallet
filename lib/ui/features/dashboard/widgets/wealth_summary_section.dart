import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/accounts/views/accounts_view.dart';
import 'package:smart_wallet/ui/features/investments/views/investments_view.dart';
import 'package:smart_wallet/ui/features/networth/views/net_worth_view.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Three-tile summary that makes the invest-as-asset-transfer model legible at
/// a glance: liquid cash on the left, current investment value in the middle,
/// the sum on the right. Tapping a tile deep-links to its owning screen so the
/// dashboard stays a navigation hub.
///
/// Numbers are derived live from [availableCashProvider],
/// [investmentAssetsValueProvider] and [totalNetWorthProvider] so the section
/// stays in sync with every income / expense / investment / transfer mutation.
class WealthSummarySection extends ConsumerWidget {
  const WealthSummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(availableCashProvider);
    final investments = ref.watch(investmentAssetsValueProvider);
    final netWorth = ref.watch(totalNetWorthProvider);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    // Show this section only once the user has at least one money-related
    // signal — otherwise it's three zeroes on a fresh install, which adds
    // noise instead of context.
    if (cash == 0 && investments == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _Tile(
              label: 'Total Balance',
              amount: cash,
              symbol: symbol,
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsView()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              label: 'Investments',
              amount: investments,
              symbol: symbol,
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF688F80),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvestmentsView()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              label: 'Net Worth',
              amount: netWorth,
              symbol: symbol,
              icon: Icons.savings_rounded,
              color: AppColors.secondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NetWorthView()),
              ),
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool emphasized;

  const _Tile({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.icon,
    required this.color,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: emphasized ? color.withValues(alpha: 0.10) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emphasized
                  ? color.withValues(alpha: 0.25)
                  : AppColors.divider.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$symbol${_compact(amount)}',
                  style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact currency formatting that fits in a narrow tile without
  /// truncating big numbers. Negatives keep their sign so an overdrawn cash
  /// position is still legible.
  String _compact(double v) {
    final abs = v.abs();
    String body;
    if (abs >= 10000000) {
      body = '${(v / 10000000).toStringAsFixed(2)}Cr';
    } else if (abs >= 100000) {
      body = '${(v / 100000).toStringAsFixed(2)}L';
    } else if (abs >= 1000) {
      body = v.toStringAsFixed(0);
    } else {
      body = v.toStringAsFixed(0);
    }
    return body;
  }
}

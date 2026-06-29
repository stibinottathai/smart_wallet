import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';

/// Hero balance card at the top of the dashboard — net balance, on-track /
/// overspent badge, and a progress bar of spend against income.
class BalanceHeaderCard extends StatefulWidget {
  final double balance;
  final double percent;
  final double income;
  final double expense;
  final String symbol;

  /// When true, shows a "Tap for monthly details" cue at the bottom so users
  /// know the card is tappable (used on the dashboard).
  final bool showDetailsHint;

  const BalanceHeaderCard({
    super.key,
    required this.balance,
    required this.percent,
    required this.income,
    required this.expense,
    required this.symbol,
    this.showDetailsHint = false,
  });

  @override
  State<BalanceHeaderCard> createState() => _BalanceHeaderCardState();
}

class _BalanceHeaderCardState extends State<BalanceHeaderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progress;
  late Animation<double> _balanceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _progress = Tween<double>(begin: 0.0, end: widget.percent.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _balanceAnimation = Tween<double>(begin: 0.0, end: widget.balance)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    // Start after the first frame so the fill plays as the card settles in
    // (not while it's still hidden behind the entrance animation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant BalanceHeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smoothly re-animate to the new value when the data/month changes
    // (e.g. swiping between months on the Balance Details page).
    if (oldWidget.percent != widget.percent || oldWidget.balance != widget.balance) {
      _progress = Tween<double>(
        begin: _progress.value,
        end: widget.percent.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      
      _balanceAnimation = Tween<double>(
        begin: _balanceAnimation.value,
        end: widget.balance,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.balance;
    final percent = widget.percent;
    final income = widget.income;
    final expense = widget.expense;
    final symbol = widget.symbol;
    final showDetailsHint = widget.showDetailsHint;

    final isPositive = balance >= 0;
    final displayPercent = income > 0 ? (expense / income) : (expense > 0 ? 1.0 : 0.0);

    final String percentText;
    if (income > 0) {
      percentText = 'Spent ${(displayPercent * 100).toStringAsFixed(0)}% of income';
    } else if (expense > 0) {
      percentText = 'Spent with no income';
    } else {
      percentText = 'No spending activity';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2F6F5E),
              Color(0xFF1E463C),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'NET BALANCE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.secondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPositive
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.secondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: isPositive ? Colors.white : AppColors.secondaryLight,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPositive ? 'On Track' : 'Overspent',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Colors.white : AppColors.secondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _balanceAnimation,
                builder: (context, _) => Text(
                  '$symbol${_balanceAnimation.value.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        percentText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$symbol${expense.toStringAsFixed(0)} / $symbol${income.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percent > 0.8
                              ? AppColors.secondary
                              : const Color(0xFFD4E8E2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showDetailsHint) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap for monthly details',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'investment_form_dialog.dart';

/// Investment portfolio screen — total invested vs current value, per-holding
/// gain/loss, grouped into active and closed positions. Modelled on the
/// debts / savings-goals views so it feels native.
class InvestmentsView extends ConsumerWidget {
  const InvestmentsView({super.key});

  void _openForm(BuildContext context, {domain.Investment? investment}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvestmentFormDialog(initialInvestment: investment),
    );
  }

  Future<void> _updateValue(
    BuildContext context,
    WidgetRef ref,
    domain.Investment inv,
    String symbol,
  ) async {
    final ctrl = TextEditingController(text: inv.currentValue.toStringAsFixed(2));
    final newValue = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Update current value', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invested: $symbol${inv.investedAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Current value', prefixText: '$symbol '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newValue == null || newValue < 0) return;
    await ref.read(investmentRepositoryProvider).updateInvestment(
          inv.copyWith(currentValue: newValue, lastValueUpdate: DateTime.now()),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${inv.name} to $symbol${newValue.toStringAsFixed(2)}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Investments',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'investments_fab',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: investmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (investments) {
          if (investments.isEmpty) return _empty(context);

          final active = investments.where((i) => !i.isClosed).toList();
          final closed = investments.where((i) => i.isClosed).toList();

          final totalInvested =
              active.fold<double>(0, (s, i) => s + i.investedAmount);
          final totalCurrent =
              active.fold<double>(0, (s, i) => s + i.currentValue);

          // Group active holdings by type for a clean visual breakdown.
          final byType = <domain.InvestmentType, List<domain.Investment>>{};
          for (final inv in active) {
            byType.putIfAbsent(inv.type, () => []).add(inv);
          }
          final orderedTypes = byType.keys.toList()
            ..sort((a, b) =>
                byType[b]!.fold<double>(0, (s, i) => s + i.currentValue)
                    .compareTo(byType[a]!.fold<double>(0, (s, i) => s + i.currentValue)));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              _PortfolioCard(
                invested: totalInvested,
                current: totalCurrent,
                symbol: symbol,
                holdingsCount: active.length,
              ),
              const SizedBox(height: 18),
              if (active.isNotEmpty) ...[
                for (final type in orderedTypes) ...[
                  _label(type.displayName.toUpperCase()),
                  const SizedBox(height: 8),
                  ...byType[type]!.map((i) => _InvestmentTile(
                        investment: i,
                        symbol: symbol,
                        onTap: () => _openForm(context, investment: i),
                        onUpdateValue: () => _updateValue(context, ref, i, symbol),
                      )),
                  const SizedBox(height: 14),
                ],
              ],
              if (closed.isNotEmpty) ...[
                _label('CLOSED'),
                const SizedBox(height: 8),
                ...closed.map((i) => _InvestmentTile(
                      investment: i,
                      symbol: symbol,
                      onTap: () => _openForm(context, investment: i),
                      onUpdateValue: null,
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
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.text.withValues(alpha: 0.5),
          letterSpacing: 0.6,
        ),
      );

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.trending_up_rounded,
                    size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('No investments yet',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text(
                'Track stocks, mutual funds, FDs, gold, crypto and more — see your cost vs current value and overall return at a glance.',
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
                child: const Text('Add an investment',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
}

class _PortfolioCard extends StatelessWidget {
  final double invested;
  final double current;
  final String symbol;
  final int holdingsCount;

  const _PortfolioCard({
    required this.invested,
    required this.current,
    required this.symbol,
    required this.holdingsCount,
  });

  @override
  Widget build(BuildContext context) {
    final gain = current - invested;
    final pct = invested > 0 ? (gain / invested) * 100 : 0.0;
    final isPositive = gain >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPositive
              ? const [Color(0xFF2F6F5E), Color(0xFF1E463C)]
              : const [Color(0xFFB5634A), Color(0xFF7A3F2D)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PORTFOLIO VALUE',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${current.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}$symbol${gain.toStringAsFixed(2)} (${pct.toStringAsFixed(2)}%)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Invested', '$symbol${invested.toStringAsFixed(0)}'),
              _stat('Holdings', '$holdingsCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );
}

class _InvestmentTile extends StatelessWidget {
  final domain.Investment investment;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback? onUpdateValue;

  const _InvestmentTile({
    required this.investment,
    required this.symbol,
    required this.onTap,
    required this.onUpdateValue,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(investment.color.replaceAll('#', '0xFF')));
    final gain = investment.gainLoss;
    final pct = investment.returnRatio * 100;
    final isPositive = gain >= 0;
    final gainColor = isPositive ? AppColors.primary : AppColors.secondary;

    final meta = <String>[];
    if (investment.platform != null && investment.platform!.isNotEmpty) {
      meta.add(investment.platform!);
    }
    if (investment.units != null) {
      meta.add('${_fmtUnits(investment.units!)} units');
    }
    if (investment.lastValueUpdate != null) {
      meta.add('updated ${DateFormat('MMM d').format(investment.lastValueUpdate!)}');
    } else {
      meta.add('bought ${DateFormat('MMM d, yyyy').format(investment.purchaseDate)}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconForType(investment.type),
                          size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  investment.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      color: AppColors.text),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (investment.isClosed) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.text.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Closed',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text
                                              .withValues(alpha: 0.55))),
                                ),
                              ],
                            ],
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(meta.join(' • '),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$symbol${investment.currentValue.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text),
                        ),
                        Text(
                          '${isPositive ? '+' : ''}${pct.toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: gainColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invested $symbol${investment.investedAmount.toStringAsFixed(2)}  •  ${isPositive ? '+' : ''}$symbol${gain.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    if (onUpdateValue != null)
                      GestureDetector(
                        onTap: onUpdateValue,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded,
                                  size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Update value',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ],
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

  String _fmtUnits(double units) {
    if (units == units.truncate()) return units.toStringAsFixed(0);
    return units.toStringAsFixed(units < 1 ? 4 : 2);
  }

  IconData _iconForType(domain.InvestmentType type) {
    switch (type) {
      case domain.InvestmentType.stocks:
        return Icons.show_chart_rounded;
      case domain.InvestmentType.mutualFund:
        return Icons.pie_chart_rounded;
      case domain.InvestmentType.etf:
        return Icons.donut_large_rounded;
      case domain.InvestmentType.fixedDeposit:
        return Icons.lock_clock_rounded;
      case domain.InvestmentType.recurringDeposit:
        return Icons.event_repeat_rounded;
      case domain.InvestmentType.bonds:
        return Icons.receipt_long_rounded;
      case domain.InvestmentType.gold:
        return Icons.workspace_premium_rounded;
      case domain.InvestmentType.crypto:
        return Icons.currency_bitcoin_rounded;
      case domain.InvestmentType.realEstate:
        return Icons.home_work_rounded;
      case domain.InvestmentType.ppf:
        return Icons.savings_rounded;
      case domain.InvestmentType.nps:
        return Icons.account_balance_rounded;
      case domain.InvestmentType.other:
        return Icons.trending_up_rounded;
    }
  }
}

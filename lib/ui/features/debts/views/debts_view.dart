import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'debt_form_dialog.dart';

/// Tracks money borrowed (you owe) and lent (owed to you) with payoff progress,
/// modelled on the savings-goals screen.
class DebtsView extends ConsumerWidget {
  const DebtsView({super.key});

  void _openForm(BuildContext context, {domain.Debt? debt}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DebtFormDialog(initialDebt: debt),
    );
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, domain.Debt debt, String symbol) async {
    final ctrl = TextEditingController();
    final isBorrowed = debt.type == domain.DebtType.borrowed;
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(isBorrowed ? 'Record payment' : 'Record received', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding: $symbol${debt.remaining.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount', prefixText: '$symbol '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (debt.remaining > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, debt.remaining),
              child: const Text('Pay off fully'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    var newPaid = debt.paidAmount + amount;
    if (newPaid > debt.principalAmount) newPaid = debt.principalAmount;
    await ref.read(debtRepositoryProvider).updateDebt(
          debt.copyWith(paidAmount: newPaid, isClosed: newPaid >= debt.principalAmount),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorded $symbol${amount.toStringAsFixed(0)} toward ${debt.name}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(allDebtsProvider);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text('Debts & Loans',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'debts_fab',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (debts) {
          if (debts.isEmpty) return _empty(context);

          final active = debts.where((d) => !d.isSettled).toList();
          final settled = debts.where((d) => d.isSettled).toList();
          final owe = active.where((d) => d.type == domain.DebtType.borrowed).toList();
          final lent = active.where((d) => d.type == domain.DebtType.lent).toList();

          final totalOwe = owe.fold<double>(0, (s, d) => s + d.remaining);
          final totalLent = lent.fold<double>(0, (s, d) => s + d.remaining);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              _SummaryCard(totalOwe: totalOwe, totalLent: totalLent, symbol: symbol),
              const SizedBox(height: 18),
              if (owe.isNotEmpty) ...[
                _label('You owe'),
                const SizedBox(height: 8),
                ...owe.map((d) => _DebtTile(
                      debt: d,
                      symbol: symbol,
                      onTap: () => _openForm(context, debt: d),
                      onPay: () => _recordPayment(context, ref, d, symbol),
                    )),
              ],
              if (lent.isNotEmpty) ...[
                const SizedBox(height: 16),
                _label('Owed to you'),
                const SizedBox(height: 8),
                ...lent.map((d) => _DebtTile(
                      debt: d,
                      symbol: symbol,
                      onTap: () => _openForm(context, debt: d),
                      onPay: () => _recordPayment(context, ref, d, symbol),
                    )),
              ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: 16),
                _label('Settled'),
                const SizedBox(height: 8),
                ...settled.map((d) => _DebtTile(
                      debt: d,
                      symbol: symbol,
                      onTap: () => _openForm(context, debt: d),
                      onPay: null,
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

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.handshake_rounded, size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('No debts or loans yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text(
                'Track money you owe (loans, EMIs) and money others owe you, and watch the payoff progress.',
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
                child: const Text('Add a debt or loan', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final double totalOwe;
  final double totalLent;
  final String symbol;

  const _SummaryCard({required this.totalOwe, required this.totalLent, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final net = totalLent - totalOwe;
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
            net >= 0 ? 'NET POSITION (OWED TO YOU)' : 'NET POSITION (YOU OWE)',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${net.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('You owe', '$symbol${totalOwe.toStringAsFixed(0)}'),
              _stat('Owed to you', '$symbol${totalLent.toStringAsFixed(0)}'),
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
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );
}

class _DebtTile extends StatelessWidget {
  final domain.Debt debt;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  const _DebtTile({required this.debt, required this.symbol, required this.onTap, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(debt.color.replaceAll('#', '0xFF')));
    final settled = debt.isSettled;
    final meta = <String>[];
    if (debt.counterparty != null && debt.counterparty!.isNotEmpty) meta.add(debt.counterparty!);
    if (debt.emiAmount != null) meta.add('EMI $symbol${debt.emiAmount!.toStringAsFixed(0)}');
    if (debt.interestRate != null) meta.add('${debt.interestRate!.toStringAsFixed(debt.interestRate! % 1 == 0 ? 0 : 1)}%');
    if (debt.dueDate != null) meta.add('due ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}');

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  debt.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.text),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (settled) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Settled',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ),
                              ],
                            ],
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(meta.join(' • '),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                          '$symbol${debt.remaining.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: color),
                        ),
                        Text(settled ? 'cleared' : 'left',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: debt.progress,
                    minHeight: 7,
                    backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$symbol${debt.paidAmount.toStringAsFixed(0)} of $symbol${debt.principalAmount.toStringAsFixed(0)} • ${(debt.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    if (onPay != null)
                      GestureDetector(
                        onTap: onPay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                debt.type == domain.DebtType.borrowed ? 'Payment' : 'Received',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
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
}

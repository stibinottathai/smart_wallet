import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'account_form_dialog.dart';
import 'transfer_form_dialog.dart';

class AccountsView extends ConsumerWidget {
  const AccountsView({super.key});

  void _openAccountForm(BuildContext context, {domain.Account? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountFormDialog(initialAccount: account),
    );
  }

  void _openTransferForm(BuildContext context, {domain.Transfer? transfer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferFormDialog(initialTransfer: transfer),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final balances = ref.watch(accountBalancesProvider);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accounts',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text),
        ),
        actions: [
          IconButton(
            tooltip: 'New transfer',
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
            onPressed: () => _openTransferForm(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'accounts_fab',
        onPressed: () => _openAccountForm(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (accounts) {
          // The 'acc_investments' system wallet is auto-managed by the
          // Investments module — hide it here so it doesn't look like a
          // regular account the user can rename / delete / move money into.
          final active = accounts
              .where((a) => !a.archived && a.id != 'acc_investments')
              .toList();
          final archived = accounts.where((a) => a.archived).toList();
          final total = active.fold<double>(0, (s, a) => s + (balances[a.id] ?? 0));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _TotalCard(total: total, symbol: symbol, accountCount: active.length),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Your Accounts'),
              const SizedBox(height: 8),
              if (active.isEmpty)
                _EmptyHint(text: 'No accounts yet. Tap + to add one.')
              else
                ...active.map((a) => _AccountTile(
                      account: a,
                      balance: balances[a.id] ?? 0,
                      symbol: symbol,
                      onTap: () => _openAccountForm(context, account: a),
                    )),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionLabel(label: 'Archived'),
                const SizedBox(height: 8),
                ...archived.map((a) => _AccountTile(
                      account: a,
                      balance: balances[a.id] ?? 0,
                      symbol: symbol,
                      onTap: () => _openAccountForm(context, account: a),
                    )),
              ],
              const SizedBox(height: 24),
              _SectionLabel(label: 'Recent Transfers'),
              const SizedBox(height: 8),
              _TransfersList(
                accounts: accounts,
                symbol: symbol,
                onTap: (t) => _openTransferForm(context, transfer: t),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final String symbol;
  final int accountCount;

  const _TotalCard({required this.total, required this.symbol, required this.accountCount});

  @override
  Widget build(BuildContext context) {
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
            'TOTAL BALANCE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$symbol${total.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Across $accountCount account${accountCount == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final domain.Account account;
  final double balance;
  final String symbol;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.balance,
    required this.symbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(account.color.replaceAll('#', '0xFF')));
    final negative = balance < 0;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(getAccountIcon(account.type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            account.type.displayName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (account.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 9, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Default',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$symbol${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: negative ? AppColors.secondary : AppColors.text,
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

class _TransfersList extends ConsumerWidget {
  final List<domain.Account> accounts;
  final String symbol;
  final ValueChanged<domain.Transfer> onTap;

  const _TransfersList({required this.accounts, required this.symbol, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(allTransfersProvider);
    final nameById = {for (final a in accounts) a.id: a.name};

    return transfersAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (err, _) => Text('$err', style: const TextStyle(color: AppColors.error)),
      data: (transfers) {
        if (transfers.isEmpty) {
          return _EmptyHint(text: 'No transfers yet. Tap the ⇄ icon to move money between accounts.');
        }
        final sorted = List<domain.Transfer>.from(transfers)..sort((a, b) => b.date.compareTo(a.date));
        final shown = sorted.take(10).toList();
        return Column(
          children: shown.map((t) {
            final from = nameById[t.fromAccountId] ?? 'Unknown';
            final to = nameById[t.toAccountId] ?? 'Unknown';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTap(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$from → $to',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.text),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM d, yyyy').format(t.date),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$symbol${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.text.withValues(alpha: 0.5),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

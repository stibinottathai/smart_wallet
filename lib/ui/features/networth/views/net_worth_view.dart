import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Row {
  final String name;
  final String? subtitle;
  final double amount;
  final double? progress;
  final IconData icon;
  final Color color;

  const _Row({
    required this.name,
    this.subtitle,
    required this.amount,
    this.progress,
    required this.icon,
    required this.color,
  });
}

String _accountTypeLabel(domain.AccountType type) {
  switch (type) {
    case domain.AccountType.cash:
      return 'Cash';
    case domain.AccountType.bank:
      return 'Bank Account';
    case domain.AccountType.card:
      return 'Credit / Debit Card';
    case domain.AccountType.upi:
      return 'UPI';
    case domain.AccountType.wallet:
      return 'Wallet';
    case domain.AccountType.other:
      return 'Other';
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────

class NetWorthView extends ConsumerWidget {
  const NetWorthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final debtsAsync = ref.watch(allDebtsProvider);
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final balances = ref.watch(accountBalancesProvider);
    final code = ref.watch(currencyCodeProvider);
    final sym = currencySymbol(code);
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    if (accountsAsync.isLoading || debtsAsync.isLoading || investmentsAsync.isLoading) {
      return const Scaffold(
        appBar: _NetWorthAppBar(),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // The 'acc_investments' system wallet holds cost basis of holdings — we
    // exclude it from cash assets and surface investments separately at their
    // **current value** so unrealized gains are reflected in net worth.
    final accounts = (accountsAsync.value ?? [])
        .where((a) => !a.archived && a.id != 'acc_investments')
        .toList();
    final debts = debtsAsync.value ?? [];
    final investments = (investmentsAsync.value ?? []).where((i) => !i.isClosed).toList();

    // Positive-balance accounts → cash assets
    final accountAssetRows = <_Row>[];
    double totalAccountAssets = 0;
    for (final acc in accounts) {
      final bal = balances[acc.id] ?? 0;
      if (bal > 0) {
        totalAccountAssets += bal;
        accountAssetRows.add(_Row(
          name: acc.name,
          subtitle: _accountTypeLabel(acc.type),
          amount: bal,
          icon: getAccountIcon(acc.type),
          color: Color(int.parse(acc.color.replaceAll('#', '0xFF'))),
        ));
      }
    }

    // Active investments → asset rows at current market value
    final investmentRows = <_Row>[];
    double totalInvestmentAssets = 0;
    for (final inv in investments) {
      totalInvestmentAssets += inv.currentValue;
      final gain = inv.gainLoss;
      final pct = inv.returnRatio * 100;
      final gainLabel = gain == 0
          ? inv.type.displayName
          : '${inv.type.displayName} • ${gain >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
      investmentRows.add(_Row(
        name: inv.name,
        subtitle: gainLabel,
        amount: inv.currentValue,
        icon: Icons.trending_up_rounded,
        color: Color(int.parse(inv.color.replaceAll('#', '0xFF'))),
      ));
    }

    // Lent debts (money owed to you) → assets
    final lentRows = <_Row>[];
    double totalLentAssets = 0;
    for (final d in debts.where((d) => d.type == domain.DebtType.lent && !d.isSettled)) {
      totalLentAssets += d.remaining;
      lentRows.add(_Row(
        name: d.name,
        subtitle: d.counterparty != null ? 'Owed by ${d.counterparty}' : null,
        amount: d.remaining,
        progress: d.progress,
        icon: Icons.handshake_rounded,
        color: AppColors.primary,
      ));
    }

    // Borrowed debts (money you owe) → liabilities
    final borrowedRows = <_Row>[];
    double totalBorrowed = 0;
    for (final d in debts.where((d) => d.type == domain.DebtType.borrowed && !d.isSettled)) {
      totalBorrowed += d.remaining;
      borrowedRows.add(_Row(
        name: d.name,
        subtitle: d.counterparty != null ? 'Owed to ${d.counterparty}' : null,
        amount: d.remaining,
        progress: d.progress,
        icon: Icons.receipt_long_rounded,
        color: AppColors.secondary,
      ));
    }

    // Negative-balance accounts (overdrafts / credit used) → liabilities
    final overdraftRows = <_Row>[];
    double totalOverdraft = 0;
    for (final acc in accounts) {
      final bal = balances[acc.id] ?? 0;
      if (bal < 0) {
        totalOverdraft += bal.abs();
        overdraftRows.add(_Row(
          name: acc.name,
          subtitle: 'Overdraft / credit used',
          amount: bal.abs(),
          icon: getAccountIcon(acc.type),
          color: Color(int.parse(acc.color.replaceAll('#', '0xFF'))),
        ));
      }
    }

    final totalAssets = totalAccountAssets + totalInvestmentAssets + totalLentAssets;
    final totalLiabilities = totalBorrowed + totalOverdraft;
    final netWorth = totalAssets - totalLiabilities;

    String fmtAmt(double v) => '$sym${fmt.format(v.round())}';

    return Scaffold(
      appBar: const _NetWorthAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(netWorth: netWorth, fmtAmt: fmtAmt),
            const SizedBox(height: 14),
            _ChartCard(
              totalAssets: totalAssets,
              totalLiabilities: totalLiabilities,
              fmtAmt: fmtAmt,
            ),
            const SizedBox(height: 22),

            // ── Assets ──────────────────────────────────────────────────────
            _SectionHeader(
              label: 'Assets',
              total: fmtAmt(totalAssets),
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            if (accountAssetRows.isEmpty && investmentRows.isEmpty && lentRows.isEmpty)
              _EmptyCard('No accounts, investments or lending records yet')
            else ...[
              if (accountAssetRows.isNotEmpty) ...[
                _GroupLabel('Accounts & Wallets'),
                const SizedBox(height: 4),
                ...accountAssetRows.map((r) => _ItemRow(row: r, fmtAmt: fmtAmt, isAsset: true)),
              ],
              if (investmentRows.isNotEmpty) ...[
                if (accountAssetRows.isNotEmpty) const SizedBox(height: 10),
                _GroupLabel('Investments (current value)'),
                const SizedBox(height: 4),
                ...investmentRows.map((r) => _ItemRow(row: r, fmtAmt: fmtAmt, isAsset: true)),
              ],
              if (lentRows.isNotEmpty) ...[
                if (accountAssetRows.isNotEmpty || investmentRows.isNotEmpty)
                  const SizedBox(height: 10),
                _GroupLabel("Amounts You'll Receive"),
                const SizedBox(height: 4),
                ...lentRows.map((r) => _ItemRow(row: r, fmtAmt: fmtAmt, isAsset: true)),
              ],
            ],

            const SizedBox(height: 22),

            // ── Liabilities ─────────────────────────────────────────────────
            _SectionHeader(
              label: 'Liabilities',
              total: fmtAmt(totalLiabilities),
              color: AppColors.secondary,
            ),
            const SizedBox(height: 10),
            if (borrowedRows.isEmpty && overdraftRows.isEmpty)
              _EmptyCard('No outstanding debts — well done!')
            else ...[
              if (borrowedRows.isNotEmpty) ...[
                _GroupLabel('Loans & Debts'),
                const SizedBox(height: 4),
                ...borrowedRows.map((r) => _ItemRow(row: r, fmtAmt: fmtAmt, isAsset: false)),
              ],
              if (overdraftRows.isNotEmpty) ...[
                if (borrowedRows.isNotEmpty) const SizedBox(height: 10),
                _GroupLabel('Overdrafts'),
                const SizedBox(height: 4),
                ...overdraftRows.map((r) => _ItemRow(row: r, fmtAmt: fmtAmt, isAsset: false)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _NetWorthAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NetWorthAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Net Worth'));
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double netWorth;
  final String Function(double) fmtAmt;

  const _SummaryCard({required this.netWorth, required this.fmtAmt});

  @override
  Widget build(BuildContext context) {
    final positive = netWorth >= 0;
    final color = positive ? AppColors.primary : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            'Net Worth',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              (positive ? '' : '−') + fmtAmt(netWorth.abs()),
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            positive
                ? 'Your assets exceed your liabilities'
                : 'You owe more than you own',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'As of today',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Donut chart + stat chips ─────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final double totalAssets;
  final double totalLiabilities;
  final String Function(double) fmtAmt;

  const _ChartCard({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.fmtAmt,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = totalAssets + totalLiabilities > 0;
    final sections = hasData
        ? [
            if (totalAssets > 0)
              PieChartSectionData(
                value: totalAssets,
                color: AppColors.primary,
                radius: 28,
                showTitle: false,
              ),
            if (totalLiabilities > 0)
              PieChartSectionData(
                value: totalLiabilities,
                color: AppColors.secondary,
                radius: 28,
                showTitle: false,
              ),
          ]
        : [
            PieChartSectionData(
              value: 1,
              color: AppColors.divider,
              radius: 28,
              showTitle: false,
            ),
          ];

    // Liability-to-total ratio label
    String ratioLabel = '';
    if (hasData && totalLiabilities > 0) {
      final pct = (totalLiabilities / (totalAssets + totalLiabilities) * 100).round();
      ratioLabel = '$pct% liabilities';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 38,
                sectionsSpace: hasData ? 3 : 0,
                startDegreeOffset: -90,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stat(
                  label: 'Total Assets',
                  value: fmtAmt(totalAssets),
                  color: AppColors.primary,
                ),
                const SizedBox(height: 14),
                _Stat(
                  label: 'Total Liabilities',
                  value: fmtAmt(totalLiabilities),
                  color: AppColors.secondary,
                ),
                if (ratioLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    ratioLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (hasData) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Dot(AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Assets', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const SizedBox(width: 10),
                      _Dot(AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('Liabilities', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String total;
  final Color color;

  const _SectionHeader({required this.label, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
        Text(
          total,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Group label ──────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            letterSpacing: 0.6,
          ),
        ),
      );
}

// ─── Empty card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
}

// ─── Item row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _Row row;
  final String Function(double) fmtAmt;
  final bool isAsset;

  const _ItemRow({required this.row, required this.fmtAmt, required this.isAsset});

  @override
  Widget build(BuildContext context) {
    final accentColor = isAsset ? AppColors.primary : AppColors.secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: row.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(row.icon, size: 19, color: row.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                    if (row.subtitle != null)
                      Text(
                        row.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                fmtAmt(row.amount),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          if (row.progress != null) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: row.progress,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(row.progress! * 100).toStringAsFixed(0)}% repaid',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

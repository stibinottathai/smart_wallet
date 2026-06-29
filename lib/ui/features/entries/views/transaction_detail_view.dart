import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';

/// Read-only detail screen for a single transaction (expense or income).
/// Tapping a transaction in a list opens this; the Edit button here opens the
/// editable [EntryFormView].
class TransactionDetailView extends ConsumerWidget {
  final domain.Expense? initialExpense;
  final domain.Income? initialIncome;

  const TransactionDetailView({
    super.key,
    this.initialExpense,
    this.initialIncome,
  }) : assert(initialExpense != null || initialIncome != null,
            'A transaction must be provided');

  bool get _isExpense => initialExpense != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-read the entry from its provider so edits made on the form screen are
    // reflected here when we return. Fall back to the passed-in snapshot if it
    // can no longer be found (e.g. it was deleted).
    if (_isExpense) {
      final expenses = ref.watch(allExpensesProvider).value;
      final expense = expenses?.firstWhere(
            (e) => e.id == initialExpense!.id,
            orElse: () => initialExpense!,
          ) ??
          initialExpense!;
      return _buildExpense(context, ref, expense);
    } else {
      final incomes = ref.watch(allIncomesProvider).value;
      final income = incomes?.firstWhere(
            (i) => i.id == initialIncome!.id,
            orElse: () => initialIncome!,
          ) ??
          initialIncome!;
      return _buildIncome(context, ref, income);
    }
  }

  Widget _buildExpense(BuildContext context, WidgetRef ref, domain.Expense expense) {
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final category = categories.cast<domain.Category?>().firstWhere(
          (c) => c?.id == expense.categoryId,
          orElse: () => null,
        );
    final account = _accountFor(ref, expense.accountId);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    final catColor = Color(int.parse((category?.color ?? '#9E9E9E').replaceAll('#', '0xFF')));

    return _scaffold(
      context: context,
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EntryFormView(initialExpense: expense)),
        );
      },
      onDelete: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final confirmed = await showDeleteConfirmationDialog(
          context: context,
          itemType: 'expense',
        );
        if (!confirmed) return;
        await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
      },
      header: _amountHeader(
        icon: getCategoryIcon(category?.icon),
        iconColor: catColor,
        title: category?.name ?? 'Uncategorized',
        amountText: '-$symbol${expense.amount.toStringAsFixed(2)}',
        amountColor: AppColors.secondary,
        subtitle: 'Expense',
      ),
      rows: [
        if (expense.isForeign)
          _DetailRow(
            icon: Icons.currency_exchange_rounded,
            label: 'Original amount',
            value:
                '${currencySymbol(expense.originalCurrency!)}${expense.originalAmount!.toStringAsFixed(2)} ${expense.originalCurrency}',
          ),
        _DetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Date',
          value: DateFormat('EEEE, MMM d, yyyy').format(expense.date),
        ),
        if (account != null)
          _DetailRow(
            icon: getAccountIcon(account.type),
            label: 'Account',
            value: account.name,
            valueColor: Color(int.parse(account.color.replaceAll('#', '0xFF'))),
          ),
        _DetailRow(
          icon: Icons.label_outline_rounded,
          label: 'Category',
          value: category?.name ?? 'Uncategorized',
        ),
        if (expense.note != null && expense.note!.isNotEmpty)
          _DetailRow(
            icon: Icons.notes_rounded,
            label: 'Note',
            value: expense.note!,
          ),
        _DetailRow(
          icon: expense.source == domain.ExpenseSource.aiScan
              ? Icons.auto_awesome_rounded
              : Icons.edit_note_rounded,
          label: 'Entry type',
          value: expense.source == domain.ExpenseSource.aiScan ? 'Scanned receipt (AI)' : 'Manual entry',
        ),
      ],
      receiptImagePath: expense.receiptImagePath,
    );
  }

  Widget _buildIncome(BuildContext context, WidgetRef ref, domain.Income income) {
    final account = _accountFor(ref, income.accountId);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return _scaffold(
      context: context,
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EntryFormView(initialIncome: income)),
        );
      },
      onDelete: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final confirmed = await showDeleteConfirmationDialog(
          context: context,
          itemType: 'income',
        );
        if (!confirmed) return;
        await ref.read(incomeRepositoryProvider).deleteIncome(income.id);
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Income deleted')));
      },
      header: _amountHeader(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.primary,
        title: income.source,
        amountText: '+$symbol${income.amount.toStringAsFixed(2)}',
        amountColor: AppColors.primary,
        subtitle: 'Income',
      ),
      rows: [
        if (income.isForeign)
          _DetailRow(
            icon: Icons.currency_exchange_rounded,
            label: 'Original amount',
            value:
                '${currencySymbol(income.originalCurrency!)}${income.originalAmount!.toStringAsFixed(2)} ${income.originalCurrency}',
          ),
        _DetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Date',
          value: DateFormat('EEEE, MMM d, yyyy').format(income.date),
        ),
        if (account != null)
          _DetailRow(
            icon: getAccountIcon(account.type),
            label: 'Account',
            value: account.name,
            valueColor: Color(int.parse(account.color.replaceAll('#', '0xFF'))),
          ),
        _DetailRow(
          icon: Icons.source_rounded,
          label: 'Source',
          value: income.source,
        ),
        if (income.isRecurring)
          _DetailRow(
            icon: Icons.repeat_rounded,
            label: 'Recurring',
            value: income.frequency.displayName,
          ),
      ],
      receiptImagePath: null,
    );
  }

  // ---- shared layout ----

  Widget _scaffold({
    required BuildContext context,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required Widget header,
    required List<Widget> rows,
    required String? receiptImagePath,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Transaction Details',
          style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary),
            onPressed: onDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
                    rows[i],
                  ],
                ],
              ),
            ),
            if (receiptImagePath != null && File(receiptImagePath).existsSync()) ...[
              const SizedBox(height: 24),
              const Text(
                'Receipt',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(receiptImagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amountText,
    required Color amountColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            style: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w700, color: amountColor),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Resolves the account a transaction belongs to. A null [accountId] (legacy
/// data) falls back to the default account so something sensible still shows.
domain.Account? _accountFor(WidgetRef ref, String? accountId) {
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  if (accounts.isEmpty) return null;
  final id = accountId ?? defaultAccountId;
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

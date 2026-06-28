import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'bill_form_dialog.dart';

/// Read-only detail screen for a bill / subscription. Tapping a bill tile opens
/// this; Edit opens the [BillFormDialog], Delete removes it after confirmation.
class BillDetailView extends ConsumerWidget {
  final domain.Bill initialBill;

  const BillDetailView({super.key, required this.initialBill});

  String _dueLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Overdue by 1 day';
    if (diff < -1) return 'Overdue by ${-diff} days';
    return 'Due in $diff days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-read from the provider so edits reflect here; if the bill was deleted
    // (here or from the edit form) close this screen automatically.
    final bills = ref.watch(allBillsProvider).value;
    final bill = bills == null
        ? initialBill
        : bills.cast<domain.Bill?>().firstWhere(
              (b) => b?.id == initialBill.id,
              orElse: () => null,
            );
    if (bill == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    final symbol = currencySymbol(ref.watch(currencyCodeProvider));
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final category = categories.cast<domain.Category?>().firstWhere(
          (c) => c?.id == bill.categoryId,
          orElse: () => null,
        );
    final catColor = Color(int.parse((category?.color ?? '#9E9E9E').replaceAll('#', '0xFF')));
    final isOverdue = bill.dueDate.isBefore(DateTime.now()) &&
        !DateUtils.isSameDay(bill.dueDate, DateTime.now()) &&
        !bill.isPaid;

    void onEdit() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BillFormDialog(initialBill: bill),
      );
    }

    Future<void> onDelete() async {
      final confirmed = await showDeleteConfirmationDialog(
        context: context,
        itemType: 'bill',
      );
      if (!confirmed) return;
      await ref.read(billRepositoryProvider).deleteBill(bill.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Bill Details',
          style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: onEdit,
          ),
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
            // Header card.
            Container(
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
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(getCategoryIcon(category?.icon), color: catColor, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    bill.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$symbol${bill.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.frequency.displayName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Due date',
                    value: DateFormat('EEE, MMM d, yyyy').format(bill.dueDate),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Status',
                    value: bill.isPaid ? 'Paid' : _dueLabel(bill.dueDate),
                    valueColor: bill.isPaid
                        ? AppColors.primary
                        : (isOverdue ? AppColors.secondary : null),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.repeat_rounded,
                    label: 'Frequency',
                    value: bill.frequency.displayName,
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.label_outline_rounded,
                    label: 'Category',
                    value: category?.name ?? 'Uncategorized',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete Bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5));
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
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
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

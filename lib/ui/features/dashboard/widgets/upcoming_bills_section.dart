import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:uuid/uuid.dart';
import '../views/bill_form_dialog.dart';
import '../views/bills_view.dart';
import 'section_header.dart';

/// Up-to-two upcoming (unpaid) bills with a quick "Pay Now" action.
class UpcomingBillsSection extends ConsumerWidget {
  final List<domain.Bill> bills;
  final Map<String, domain.Category> categoryMap;
  final String symbol;

  const UpcomingBillsSection({
    super.key,
    required this.bills,
    required this.categoryMap,
    required this.symbol,
  });

  String _getDueDateLabel(DateTime dueDate) {
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

  Future<void> _confirmPayBill(BuildContext context, WidgetRef ref, domain.Bill bill) async {
    final code = ref.read(currencyCodeProvider);
    final sym = currencySymbol(code);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Pay Bill',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              bill.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$sym${bill.amount.toStringAsFixed(2)} — ${bill.frequency.displayName}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'An expense of $sym${bill.amount.toStringAsFixed(2)} will be logged automatically.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Pay Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _toggleBillPaid(context, ref, bill);
    }
  }

  Future<void> _toggleBillPaid(BuildContext context, WidgetRef ref, domain.Bill bill) async {
    final repo = ref.read(billRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    final now = DateTime.now();
    final categoryId = bill.categoryId ?? 'cat_uncategorized';

    final expense = domain.Expense(
      id: const Uuid().v4(),
      amount: bill.amount,
      categoryId: categoryId,
      date: now,
      note: 'Auto-logged bill payment: ${bill.name}',
      source: domain.ExpenseSource.manual,
    );
    await expenseRepo.addExpense(expense);

    // Mark current bill as paid so it disappears from upcoming section
    await repo.updateBill(bill.copyWith(isPaid: true));

    // For recurring bills, create the next occurrence
    if (bill.frequency != domain.BillFrequency.oneOff) {
      DateTime nextDueDate;
      switch (bill.frequency) {
        case domain.BillFrequency.daily:
          nextDueDate = bill.dueDate.add(const Duration(days: 1));
          break;
        case domain.BillFrequency.weekly:
          nextDueDate = bill.dueDate.add(const Duration(days: 7));
          break;
        case domain.BillFrequency.monthly:
          nextDueDate = DateTime(
            bill.dueDate.year,
            bill.dueDate.month + 1,
            bill.dueDate.day,
          );
          break;
        case domain.BillFrequency.yearly:
          nextDueDate = DateTime(
            bill.dueDate.year + 1,
            bill.dueDate.month,
            bill.dueDate.day,
          );
          break;
        case domain.BillFrequency.oneOff:
          nextDueDate = bill.dueDate;
          break;
      }
      await repo.addBill(
        domain.Bill(
          id: const Uuid().v4(),
          name: bill.name,
          amount: bill.amount,
          dueDate: nextDueDate,
          isPaid: false,
          frequency: bill.frequency,
          categoryId: bill.categoryId,
        ),
      );
    }

    if (context.mounted) {
      final categoryName = categoryMap[categoryId]?.name ?? 'Uncategorized';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paid! Logged ${currencySymbol(ref.read(currencyCodeProvider))}${bill.amount.toStringAsFixed(2)} expense for ${bill.name} under $categoryName.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Upcoming Bills & Subs',
            action: AddIconButton(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const BillFormDialog(),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (upcoming.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No upcoming payments',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap the plus icon to track subscriptions like Netflix, Rent, utilities, and more.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...upcoming.take(2).map((bill) {
              final cat = bill.categoryId != null ? categoryMap[bill.categoryId] : null;
              final catColorStr = cat?.color ?? '#9E9E9E';
              final catColor = Color(int.parse(catColorStr.replaceAll('#', '0xFF')));
              final iconData = getCategoryIcon(cat?.icon);
              final dueLabel = _getDueDateLabel(bill.dueDate);
              final isOverdue = bill.dueDate.isBefore(DateTime.now()) &&
                  !DateUtils.isSameDay(bill.dueDate, DateTime.now());
              final diff = bill.dueDate.difference(DateTime.now());
              final canPay = isOverdue || switch (bill.frequency) {
                domain.BillFrequency.daily => diff.inHours <= 12,
                domain.BillFrequency.weekly => diff.inDays <= 2,
                domain.BillFrequency.monthly => diff.inDays <= 10,
                domain.BillFrequency.yearly => diff.inDays <= 30,
                domain.BillFrequency.oneOff => diff.inDays <= 10,
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => BillFormDialog(initialBill: bill),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: catColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dueLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverdue ? AppColors.secondary : AppColors.textSecondary,
                                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$symbol${bill.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bill.frequency.displayName,
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (canPay) ...[
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () => _confirmPayBill(context, ref, bill),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pay Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          if (upcoming.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BillsView()),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    'View All (${upcoming.length})',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

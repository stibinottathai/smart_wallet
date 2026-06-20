import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/dashboard/views/bill_form_dialog.dart';
import 'package:uuid/uuid.dart';

class BillsView extends ConsumerStatefulWidget {
  const BillsView({super.key});

  @override
  ConsumerState<BillsView> createState() => _BillsViewState();
}

class _BillsViewState extends ConsumerState<BillsView> {
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

  bool _canPay(domain.Bill bill) {
    final isOverdue = bill.dueDate.isBefore(DateTime.now()) &&
        !DateUtils.isSameDay(bill.dueDate, DateTime.now());
    if (isOverdue) return true;
    final diff = bill.dueDate.difference(DateTime.now());
    return switch (bill.frequency) {
      domain.BillFrequency.daily   => diff.inHours <= 12,
      domain.BillFrequency.weekly  => diff.inDays <= 2,
      domain.BillFrequency.monthly => diff.inDays <= 10,
      domain.BillFrequency.yearly  => diff.inDays <= 30,
      domain.BillFrequency.oneOff  => diff.inDays <= 10,
    };
  }

  Future<void> _confirmPayBill(domain.Bill bill) async {
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
              'An expense will be logged automatically.',
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
    if (confirmed == true) {
      _toggleBillPaid(bill);
    }
  }

  void _toggleBillPaid(domain.Bill bill) async {
    final repo = ref.read(billRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final sym = currencySymbol(ref.read(currencyCodeProvider));

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

    await repo.updateBill(bill.copyWith(isPaid: true));

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paid! Logged $sym${bill.amount.toStringAsFixed(2)} expense for ${bill.name}.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(allBillsProvider).value ?? [];
    final categories = ref.watch(allCategoriesProvider).value ?? [];
    final categoryMap = {for (final c in categories) c.id: c};
    final code = ref.watch(currencyCodeProvider);
    final sym = currencySymbol(code);

    final unpaid = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(title: const Text('All Bills')),
      body: unpaid.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.text.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  const Text(
                    'No unpaid bills',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: unpaid.length,
              itemBuilder: (context, index) {
                final bill = unpaid[index];
                final cat = bill.categoryId != null ? categoryMap[bill.categoryId] : null;
                final catColorStr = cat?.color ?? '#9E9E9E';
                final catColor = Color(int.parse(catColorStr.replaceAll('#', '0xFF')));
                final iconData = cat != null ? _getCategoryIcon(cat.icon) : Icons.receipt_rounded;
                final dueLabel = _getDueDateLabel(bill.dueDate);
                final isOverdue = bill.dueDate.isBefore(DateTime.now()) &&
                    !DateUtils.isSameDay(bill.dueDate, DateTime.now());
                final canPay = _canPay(bill);

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
                                  '$sym${bill.amount.toStringAsFixed(2)}',
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
                                onPressed: () => _confirmPayBill(bill),
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
              },
            ),
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant_rounded;
      case 'shopping_cart': return Icons.shopping_cart_rounded;
      case 'directions_car': return Icons.directions_car_rounded;
      case 'home': return Icons.home_rounded;
      case 'flight': return Icons.flight_rounded;
      case 'local_hospital': return Icons.local_hospital_rounded;
      case 'school': return Icons.school_rounded;
      case 'sports_esports': return Icons.sports_esports_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      case 'music_note': return Icons.music_note_rounded;
      case 'subscriptions': return Icons.subscriptions_rounded;
      case 'electrical_services': return Icons.electrical_services_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'wifi': return Icons.wifi_rounded;
      case 'local_grocery_store': return Icons.local_grocery_store_rounded;
      case 'pets': return Icons.pets_rounded;
      case 'local_taxi': return Icons.local_taxi_rounded;
      case 'card_giftcard': return Icons.card_giftcard_rounded;
      case 'checkroom': return Icons.checkroom_rounded;
      case 'coffee': return Icons.coffee_rounded;
      case 'local_bar': return Icons.local_bar_rounded;
      default: return Icons.receipt_rounded;
    }
  }
}

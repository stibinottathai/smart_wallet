import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';

class TopSpendingDaysCard extends ConsumerWidget {
  final List<domain.Expense> expenses;
  final Map<String, domain.Category> catMap;

  const TopSpendingDaysCard({
    super.key,
    required this.expenses,
    required this.catMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final dayMap = <DateTime, List<domain.Expense>>{};
    for (final exp in expenses) {
      final day = DateTime(exp.date.year, exp.date.month, exp.date.day);
      dayMap.putIfAbsent(day, () => []);
      dayMap[day]!.add(exp);
    }

    final dayTotals = dayMap.entries.map((e) => (
      date: e.key,
      total: e.value.fold(0.0, (s, x) => s + x.amount),
      expenses: e.value,
    )).toList()..sort((a, b) => b.total.compareTo(a.total));

    final top5 = dayTotals.take(5).toList();

    if (top5.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No expenses yet', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      );
    }

    return Column(
      children: top5.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final categories = item.expenses
            .fold<Map<String, double>>({}, (map, e) {
              map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
              return map;
            })
            .entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#${i + 1}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(item.date),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: categories.take(3).map((c) {
                        final cat = catMap[c.key];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: cat != null ? Color(int.parse(cat.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.12) : AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${cat?.name ?? '?'} ${currencySymbol(code)}${c.value.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: cat != null ? Color(int.parse(cat.color.replaceAll('#', '0xFF'))) : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Text(
                '${currencySymbol(code)}${item.total.toStringAsFixed(2)}',
                style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

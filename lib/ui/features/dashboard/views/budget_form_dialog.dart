import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import '../../../core/theme.dart';
import '../../../core/currency_utils.dart';
import '../../../providers.dart';
import '../../../core/category_icons.dart';

class BudgetFormDialog extends ConsumerStatefulWidget {
  final List<domain.Category> categories;

  const BudgetFormDialog({super.key, required this.categories});

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final category in widget.categories) {
      if (category.id == 'cat_income') continue;
      
      final currentLimit = category.budgetLimit;
      _controllers[category.id] = TextEditingController(
        text: currentLimit != null && currentLimit > 0
            ? currentLimit.toStringAsFixed(0)
            : '',
      );
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _save() async {
    final repo = ref.read(expenseRepositoryProvider);
    bool hasChanges = false;

    for (final category in widget.categories) {
      if (category.id == 'cat_income') continue;

      final ctrl = _controllers[category.id];
      if (ctrl == null) continue;

      final text = ctrl.text.trim();
      final newLimit = double.tryParse(text);

      if (text.isEmpty || newLimit == null || newLimit <= 0) {
        // If it was previously set, clear it
        if (category.budgetLimit != null) {
          final updated = category.copyWith(clearBudgetLimit: true);
          await repo.updateCategory(updated);
          hasChanges = true;
        }
      } else {
        // If it changed, update it
        if (category.budgetLimit != newLimit) {
          final updated = category.copyWith(budgetLimit: newLimit);
          await repo.updateCategory(updated);
          hasChanges = true;
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      if (hasChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly budget limits updated successfully.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySym = currencySymbol(ref.watch(currencyCodeProvider));
    final expenseCategories = widget.categories
        .where((c) => c.id != 'cat_income')
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Column(
                    children: [
                      _dragHandle(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Budgets',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      Text(
                        'Set monthly spending limits for each category. Enter 0 or leave empty to disable limits.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: expenseCategories.length,
                    itemBuilder: (context, index) {
                      final category = expenseCategories[index];
                      final catColor = Color(
                        int.parse(category.color.replaceAll('#', '0xFF')),
                      );
                      final controller = _controllers[category.id];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                getCategoryIcon(category.icon),
                                color: catColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    prefixText: '$currencySym ',
                                    prefixStyle: TextStyle(
                                      color: AppColors.text.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    hintText: 'No limit',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Budgets',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

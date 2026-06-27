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
  final Map<String, bool> _rollover = {};

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
      _rollover[category.id] = category.rolloverEnabled;
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
      final rolloverOn = _rollover[category.id] ?? false;
      final hasLimit = !(text.isEmpty || newLimit == null || newLimit <= 0);

      // Rollover only makes sense with a limit set; drop it otherwise.
      final effectiveRollover = hasLimit && rolloverOn;

      if (!hasLimit) {
        // Clear the limit (and any rollover) if it was previously set.
        if (category.budgetLimit != null || category.rolloverEnabled) {
          final updated = category.copyWith(
            clearBudgetLimit: true,
            rolloverEnabled: false,
          );
          await repo.updateCategory(updated);
          hasChanges = true;
        }
      } else if (category.budgetLimit != newLimit ||
          category.rolloverEnabled != effectiveRollover) {
        final updated = category.copyWith(
          budgetLimit: newLimit,
          rolloverEnabled: effectiveRollover,
        );
        await repo.updateCategory(updated);
        hasChanges = true;
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
                        'Set monthly spending limits per category. Turn on rollover to carry unspent budget into next month. Leave empty to disable.',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                      onChanged: (_) => setState(() {}),
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
                            if ((controller?.text.trim().isNotEmpty ?? false))
                              Padding(
                                padding: const EdgeInsets.only(left: 48, top: 2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() {
                                    _rollover[category.id] = !(_rollover[category.id] ?? false);
                                  }),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 28,
                                        width: 36,
                                        child: Transform.scale(
                                          scale: 0.7,
                                          alignment: Alignment.centerLeft,
                                          child: Switch(
                                            value: _rollover[category.id] ?? false,
                                            activeThumbColor: AppColors.primary,
                                            onChanged: (v) => setState(() => _rollover[category.id] = v),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Roll over unspent budget',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
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

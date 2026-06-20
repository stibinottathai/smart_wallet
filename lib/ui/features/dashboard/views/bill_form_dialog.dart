import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import '../../../core/theme.dart';
import '../../../core/dialogs.dart';
import '../../../providers.dart';

class BillFormDialog extends ConsumerStatefulWidget {
  final domain.Bill? initialBill;

  const BillFormDialog({super.key, this.initialBill});

  @override
  ConsumerState<BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends ConsumerState<BillFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now();
  domain.BillFrequency _frequency = domain.BillFrequency.monthly;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.initialBill != null) {
      final b = widget.initialBill!;
      _nameCtrl.text = b.name;
      _amountCtrl.text = b.amount.toStringAsFixed(2);
      _dueDate = b.dueDate;
      _frequency = b.frequency;
      _selectedCategoryId = b.categoryId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.')),
      );
      return;
    }

    final repo = ref.read(billRepositoryProvider);
    final isEdit = widget.initialBill != null;

    final bill = domain.Bill(
      id: isEdit ? widget.initialBill!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      amount: amount,
      dueDate: _dueDate,
      isPaid: isEdit ? widget.initialBill!.isPaid : false,
      frequency: _frequency,
      categoryId: _selectedCategoryId,
    );

    if (isEdit) {
      await repo.updateBill(bill);
    } else {
      await repo.addBill(bill);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill/Subscription ${isEdit ? "updated" : "added"}.')),
      );
    }
  }

  void _delete() async {
    final isConfirmed = await showDeleteConfirmationDialog(
      context: context,
      itemType: 'bill/subscription',
    );

    if (!isConfirmed) return;

    if (widget.initialBill != null) {
      await ref.read(billRepositoryProvider).deleteBill(widget.initialBill!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill/Subscription deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final isEdit = widget.initialBill != null;

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Bill / Sub' : 'New Bill / Sub',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary),
                        onPressed: _delete,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Netflix, Rent, Electricity',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '\$',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(_dueDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<domain.BillFrequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                  ),
                  items: domain.BillFrequency.values.map((f) {
                    return DropdownMenuItem(value: f, child: Text(f.displayName));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _frequency = v);
                  },
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (err, _) => Text('$err', style: const TextStyle(color: AppColors.error)),
                  data: (categories) {
                    final expenseCategories = categories.where((c) => c.id != 'cat_income').toList();
                    if (_selectedCategoryId == null && expenseCategories.isNotEmpty) {
                      _selectedCategoryId = expenseCategories.first.id;
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_rounded, size: 18, color: AppColors.primary),
                      ),
                      items: expenseCategories.map((cat) {
                        final catColor = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    );
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Create Bill'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

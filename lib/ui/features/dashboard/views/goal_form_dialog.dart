import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import '../../../core/theme.dart';
import '../../../core/dialogs.dart';
import '../../../core/currency_utils.dart';
import '../../../providers.dart';

class GoalFormDialog extends ConsumerStatefulWidget {
  final domain.SavingsGoal? initialGoal;

  const GoalFormDialog({super.key, this.initialGoal});

  @override
  ConsumerState<GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends ConsumerState<GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetAmountCtrl = TextEditingController();
  final _currentAmountCtrl = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  String _selectedColor = '#2F6F5E';

  final List<String> _colors = [
    '#2F6F5E', // Deep Green
    '#B5634A', // Terracotta
    '#617C8F', // Steel Blue
    '#D39B82', // Warm Orange
    '#4F5B56', // Dark Slate
    '#688F80', // Muted Teal
    '#9C27B0', // Purple
    '#E91E63', // Pink
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGoal != null) {
      final g = widget.initialGoal!;
      _nameCtrl.text = g.name;
      _targetAmountCtrl.text = g.targetAmount.toStringAsFixed(0);
      _currentAmountCtrl.text = g.currentAmount.toStringAsFixed(0);
      _targetDate = g.targetDate;
      _selectedColor = g.color;
    } else {
      _currentAmountCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetAmountCtrl.dispose();
    _currentAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
      setState(() => _targetDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final target = double.tryParse(_targetAmountCtrl.text) ?? 0.0;
    final current = double.tryParse(_currentAmountCtrl.text) ?? 0.0;

    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target amount must be greater than 0.')),
      );
      return;
    }

    final isEdit = widget.initialGoal != null;

    if (!isEdit) {
      final existing = ref.read(allSavingsGoalsProvider).value ?? [];
      if (existing.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't add more than 3 savings goals.")),
        );
        return;
      }
    }

    final repo = ref.read(savingsGoalRepositoryProvider);

    final goal = domain.SavingsGoal(
      id: isEdit ? widget.initialGoal!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      targetAmount: target,
      currentAmount: current,
      targetDate: _targetDate,
      color: _selectedColor,
    );

    if (isEdit) {
      await repo.updateGoal(goal);
    } else {
      await repo.addGoal(goal);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Savings goal ${isEdit ? "updated" : "added"}.')),
      );
    }
  }

  void _delete() async {
    final isConfirmed = await showDeleteConfirmationDialog(
      context: context,
      itemType: 'savings goal',
    );

    if (!isConfirmed) return;

    if (widget.initialGoal != null) {
      await ref.read(savingsGoalRepositoryProvider).deleteGoal(widget.initialGoal!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Savings goal deleted.')),
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
    final isEdit = widget.initialGoal != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySym = currencySymbol(ref.watch(currencyCodeProvider));

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dragHandle(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Goal' : 'New Savings Goal',
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
                        labelText: 'Goal Name',
                        hintText: 'e.g. Vacation Fund, Emergency Fund',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _targetAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Target Amount',
                              hintText: '0',
                              prefixText: currencySym,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter target';
                              if (double.tryParse(v) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _currentAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Saved So Far',
                              hintText: '0',
                              prefixText: currencySym,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter amount';
                              if (double.tryParse(v) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Target Date',
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                        ),
                        child: Text(
                          DateFormat('EEE, MMM d, yyyy').format(_targetDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Theme Color',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colors.map((hex) {
                        final colorVal = Color(int.parse(hex.replaceAll('#', '0xFF')));
                        final isSelected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorVal,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppColors.text, width: 2.5)
                                  : Border.all(color: Colors.transparent),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
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
                      child: Text(isEdit ? 'Save Changes' : 'Create Goal'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}

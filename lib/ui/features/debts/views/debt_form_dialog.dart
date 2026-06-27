import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Bottom-sheet form for creating or editing a [domain.Debt] (money borrowed or
/// lent), modelled on the savings-goal form.
class DebtFormDialog extends ConsumerStatefulWidget {
  final domain.Debt? initialDebt;

  const DebtFormDialog({super.key, this.initialDebt});

  @override
  ConsumerState<DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends ConsumerState<DebtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  domain.DebtType _type = domain.DebtType.borrowed;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  String _color = '#B5634A';
  bool _isClosed = false;

  final List<String> _colors = [
    '#B5634A', // Terracotta
    '#2F6F5E', // Deep Green
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
    final d = widget.initialDebt;
    if (d != null) {
      _type = d.type;
      _nameCtrl.text = d.name;
      _counterpartyCtrl.text = d.counterparty ?? '';
      _principalCtrl.text = d.principalAmount.toStringAsFixed(0);
      _paidCtrl.text = d.paidAmount == 0 ? '' : d.paidAmount.toStringAsFixed(0);
      _interestCtrl.text = d.interestRate?.toString() ?? '';
      _emiCtrl.text = d.emiAmount?.toStringAsFixed(0) ?? '';
      _noteCtrl.text = d.note ?? '';
      _startDate = d.startDate;
      _dueDate = d.dueDate;
      _color = d.color;
      _isClosed = d.isClosed;
    } else {
      _paidCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _counterpartyCtrl.dispose();
    _principalCtrl.dispose();
    _paidCtrl.dispose();
    _interestCtrl.dispose();
    _emiCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_dueDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: AppColors.card,
                onSurface: AppColors.text,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final principal = double.tryParse(_principalCtrl.text.trim()) ?? 0;
    if (principal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }
    var paid = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    if (paid < 0) paid = 0;
    if (paid > principal) paid = principal;

    final isEdit = widget.initialDebt != null;
    final counterparty = _counterpartyCtrl.text.trim();
    final interest = double.tryParse(_interestCtrl.text.trim());
    final emi = double.tryParse(_emiCtrl.text.trim());
    final note = _noteCtrl.text.trim();

    final debt = domain.Debt(
      id: isEdit ? widget.initialDebt!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      counterparty: counterparty.isEmpty ? null : counterparty,
      principalAmount: principal,
      paidAmount: paid,
      interestRate: interest,
      emiAmount: emi,
      startDate: _startDate,
      dueDate: _dueDate,
      color: _color,
      isClosed: _isClosed || paid >= principal,
      note: note.isEmpty ? null : note,
    );

    final repo = ref.read(debtRepositoryProvider);
    if (isEdit) {
      await repo.updateDebt(debt);
    } else {
      await repo.addDebt(debt);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debt ${isEdit ? "updated" : "added"}.')),
      );
    }
  }

  void _delete() async {
    final ok = await showDeleteConfirmationDialog(context: context, itemType: 'debt');
    if (!ok) return;
    if (widget.initialDebt != null) {
      await ref.read(debtRepositoryProvider).deleteDebt(widget.initialDebt!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt deleted.')),
        );
      }
    }
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialDebt != null;
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
                      isEdit ? 'Edit Debt' : 'New Debt',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
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
                const SizedBox(height: 12),
                _typeToggle(),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: _type == domain.DebtType.borrowed ? 'e.g. Car Loan, Phone EMI' : 'e.g. Lent to Alex',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _counterpartyCtrl,
                  decoration: InputDecoration(
                    labelText: _type == domain.DebtType.borrowed ? 'Lender (optional)' : 'Borrower (optional)',
                    hintText: 'e.g. HDFC Bank, Alex',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _principalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Total amount', prefixText: '$currencySym '),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter amount';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _type == domain.DebtType.borrowed ? 'Paid so far' : 'Received',
                          prefixText: '$currencySym ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _interestCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Interest % (opt)', suffixText: '%'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emiCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'EMI (opt)', prefixText: '$currencySym '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateField(label: 'Start date', date: _startDate, onTap: () => _pickDate(isStart: true))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        label: 'Due (optional)',
                        date: _dueDate,
                        onTap: () => _pickDate(isStart: false),
                        onClear: _dueDate == null ? null : () => setState(() => _dueDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Color',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colors.map((hex) {
                    final colorVal = Color(int.parse(hex.replaceAll('#', '0xFF')));
                    final selected = _color == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: selected ? Border.all(color: AppColors.text, width: 2.5) : null,
                        ),
                        child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Settled / closed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: _isClosed,
                      activeThumbColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onChanged: (v) => setState(() => _isClosed = v),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Add Debt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeToggle() {
    Widget btn(domain.DebtType type, Color color) {
      final selected = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _type = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              type.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.text.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          btn(domain.DebtType.borrowed, AppColors.secondary),
          btn(domain.DebtType.lent, AppColors.primary),
        ],
      ),
    );
  }

  Widget _dateField({required String label, required DateTime? date, required VoidCallback onTap, VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
          suffixIcon: onClear != null
              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16), onPressed: onClear)
              : null,
        ),
        child: Text(
          date != null ? DateFormat('MMM d, yyyy').format(date) : '—',
          style: const TextStyle(fontSize: 13.5, color: AppColors.text),
        ),
      ),
    );
  }
}

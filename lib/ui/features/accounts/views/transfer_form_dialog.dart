import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import '../../../core/theme.dart';
import '../../../core/dialogs.dart';
import '../../../core/currency_utils.dart';
import '../../../core/account_icons.dart';
import '../../../providers.dart';

/// Bottom-sheet form for moving money from one account to another.
class TransferFormDialog extends ConsumerStatefulWidget {
  final domain.Transfer? initialTransfer;

  const TransferFormDialog({super.key, this.initialTransfer});

  @override
  ConsumerState<TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final t = widget.initialTransfer;
    if (t != null) {
      _amountCtrl.text = t.amount.toStringAsFixed(2);
      _noteCtrl.text = t.note ?? '';
      _fromAccountId = t.fromAccountId;
      _toAccountId = t.toAccountId;
      _date = t.date;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
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
    if (picked != null) setState(() => _date = picked);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick both accounts.')),
      );
      return;
    }
    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick two different accounts.')),
      );
      return;
    }

    final isEdit = widget.initialTransfer != null;
    final transfer = domain.Transfer(
      id: isEdit ? widget.initialTransfer!.id : const Uuid().v4(),
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      amount: amount,
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    final repo = ref.read(transferRepositoryProvider);
    if (isEdit) {
      await repo.updateTransfer(transfer);
    } else {
      await repo.addTransfer(transfer);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transfer ${isEdit ? "updated" : "recorded"}.')),
      );
    }
  }

  void _delete() async {
    final isConfirmed = await showDeleteConfirmationDialog(
      context: context,
      itemType: 'transfer',
    );
    if (!isConfirmed) return;
    if (widget.initialTransfer != null) {
      await ref.read(transferRepositoryProvider).deleteTransfer(widget.initialTransfer!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer deleted.')),
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

  Widget _accountDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<domain.Account> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      ),
      items: accounts.map((acc) {
        final accColor = Color(int.parse(acc.color.replaceAll('#', '0xFF')));
        return DropdownMenuItem(
          value: acc.id,
          child: Row(
            children: [
              Icon(getAccountIcon(acc.type), size: 18, color: accColor),
              const SizedBox(width: 10),
              Flexible(child: Text(acc.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTransfer != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySym = currencySymbol(ref.watch(currencyCodeProvider));
    final accounts = (ref.watch(allAccountsProvider).value ?? [])
        .where((a) => !a.archived && a.id != 'acc_investments')
        .toList();

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
                      isEdit ? 'Edit Transfer' : 'New Transfer',
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
                if (accounts.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'You need at least two active accounts to make a transfer.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else ...[
                  _accountDropdown(
                    label: 'From',
                    icon: Icons.call_made_rounded,
                    value: _fromAccountId,
                    accounts: accounts,
                    onChanged: (v) => setState(() => _fromAccountId = v),
                  ),
                  const SizedBox(height: 12),
                  _accountDropdown(
                    label: 'To',
                    icon: Icons.call_received_rounded,
                    value: _toAccountId,
                    accounts: accounts,
                    onChanged: (v) => setState(() => _toAccountId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixText: currencySym,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter an amount';
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
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                      ),
                      child: Text(
                        DateFormat('EEE, MMM d, yyyy').format(_date),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.note_rounded, size: 18, color: AppColors.primary),
                    ),
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
                    child: Text(isEdit ? 'Save Changes' : 'Transfer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/data/services/sms_parser.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;

class SmsImportDialog extends ConsumerStatefulWidget {
  final ParsedSmsTransaction transaction;
  final String predictedCategoryId;
  final String? initialAccountId;

  const SmsImportDialog({
    super.key,
    required this.transaction,
    required this.predictedCategoryId,
    this.initialAccountId,
  });

  @override
  ConsumerState<SmsImportDialog> createState() => _SmsImportDialogState();
}

class _SmsImportDialogState extends ConsumerState<SmsImportDialog> {
  final _formKey = GlobalKey<FormState>();

  late bool _isExpense;
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  String? _selectedCategoryId;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.transaction.type == SmsTransactionType.debit;
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _merchantController = TextEditingController(text: widget.transaction.merchant);
    _notesController = TextEditingController(
      text: 'SMS Import - ${widget.transaction.bankName}: ${widget.transaction.rawSms}',
    );
    _selectedDate = widget.transaction.dateTime;
    _selectedCategoryId = widget.predictedCategoryId;
    _selectedAccountId = widget.initialAccountId ?? ref.read(defaultAccountIdProvider);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }

    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a merchant or source.')),
      );
      return;
    }

    final categories = ref.read(allCategoriesProvider).value ?? [];
    final defaultCat = categories.isNotEmpty ? categories.first.id : 'cat_uncategorized';

    if (_isExpense) {
      final expense = domain.Expense(
        id: widget.transaction.smsHash,
        amount: amount,
        categoryId: _selectedCategoryId ?? defaultCat,
        date: _selectedDate,
        note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        accountId: _selectedAccountId,
        source: domain.ExpenseSource.manual,
      );
      await ref.read(expenseRepositoryProvider).addExpense(expense);
    } else {
      final income = domain.Income(
        id: widget.transaction.smsHash,
        amount: amount,
        source: merchant,
        date: _selectedDate,
        isRecurring: false,
        frequency: domain.IncomeFrequency.oneOff,
        accountId: _selectedAccountId,
      );
      await ref.read(incomeRepositoryProvider).addIncome(income);
    }

    // Mark SMS as processed
    await ref.read(smsImportRepositoryProvider).markAsProcessed(
      hash: widget.transaction.smsHash,
      sender: widget.transaction.sender,
      date: widget.transaction.dateTime,
      referenceNumber: widget.transaction.referenceNumber,
      amount: widget.transaction.amount,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider).value ?? [];
    final accounts = ref.watch(allAccountsProvider).value ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Transaction Detected',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Segmented type selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _isExpense,
                      onSelected: (val) => setState(() => _isExpense = val),
                      selectedColor: AppColors.secondaryLight,
                      labelStyle: TextStyle(
                        color: _isExpense ? AppColors.secondary : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: !_isExpense,
                      onSelected: (val) => setState(() => _isExpense = !val),
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        color: !_isExpense ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter amount' : null,
              ),
              const SizedBox(height: 12),
              // Merchant / Source field
              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: _isExpense ? 'Merchant' : 'Income Source',
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter merchant name' : null,
              ),
              const SizedBox(height: 12),
              // Category (only show for Expense)
              if (_isExpense) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
                const SizedBox(height: 12),
              ],
              // Account
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: 'Account / Wallet'),
                items: accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name),
                )).toList(),
                onChanged: (val) => setState(() => _selectedAccountId = val),
              ),
              const SizedBox(height: 12),
              // Date Row
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(color: AppColors.text.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      Text(
                        DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Mark SMS as processed so it is ignored
                        ref.read(smsImportRepositoryProvider).markAsProcessed(
                          hash: widget.transaction.smsHash,
                          sender: widget.transaction.sender,
                          date: widget.transaction.dateTime,
                          referenceNumber: widget.transaction.referenceNumber,
                          amount: widget.transaction.amount,
                        );
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Ignore'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

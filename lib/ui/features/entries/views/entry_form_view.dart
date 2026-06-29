import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:google_fonts/google_fonts.dart';

/// Common income sources offered in the entry form dropdown. 'Other' reveals a
/// free-text field so any source not in this list can still be entered.
const List<String> kIncomeSources = [
  'Salary',
  'Freelance',
  'Business',
  'Sale',
  'Investment',
  'Rental Income',
  'Interest',
  'Bonus',
  'Gift',
  'Refund',
  'Other',
];

class EntryFormView extends ConsumerStatefulWidget {
  final domain.Income? initialIncome;
  final domain.Expense? initialExpense;

  const EntryFormView({
    super.key,
    this.initialIncome,
    this.initialExpense,
  });

  @override
  ConsumerState<EntryFormView> createState() => _EntryFormViewState();
}

class _EntryFormViewState extends ConsumerState<EntryFormView> {
  final _formKey = GlobalKey<FormState>();

  bool _isExpense = true;
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Multi-currency: the currency the amount is entered in, plus the exchange
  // rate (base units per 1 foreign unit) used to convert to the base currency.
  late String _currencyCode;
  final _rateController = TextEditingController();
  bool _fetchingRate = false;

  final _sourceController = TextEditingController();
  String _selectedSource = kIncomeSources.first;
  bool _isRecurring = false;
  domain.IncomeFrequency _frequency = domain.IncomeFrequency.oneOff;

  String? _selectedCategoryId;
  String? _selectedAccountId;
  final _noteController = TextEditingController();
  String? _receiptImagePath;
  domain.ExpenseSource _expenseSource = domain.ExpenseSource.manual;
  double? _aiConfidence;

  String get _baseCurrency => ref.read(currencyCodeProvider);
  bool get _isForeign => _currencyCode != _baseCurrency;

  @override
  void initState() {
    super.initState();
    _currencyCode = ref.read(currencyCodeProvider);
    if (widget.initialIncome != null) {
      _isExpense = false;
      _amountController.text = widget.initialIncome!.amount.toString();
      _applyForeign(widget.initialIncome!.originalCurrency, widget.initialIncome!.originalAmount, widget.initialIncome!.amount);
      _selectedDate = widget.initialIncome!.date;
      final existingSource = widget.initialIncome!.source;
      // Match the stored source to a preset (case-insensitive); anything else
      // becomes a custom 'Other' entry so the original text is preserved.
      final preset = kIncomeSources.firstWhere(
        (s) => s != 'Other' && s.toLowerCase() == existingSource.toLowerCase(),
        orElse: () => 'Other',
      );
      _selectedSource = preset;
      _sourceController.text = preset == 'Other' ? existingSource : '';
      _isRecurring = widget.initialIncome!.isRecurring;
      _frequency = widget.initialIncome!.frequency;
      _selectedAccountId = widget.initialIncome!.accountId;
    } else if (widget.initialExpense != null) {
      _isExpense = true;
      _amountController.text = widget.initialExpense!.amount.toString();
      _applyForeign(widget.initialExpense!.originalCurrency, widget.initialExpense!.originalAmount, widget.initialExpense!.amount);
      _selectedDate = widget.initialExpense!.date;
      _selectedCategoryId = widget.initialExpense!.categoryId;
      _noteController.text = widget.initialExpense!.note ?? '';
      _receiptImagePath = widget.initialExpense!.receiptImagePath;
      _expenseSource = widget.initialExpense!.source;
      _aiConfidence = widget.initialExpense!.aiConfidence;
      _selectedAccountId = widget.initialExpense!.accountId;
    }
  }

  /// When editing a foreign-currency entry, show the original amount/currency
  /// and back out the exchange rate that was used.
  void _applyForeign(String? currency, double? originalAmount, double baseAmount) {
    if (currency == null || originalAmount == null || originalAmount <= 0) return;
    _currencyCode = currency;
    _amountController.text = _trim(originalAmount);
    _rateController.text = _trim(baseAmount / originalAmount);
  }

  String _trim(double v) {
    final s = v.toStringAsFixed(4);
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  /// Fetches the live exchange rate for the selected currency → base and fills
  /// the rate field. Silent on failure — the user can type a rate manually.
  Future<void> _fetchRate() async {
    if (!_isForeign) return;
    setState(() => _fetchingRate = true);
    try {
      final rate = await ref
          .read(currencyConversionServiceProvider)
          .fetchRate(_currencyCode, _baseCurrency);
      if (!mounted) return;
      if (rate != null && rate > 0) {
        _rateController.text = _trim(rate);
      }
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
  }

  void _onCurrencyChanged(String code) {
    setState(() {
      _currencyCode = code;
      if (!_isForeign) _rateController.clear();
    });
    if (_isForeign && _rateController.text.trim().isEmpty) {
      _fetchRate();
    }
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

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final entered = double.tryParse(_amountController.text) ?? 0.0;
    if (entered <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }

    // Resolve the base-currency amount + original-currency fields.
    double amount = entered;
    String? originalCurrency;
    double? originalAmount;
    if (_isForeign) {
      final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
      if (rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an exchange rate for the selected currency.')),
        );
        return;
      }
      amount = entered * rate;
      originalCurrency = _currencyCode;
      originalAmount = entered;
    }

    final uuid = const Uuid().v4();

    if (_isExpense) {
      final categoriesAsync = ref.read(allCategoriesProvider);
      final categories = categoriesAsync.value ?? [];
      final defaultCat = categories.isNotEmpty ? categories.first.id : 'cat_uncategorized';

      final expense = domain.Expense(
        id: widget.initialExpense?.id ?? uuid,
        amount: amount,
        categoryId: _selectedCategoryId ?? defaultCat,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        receiptImagePath: _receiptImagePath,
        source: _expenseSource,
        aiConfidence: _aiConfidence,
        accountId: _selectedAccountId,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
      );

      final repo = ref.read(expenseRepositoryProvider);
      if (widget.initialExpense != null) {
        await repo.updateExpense(expense);
      } else {
        await repo.addExpense(expense);
      }
    } else {
      final customSource = _sourceController.text.trim();
      final source = _selectedSource == 'Other'
          ? (customSource.isEmpty ? 'Other' : customSource)
          : _selectedSource;

      final income = domain.Income(
        id: widget.initialIncome?.id ?? uuid,
        amount: amount,
        source: source,
        date: _selectedDate,
        isRecurring: _isRecurring,
        frequency: _frequency,
        accountId: _selectedAccountId,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
      );

      final repo = ref.read(incomeRepositoryProvider);
      if (widget.initialIncome != null) {
        await repo.updateIncome(income);
      } else {
        await repo.addIncome(income);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final isEdit = widget.initialIncome != null || widget.initialExpense != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit ${_isExpense ? "Expense" : "Income"}' : 'New Transaction'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isEdit) _buildTypeToggle(),
                  const SizedBox(height: 20),
                  _buildSectionCard([
                    _buildAmountField(),
                    const SizedBox(height: 14),
                    _buildDateField(),
                  ]),
                  const SizedBox(height: 12),
                  if (!_isExpense)
                    _buildSectionCard([
                      _buildSourceField(),
                      const SizedBox(height: 14),
                      _buildAccountField(),
                      const SizedBox(height: 14),
                      _buildRecurringSection(),
                    ])
                  else
                    _buildSectionCard([
                      categoriesAsync.when(
                        loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        error: (err, _) => Text('$err', style: const TextStyle(color: AppColors.error)),
                        data: (categories) => _buildCategoryDropdown(categories),
                      ),
                      const SizedBox(height: 14),
                      _buildAccountField(),
                      const SizedBox(height: 14),
                      _buildNoteField(),
                      if (_receiptImagePath != null) ...[
                        const SizedBox(height: 14),
                        _buildReceiptPreview(),
                      ],
                    ]),
                  const SizedBox(height: 24),
                  _buildSaveButton(isEdit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _toggleBtn('Income', false, AppColors.primary)),
          Expanded(child: _toggleBtn('Expense', true, AppColors.secondary)),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool isExpense, Color color) {
    final selected = _isExpense == isExpense;
    return GestureDetector(
      onTap: () => setState(() => _isExpense = isExpense),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpense ? Icons.trending_down_rounded : Icons.trending_up_rounded,
              size: 16,
              color: selected ? Colors.white : color.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.text.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildAmountField() {
    final currencySym = currencySymbol(_currencyCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.text),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: '0.00',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(currencySym, style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.primary)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            suffixIcon: _buildCurrencySelector(),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter an amount';
            if (double.tryParse(v) == null) return 'Enter a valid number';
            return null;
          },
        ),
        if (_isForeign) ...[
          const SizedBox(height: 12),
          _buildConversionRow(),
        ],
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _currencyCode,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            items: supportedCurrencies
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) _onCurrencyChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversionRow() {
    final base = _baseCurrency;
    final baseSym = currencySymbol(base);
    final entered = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    final converted = (entered != null && rate != null) ? entered * rate : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('1 $_currencyCode =', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: baseSym,
                    hintText: 'rate',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Fetch live rate',
                visualDensity: VisualDensity.compact,
                icon: _fetchingRate
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                onPressed: _fetchingRate ? null : _fetchRate,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            converted != null
                ? '≈ $baseSym${converted.toStringAsFixed(2)} in $base'
                : 'Enter a rate to see the $base amount',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
          suffixIcon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
        ),
        child: Text(
          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 15, color: AppColors.text),
        ),
      ),
    );
  }

  Widget _buildSourceField() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedSource,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Source',
            prefixIcon: Icon(Icons.business_rounded, size: 20, color: AppColors.primary),
          ),
          items: kIncomeSources.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(s == 'Other' ? 'Other (Custom)' : s),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedSource = v ?? _selectedSource),
        ),
        if (_selectedSource == 'Other') ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _sourceController,
            decoration: const InputDecoration(
              labelText: 'Custom Source',
              hintText: 'e.g. Side gig, Cashback',
              prefixIcon: Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
            ),
            validator: (v) {
              if (_selectedSource == 'Other' && (v == null || v.trim().isEmpty)) {
                return 'Enter a source name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRecurringSection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            title: const Text('Recurring Income', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: _isRecurring ? const Text('Paid on a regular schedule') : null,
            value: _isRecurring,
            activeThumbColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onChanged: (v) => setState(() => _isRecurring = v),
          ),
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<domain.IncomeFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(
              labelText: 'Frequency',
              prefixIcon: Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
            ),
            items: domain.IncomeFrequency.values.map((f) {
              return DropdownMenuItem(value: f, child: Text(f.displayName));
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _frequency = v);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryDropdown(List<domain.Category> categories) {
    final expenseCategories = categories.where((c) => c.id != 'cat_income').toList();

    if (_selectedCategoryId == null && expenseCategories.isNotEmpty) {
      _selectedCategoryId = expenseCategories.first.id;
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_rounded, size: 20, color: AppColors.primary),
      ),
      items: expenseCategories.map((cat) {
        final catColor = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
        return DropdownMenuItem(
          value: cat.id,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(cat.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
    );
  }

  Widget _buildAccountField() {
    final accountsAsync = ref.watch(allAccountsProvider);
    return accountsAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Text('$err', style: const TextStyle(color: AppColors.error)),
      data: (allAccounts) {
        final accounts = allAccounts.where((a) => !a.archived).toList();
        if (accounts.isEmpty) {
          return const SizedBox.shrink();
        }
        // Prefer the user-designated default account; fall back to first available.
        if (_selectedAccountId == null ||
            !accounts.any((a) => a.id == _selectedAccountId)) {
          final defaultId = ref.read(defaultAccountIdProvider);
          _selectedAccountId = accounts.any((a) => a.id == defaultId)
              ? defaultId
              : accounts.first.id;
        }
        return DropdownButtonFormField<String>(
          initialValue: _selectedAccountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Account',
            prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.primary),
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
          onChanged: (v) => setState(() => _selectedAccountId = v),
        );
      },
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Note / Merchant',
        hintText: 'Optional details...',
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 48),
          child: Icon(Icons.note_rounded, size: 20, color: AppColors.primary),
        ),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_receiptImagePath!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt attached', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 2),
                Text('Scanned with AI', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: () => setState(() {
              _receiptImagePath = null;
              _expenseSource = domain.ExpenseSource.manual;
              _aiConfidence = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isEdit) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _saveForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isExpense ? AppColors.secondary : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(isEdit ? 'Save Changes' : 'Add ${_isExpense ? "Expense" : "Income"}'),
      ),
    );
  }
}

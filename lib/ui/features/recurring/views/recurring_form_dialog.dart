import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart' show kIncomeSources;

/// Bottom-sheet form to create or edit a recurring expense/income rule.
class RecurringFormDialog extends ConsumerStatefulWidget {
  final domain.RecurringRule? initialRule;

  const RecurringFormDialog({super.key, this.initialRule});

  @override
  ConsumerState<RecurringFormDialog> createState() => _RecurringFormDialogState();
}

class _RecurringFormDialogState extends ConsumerState<RecurringFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isExpense = true;
  String? _categoryId;
  String _incomeSource = kIncomeSources.first;
  String? _accountId;
  domain.RecurrenceFrequency _frequency = domain.RecurrenceFrequency.monthly;
  DateTime _dueDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    if (r != null) {
      _isExpense = r.type == domain.RecurringType.expense;
      _titleCtrl.text = r.title;
      _amountCtrl.text = r.amount.toStringAsFixed(r.amount == r.amount.roundToDouble() ? 0 : 2);
      _noteCtrl.text = r.note ?? '';
      _categoryId = r.categoryId;
      _accountId = r.accountId;
      _frequency = r.frequency;
      _dueDate = r.nextDueDate;
      _endDate = r.endDate;
      _isActive = r.isActive;
      final src = r.source;
      if (src != null) {
        final preset = kIncomeSources.firstWhere(
          (s) => s != 'Other' && s.toLowerCase() == src.toLowerCase(),
          orElse: () => 'Other',
        );
        _incomeSource = preset;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDue}) async {
    final initial = isDue ? _dueDate : (_endDate ?? _dueDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
    if (picked != null) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
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

    final isEdit = widget.initialRule != null;
    final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);

    final rule = domain.RecurringRule(
      id: isEdit ? widget.initialRule!.id : const Uuid().v4(),
      type: _isExpense ? domain.RecurringType.expense : domain.RecurringType.income,
      title: _titleCtrl.text.trim(),
      amount: amount,
      categoryId: _isExpense ? (_categoryId ?? 'cat_uncategorized') : null,
      // 'Other' has no custom field here, so fall back to the rule name as the
      // posted income's source.
      source: _isExpense ? null : (_incomeSource == 'Other' ? null : _incomeSource),
      accountId: _accountId,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      frequency: _frequency,
      nextDueDate: due,
      endDate: _endDate == null ? null : DateTime(_endDate!.year, _endDate!.month, _endDate!.day),
      lastPostedDate: widget.initialRule?.lastPostedDate,
      isActive: _isActive,
    );

    final repo = ref.read(recurringRuleRepositoryProvider);
    if (isEdit) {
      await repo.updateRule(rule);
    } else {
      await repo.addRule(rule);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recurring ${_isExpense ? 'expense' : 'income'} ${isEdit ? 'updated' : 'scheduled'}.')),
      );
    }
  }

  void _delete() async {
    final ok = await showDeleteConfirmationDialog(context: context, itemType: 'recurring rule');
    if (!ok) return;
    if (widget.initialRule != null) {
      await ref.read(recurringRuleRepositoryProvider).deleteRule(widget.initialRule!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring rule deleted. Already-posted entries are kept.')),
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
    final isEdit = widget.initialRule != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySym = currencySymbol(ref.watch(currencyCodeProvider));
    final categories = (ref.watch(allCategoriesProvider).value ?? [])
        .where((c) => c.id != 'cat_income')
        .toList();
    final accounts = (ref.watch(allAccountsProvider).value ?? [])
        .where((a) => !a.archived)
        .toList();

    if (_isExpense && _categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

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
                      isEdit ? 'Edit Recurring' : 'New Recurring',
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
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: _isExpense ? 'e.g. Rent, Netflix' : 'e.g. Salary',
                    prefixIcon: const Icon(Icons.label_outline_rounded, size: 20, color: AppColors.primary),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '$currencySym ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an amount';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (_isExpense)
                  _categoryDropdown(categories)
                else
                  _sourceDropdown(),
                const SizedBox(height: 12),
                if (accounts.isNotEmpty) ...[
                  _accountDropdown(accounts),
                  const SizedBox(height: 12),
                ],
                _frequencyDropdown(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateField(label: 'First / next due', date: _dueDate, onTap: () => _pickDate(isDue: true))),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField(label: 'Ends (optional)', date: _endDate, onTap: () => _pickDate(isDue: false), onClear: _endDate == null ? null : () => setState(() => _endDate = null))),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _isActive ? 'Auto-posts when due' : 'Paused — nothing will post',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isActive,
                    activeThumbColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeToggle() {
    Widget btn(String label, bool expense, Color color) {
      final selected = _isExpense == expense;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isExpense = expense),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
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
          btn('Income', false, AppColors.primary),
          btn('Expense', true, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _categoryDropdown(List<domain.Category> categories) {
    return DropdownButtonFormField<String>(
      initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_rounded, size: 20, color: AppColors.primary),
      ),
      items: categories.map((cat) {
        final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
        return DropdownMenuItem(
          value: cat.id,
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Flexible(child: Text(cat.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  Widget _sourceDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _incomeSource,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Source',
        prefixIcon: Icon(Icons.business_rounded, size: 20, color: AppColors.primary),
      ),
      items: kIncomeSources
          .map((s) => DropdownMenuItem(value: s, child: Text(s == 'Other' ? 'Other (Custom)' : s)))
          .toList(),
      onChanged: (v) => setState(() => _incomeSource = v ?? _incomeSource),
    );
  }

  Widget _accountDropdown(List<domain.Account> accounts) {
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Account',
        prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.primary),
      ),
      items: accounts.map((acc) {
        final color = Color(int.parse(acc.color.replaceAll('#', '0xFF')));
        return DropdownMenuItem(
          value: acc.id,
          child: Row(
            children: [
              Icon(getAccountIcon(acc.type), size: 18, color: color),
              const SizedBox(width: 10),
              Flexible(child: Text(acc.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _accountId = v),
    );
  }

  Widget _frequencyDropdown() {
    return DropdownButtonFormField<domain.RecurrenceFrequency>(
      initialValue: _frequency,
      decoration: const InputDecoration(
        labelText: 'Repeats',
        prefixIcon: Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
      ),
      items: domain.RecurrenceFrequency.values
          .map((f) => DropdownMenuItem(value: f, child: Text(f.displayName)))
          .toList(),
      onChanged: (v) => setState(() => _frequency = v ?? _frequency),
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

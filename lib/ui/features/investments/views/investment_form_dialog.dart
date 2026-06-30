import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/data/services/investment_transfer_service.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Bottom-sheet form for creating or editing an [domain.Investment]. Mirrors
/// the debt form's structure so the UX stays consistent across modules.
class InvestmentFormDialog extends ConsumerStatefulWidget {
  final domain.Investment? initialInvestment;

  const InvestmentFormDialog({super.key, this.initialInvestment});

  @override
  ConsumerState<InvestmentFormDialog> createState() =>
      _InvestmentFormDialogState();
}

class _InvestmentFormDialogState extends ConsumerState<InvestmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _investedCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _unitsCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  domain.InvestmentType _type = domain.InvestmentType.stocks;
  DateTime _purchaseDate = DateTime.now();
  String _color = '#2F6F5E';
  bool _isClosed = false;
  String? _accountId;

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
    final i = widget.initialInvestment;
    if (i != null) {
      _type = i.type;
      _nameCtrl.text = i.name;
      _investedCtrl.text = i.investedAmount.toStringAsFixed(2);
      _currentCtrl.text = i.currentValue.toStringAsFixed(2);
      _unitsCtrl.text = i.units?.toString() ?? '';
      _platformCtrl.text = i.platform ?? '';
      _noteCtrl.text = i.note ?? '';
      _purchaseDate = i.purchaseDate;
      _color = i.color;
      _isClosed = i.isClosed;
      _accountId = i.accountId;
    } else {
      // New investment: pre-select the user's default account (the one they
      // marked as default in Accounts → Settings) so the funding picker
      // mirrors the rest of the app instead of starting on "Not linked".
      // Falls back to null if the resolved id is the hidden investment wallet
      // (defensive — that account isn't selectable as a default today).
      final defaultId = ref.read(defaultAccountIdProvider);
      _accountId = defaultId == InvestmentTransferService.investmentAccountId
          ? null
          : defaultId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _investedCtrl.dispose();
    _currentCtrl.dispose();
    _unitsCtrl.dispose();
    _platformCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _purchaseDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final invested = double.tryParse(_investedCtrl.text.trim()) ?? 0;
    if (invested <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an invested amount greater than 0.')),
      );
      return;
    }
    final currentText = _currentCtrl.text.trim();
    final current = currentText.isEmpty
        ? invested
        : (double.tryParse(currentText) ?? invested);

    final units = double.tryParse(_unitsCtrl.text.trim());
    final platform = _platformCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    final isEdit = widget.initialInvestment != null;
    final wasValueEdited = !isEdit ||
        (widget.initialInvestment!.currentValue != current);

    final investment = domain.Investment(
      id: isEdit ? widget.initialInvestment!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      investedAmount: invested,
      currentValue: current,
      units: units,
      purchaseDate: _purchaseDate,
      lastValueUpdate: wasValueEdited
          ? DateTime.now()
          : widget.initialInvestment?.lastValueUpdate,
      platform: platform.isEmpty ? null : platform,
      accountId: _accountId,
      color: _color,
      isClosed: _isClosed,
      note: note.isEmpty ? null : note,
    );

    // Available-balance check: if the funding account would go negative once
    // the buy transfer is rewritten, confirm before proceeding. Edits only
    // need to cover the delta (existing buy transfer is already deducted), so
    // we add back the previous amount on the same account before comparing.
    if (!await _confirmIfOverdrawing(investment)) return;

    final repo = ref.read(investmentRepositoryProvider);
    if (isEdit) {
      await repo.updateInvestment(investment);
    } else {
      await repo.addInvestment(investment);
    }

    // Sync the auto-managed buy / sell transfers so wallet balances reflect
    // the holding. No-op when [accountId] is null (manual mode).
    await ref.read(investmentTransferServiceProvider).syncOnSave(
          investment: investment,
          previous: widget.initialInvestment,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_savedMessage(investment, isEdit))),
      );
    }
  }

  /// Returns true if the save should proceed. Soft-blocks (with a confirm
  /// dialog) when the funding account doesn't have enough liquid cash to
  /// cover the new investment amount — the user can still override, because
  /// they may have unrecorded income or be deliberately running a credit
  /// balance. Returns true immediately when no funding account is picked,
  /// when the investment is already marked closed (sell flow can credit, not
  /// debit), or when the funding account is unchanged and the new amount is
  /// less than or equal to the previous one.
  Future<bool> _confirmIfOverdrawing(domain.Investment next) async {
    final fundingId = next.accountId;
    if (fundingId == null || next.isClosed) return true;

    final balances = ref.read(accountBalancesProvider);
    final accounts = ref.read(allAccountsProvider).value ?? const [];
    final account =
        accounts.where((a) => a.id == fundingId).firstOrNull;
    if (account == null) return true;

    final previous = widget.initialInvestment;
    // Add back what's already deducted on this account so we only validate
    // the *additional* draw imposed by this edit.
    var available = balances[fundingId] ?? 0;
    if (previous != null &&
        previous.accountId == fundingId &&
        !previous.isClosed) {
      available += previous.investedAmount;
    }

    if (available >= next.investedAmount) return true;

    final symbol = currencySymbol(ref.read(currencyCodeProvider));
    final shortfall = next.investedAmount - available;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Insufficient balance', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${account.name} only has $symbol${available.toStringAsFixed(2)} '
              'available. This investment would overdraw it by '
              '$symbol${shortfall.toStringAsFixed(2)}.',
              style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Continue anyway? The account balance will go negative.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _savedMessage(domain.Investment inv, bool isEdit) {
    final verb = isEdit ? 'updated' : 'added';
    if (inv.accountId == null) {
      return 'Investment $verb. (No funding account — wallet balance unchanged.)';
    }
    if (inv.isClosed) {
      return 'Investment $verb. Proceeds credited to your account.';
    }
    return 'Investment $verb. Funding account balance updated.';
  }

  void _delete() async {
    final ok = await showDeleteConfirmationDialog(
        context: context, itemType: 'investment');
    if (!ok) return;
    final inv = widget.initialInvestment;
    if (inv != null) {
      await ref.read(investmentRepositoryProvider).deleteInvestment(inv.id);
      // Drop the auto-managed buy / sell transfers so the funding account's
      // balance pops back to its pre-investment state.
      await ref
          .read(investmentTransferServiceProvider)
          .syncOnDelete(inv.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Investment deleted.')),
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
    final isEdit = widget.initialInvestment != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySym = currencySymbol(ref.watch(currencyCodeProvider));
    final accounts = ref.watch(allAccountsProvider).value ?? const [];

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
                      isEdit ? 'Edit Investment' : 'New Investment',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                    ),
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.secondary),
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
                DropdownButtonFormField<domain.InvestmentType>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: domain.InvestmentType.values
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. HDFC Bank, Nifty 50 Index, SBI FD',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _investedCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Invested', prefixText: '$currencySym '),
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
                        controller: _currentCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Current value',
                            prefixText: '$currencySym ',
                            helperText: 'Leave blank = same as invested'),
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
                        controller: _unitsCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Units / Qty (opt)',
                            hintText: 'e.g. 25, 10.5'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _platformCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Platform (opt)',
                          hintText: 'Zerodha, Groww, …',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                          label: 'Purchase date',
                          date: _purchaseDate,
                          onTap: _pickPurchaseDate),
                    ),
                  ],
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Funded from',
                      helperText:
                          'Picking an account moves the invested amount out of it (and credits proceeds back when closed). Leave blank to track without touching balances.',
                      helperMaxLines: 3,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Not linked (manual)',
                            overflow: TextOverflow.ellipsis),
                      ),
                      for (final a in accounts.where((a) =>
                          !a.archived &&
                          a.id != InvestmentTransferService.investmentAccountId))
                        DropdownMenuItem<String?>(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Color',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colors.map((hex) {
                    final colorVal =
                        Color(int.parse(hex.replaceAll('#', '0xFF')));
                    final selected = _color == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: AppColors.text, width: 2.5)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note_rounded,
                        size: 20, color: AppColors.primary),
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
                      title: const Text('Closed / sold',
                          style:
                              TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: _isClosed,
                      activeThumbColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Add Investment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded,
              size: 18, color: AppColors.primary),
        ),
        child: Text(
          DateFormat('MMM d, yyyy').format(date),
          style: const TextStyle(fontSize: 13.5, color: AppColors.text),
        ),
      ),
    );
  }
}

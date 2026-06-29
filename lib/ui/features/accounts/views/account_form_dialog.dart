import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/models.dart' as domain;
import '../../../core/theme.dart';
import '../../../core/dialogs.dart';
import '../../../core/currency_utils.dart';
import '../../../core/account_icons.dart';
import '../../../providers.dart';

/// Bottom-sheet form for creating or editing an [domain.Account].
class AccountFormDialog extends ConsumerStatefulWidget {
  final domain.Account? initialAccount;

  const AccountFormDialog({super.key, this.initialAccount});

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  domain.AccountType _type = domain.AccountType.bank;
  String _selectedColor = '#2F6F5E';
  bool _archived = false;

  final List<String> _colors = [
    '#2F6F5E', // Deep Green
    '#4F5B56', // Dark Slate
    '#B5634A', // Terracotta
    '#617C8F', // Steel Blue
    '#D39B82', // Warm Orange
    '#688F80', // Muted Teal
    '#9C27B0', // Purple
    '#E91E63', // Pink
  ];

  bool get _isHardcodedFallback => widget.initialAccount?.id == defaultAccountId;

  bool get _isCurrentDefault => widget.initialAccount?.isDefault ?? false;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAccount;
    if (a != null) {
      _nameCtrl.text = a.name;
      _type = a.type;
      _selectedColor = a.color;
      _archived = a.archived;
      _openingBalanceCtrl.text = a.openingBalance == 0 ? '' : a.openingBalance.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.initialAccount != null;
    final repo = ref.read(accountRepositoryProvider);

    final existing = ref.read(allAccountsProvider).value ?? [];
    final sortOrder = isEdit
        ? widget.initialAccount!.sortOrder
        : (existing.isEmpty ? 0 : existing.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) + 1);

    final account = domain.Account(
      id: isEdit ? widget.initialAccount!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      color: _selectedColor,
      openingBalance: double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0,
      archived: _archived,
      sortOrder: sortOrder,
    );

    if (isEdit) {
      await repo.updateAccount(account);
    } else {
      await repo.addAccount(account);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account ${isEdit ? "updated" : "added"}.')),
      );
    }
  }

  void _delete() async {
    if (_isHardcodedFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("The Cash account can't be deleted. You can archive it instead.")),
      );
      return;
    }
    final isConfirmed = await showDeleteConfirmationDialog(
      context: context,
      itemType: 'account',
    );
    if (!isConfirmed) return;
    if (widget.initialAccount != null) {
      await ref.read(accountRepositoryProvider).deleteAccount(widget.initialAccount!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted. Its transactions now count toward Cash.')),
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
    final isEdit = widget.initialAccount != null;
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
                      isEdit ? 'Edit Account' : 'New Account',
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
                    labelText: 'Account Name',
                    hintText: 'e.g. HDFC Savings, Wallet Cash',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<domain.AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_rounded, size: 20, color: AppColors.primary),
                  ),
                  items: domain.AccountType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(getAccountIcon(t), size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(t.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _openingBalanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    hintText: '0',
                    prefixText: currencySym,
                    helperText: 'Current money already in this account',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Color',
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
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Archived', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Hide from pickers and totals', style: TextStyle(fontSize: 12)),
                      value: _archived,
                      activeThumbColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onChanged: (v) => setState(() => _archived = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isCurrentDefault ? AppColors.primary : AppColors.divider,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        _isCurrentDefault ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: _isCurrentDefault ? AppColors.primary : AppColors.textSecondary,
                      ),
                      title: Text(
                        _isCurrentDefault ? 'Default Account' : 'Set as Default',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _isCurrentDefault ? AppColors.primary : AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        _isCurrentDefault
                            ? 'Auto-selected when adding a transaction'
                            : 'Auto-select this account for new transactions',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _isCurrentDefault
                          ? null
                          : TextButton(
                              onPressed: () async {
                                await ref.read(accountRepositoryProvider).setDefaultAccount(widget.initialAccount!.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${widget.initialAccount!.name} is now the default account.')),
                                  );
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Set'),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

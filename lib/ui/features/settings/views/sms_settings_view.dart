import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/data/services/sms_parser.dart';
import 'package:smart_wallet/data/services/category_predictor.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;

class SmsSettingsView extends ConsumerStatefulWidget {
  const SmsSettingsView({super.key});

  @override
  ConsumerState<SmsSettingsView> createState() => _SmsSettingsViewState();
}

class _SmsSettingsViewState extends ConsumerState<SmsSettingsView> {
  bool _enabled = false;
  bool _duplicateProtection = true;
  bool _autoCategory = true;
  bool _confirmation = true;
  bool _autoDelete = false;
  List<String> _excludedSenders = [];
  final List<String> _supportedBanks = ['HDFC', 'ICICI', 'SBI', 'Axis', 'Kotak', 'PNB', 'BOB'];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('sms_import_enabled') ?? false;
      _duplicateProtection = prefs.getBool('sms_import_duplicate_protection') ?? true;
      _autoCategory = prefs.getBool('sms_import_auto_category') ?? true;
      _confirmation = prefs.getBool('sms_import_confirmation') ?? true;
      _autoDelete = prefs.getBool('sms_import_auto_delete') ?? false;
      
      final excludedJson = prefs.getString('sms_import_excluded_senders');
      if (excludedJson != null) {
        try {
          _excludedSenders = List<String>.from(jsonDecode(excludedJson));
        } catch (_) {
          _excludedSenders = [];
        }
      }
      _loading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _saveExcludedSenders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_import_excluded_senders', jsonEncode(_excludedSenders));
  }

  Future<void> _toggleEnabled(bool val) async {
    if (val) {
      // Request permissions
      final success = await ref.read(smsPermissionServiceProvider).requestPermission();
      if (!success) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('SMS Permission Required'),
              content: const Text(
                'This feature requires SMS permissions to read transaction messages from your bank. Please enable them in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(smsPermissionServiceProvider).openSettings();
                  },
                  child: const Text('Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    setState(() => _enabled = val);
    await _saveSetting('sms_import_enabled', val);
  }

  void _addExcludedSender() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exclude Sender'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. AD-PROMOT',
            labelText: 'Sender Name / Pattern',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  _excludedSenders.add(val);
                });
                _saveExcludedSenders();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Existing SMS'),
        content: const Text('Select a period to scan for transaction SMS messages in your inbox:'),
        actions: [
          SimpleDialogOption(
            onPressed: () => _scanInbox(30),
            child: const Text('Last 30 Days'),
          ),
          SimpleDialogOption(
            onPressed: () => _scanInbox(90),
            child: const Text('Last 3 Months'),
          ),
          SimpleDialogOption(
            onPressed: () => _scanInbox(365),
            child: const Text('Last Year'),
          ),
          SimpleDialogOption(
            onPressed: () => _scanInbox(0), // all
            child: const Text('Scan All (Complete Inbox)'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanInbox(int days) async {
    Navigator.pop(context); // Close scan period dialog
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Scanning SMS messages...'),
          ],
        ),
      ),
    );

    try {
      final transactions = await ref.read(smsServiceProvider).scanInboxAndDetectTransactions(
        days: days,
        excludedSenders: _excludedSenders,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        if (transactions.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Scan Completed'),
              content: const Text('No new, non-duplicate transaction SMS messages were found.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => SmsImportSelectionView(
                transactions: transactions,
                duplicateProtection: _duplicateProtection,
                autoCategory: _autoCategory,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning SMS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Import Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSectionCard(
              icon: Icons.sms_rounded,
              title: 'SMS Transaction Import',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable SMS Import'),
                subtitle: const Text('Detect and import bank transactions from incoming SMS'),
                value: _enabled,
                onChanged: _toggleEnabled,
              ),
            ),
            const SizedBox(height: 12),
            if (_enabled) ...[
              _buildSectionCard(
                icon: Icons.history_rounded,
                title: 'Existing SMS History',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan your existing inbox to parse and import historical financial transactions.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showScanDialog,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Scan & Import Existing SMS'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                icon: Icons.security_rounded,
                title: 'Import Preferences',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Duplicate Protection'),
                      subtitle: const Text('Prevent importing duplicate transactions'),
                      value: _duplicateProtection,
                      onChanged: (val) {
                        setState(() => _duplicateProtection = val);
                        _saveSetting('sms_import_duplicate_protection', val);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Category Suggestion'),
                      subtitle: const Text('Automatically predict transaction category'),
                      value: _autoCategory,
                      onChanged: (val) {
                        setState(() => _autoCategory = val);
                        _saveSetting('sms_import_auto_category', val);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Confirm Before Saving'),
                      subtitle: const Text('Show verification sheet for details review'),
                      value: _confirmation,
                      onChanged: (val) {
                        setState(() => _confirmation = val);
                        _saveSetting('sms_import_confirmation', val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                icon: Icons.block_rounded,
                title: 'Excluded Senders',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Ignore SMS from these specific addresses',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _addExcludedSender,
                          icon: const Icon(Icons.add_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (_excludedSenders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No senders excluded.',
                          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _excludedSenders.length,
                        itemBuilder: (ctx, idx) {
                          final sender = _excludedSenders[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(sender),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary),
                              onPressed: () {
                                setState(() {
                                  _excludedSenders.removeAt(idx);
                                });
                                _saveExcludedSenders();
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                icon: Icons.account_balance_rounded,
                title: 'Supported Banks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Wallet automatically detects SMS formats from the following banks/senders:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _supportedBanks.map((b) => Chip(
                        label: Text(b),
                        backgroundColor: AppColors.surface,
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                icon: Icons.delete_sweep_rounded,
                title: 'Auto-delete Messages',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto Delete Imported SMS'),
                  subtitle: const Text('Remove parsed SMS messages from the system inbox'),
                  value: _autoDelete,
                  onChanged: (val) {
                    // Show warning disclaimer
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.secondary, size: 40),
                        title: const Text('System Limitation'),
                        content: const Text(
                          'Android security policies only allow the DEFAULT SMS app to delete messages. Since Smart Wallet is not your default SMS app, this setting cannot delete system SMS and will remain disabled.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection view for bulk importing existing SMS
// ─────────────────────────────────────────────────────────────────────────────

class SmsImportSelectionView extends ConsumerStatefulWidget {
  final List<ParsedSmsTransaction> transactions;
  final bool duplicateProtection;
  final bool autoCategory;

  const SmsImportSelectionView({
    super.key,
    required this.transactions,
    required this.duplicateProtection,
    required this.autoCategory,
  });

  @override
  ConsumerState<SmsImportSelectionView> createState() => _SmsImportSelectionViewState();
}

class _SmsImportSelectionViewState extends ConsumerState<SmsImportSelectionView> {
  late List<bool> _selected;
  late List<ParsedSmsTransaction> _txList;
  late List<String> _predictedCategoryIds;
  late List<String?> _selectedAccountIds;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _txList = List.from(widget.transactions);
    _selected = List.filled(_txList.length, true);
    _predictedCategoryIds = List.filled(_txList.length, 'cat_uncategorized');
    _selectedAccountIds = List.filled(_txList.length, null);
    _predictCategoriesAndAccounts();
  }

  void _predictCategoriesAndAccounts() {
    final categories = ref.read(allCategoriesProvider).value ?? [];
    final accounts = ref.read(allAccountsProvider).value ?? [];
    final defaultAccId = ref.read(defaultAccountIdProvider);

    for (var i = 0; i < _txList.length; i++) {
      final tx = _txList[i];
      if (widget.autoCategory) {
        _predictedCategoryIds[i] = CategoryPredictor.predict(
          tx.merchant,
          categories,
          tx.type == SmsTransactionType.debit,
        );
      }
      
      // Match bank account suffix if possible, or fallback to default account
      final matchedAcc = accounts.where((a) {
        final normName = a.name.toLowerCase();
        final normBank = tx.bankName.toLowerCase();
        return normName.contains(normBank) || (tx.accountOrCard.toLowerCase().contains(a.id.replaceAll('acc_', '')));
      }).firstOrNull;
      
      _selectedAccountIds[i] = matchedAcc?.id ?? defaultAccId;
    }
  }

  Future<void> _importSelected() async {
    setState(() => _importing = true);

    try {
      final repoSms = ref.read(smsImportRepositoryProvider);
      final repoExpense = ref.read(expenseRepositoryProvider);
      final repoIncome = ref.read(incomeRepositoryProvider);

      var count = 0;

      for (var i = 0; i < _txList.length; i++) {
        if (!_selected[i]) continue;

        final tx = _txList[i];
        final catId = _predictedCategoryIds[i];
        final accId = _selectedAccountIds[i];

        if (tx.type == SmsTransactionType.debit) {
          final expense = domain.Expense(
            id: tx.smsHash,
            amount: tx.amount,
            categoryId: catId,
            date: tx.dateTime,
            note: 'SMS Import - ${tx.bankName}: ${tx.rawSms}',
            accountId: accId,
          );
          await repoExpense.addExpense(expense);
        } else {
          final income = domain.Income(
            id: tx.smsHash,
            amount: tx.amount,
            source: tx.merchant,
            date: tx.dateTime,
            isRecurring: false,
            frequency: domain.IncomeFrequency.oneOff,
            accountId: accId,
          );
          await repoIncome.addIncome(income);
        }

        // Mark SMS as processed
        await repoSms.markAsProcessed(
          hash: tx.smsHash,
          sender: tx.sender,
          date: tx.dateTime,
          referenceNumber: tx.referenceNumber,
          amount: tx.amount,
        );

        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $count transactions.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  void _editTransaction(int index) async {
    final tx = _txList[index];
    final defaultAccId = ref.read(defaultAccountIdProvider);

    domain.Expense? expense;
    domain.Income? income;

    if (tx.type == SmsTransactionType.debit) {
      expense = domain.Expense(
        id: tx.smsHash,
        amount: tx.amount,
        categoryId: _predictedCategoryIds[index],
        date: tx.dateTime,
        note: 'SMS Import - ${tx.bankName}: ${tx.rawSms}',
        accountId: _selectedAccountIds[index] ?? defaultAccId,
      );
    } else {
      income = domain.Income(
        id: tx.smsHash,
        amount: tx.amount,
        source: tx.merchant,
        date: tx.dateTime,
        isRecurring: false,
        frequency: domain.IncomeFrequency.oneOff,
        accountId: _selectedAccountIds[index] ?? defaultAccId,
      );
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EntryFormView(
          initialExpense: expense,
          initialIncome: income,
          initialIsExpense: tx.type == SmsTransactionType.debit,
        ),
      ),
    );

    // If successfully saved in the form directly, we deselect it so it won't be imported again in bulk.
    if (result == true && mounted) {
      // Mark as processed in duplicate tracker too
      await ref.read(smsImportRepositoryProvider).markAsProcessed(
        hash: tx.smsHash,
        sender: tx.sender,
        date: tx.dateTime,
        referenceNumber: tx.referenceNumber,
        amount: tx.amount,
      );

      setState(() {
        _selected[index] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider).value ?? [];
    final accounts = ref.watch(allAccountsProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Transactions to Import'),
        actions: [
          if (!_importing)
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () {
                final allSelected = _selected.every((b) => b);
                setState(() {
                  _selected = List.filled(_selected.length, !allSelected);
                });
              },
            ),
        ],
      ),
      body: _importing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _txList.length,
                    itemBuilder: (ctx, idx) {
                      final tx = _txList[idx];
                      final isSelected = _selected[idx];
                      final isExpense = tx.type == SmsTransactionType.debit;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() {
                                  _selected[idx] = val ?? false;
                                });
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tx.merchant,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${isExpense ? '-' : '+'}${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isExpense ? AppColors.secondary : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${tx.bankName} • ${tx.paymentMethod} • ${tx.dateTime.toString().split(' ')[0]}',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  if (isExpense) ...[
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _predictedCategoryIds[idx],
                                        decoration: const InputDecoration(
                                          labelText: 'Category',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        items: categories.map((c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name, style: const TextStyle(fontSize: 12)),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _predictedCategoryIds[idx] = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedAccountIds[idx],
                                      decoration: const InputDecoration(
                                        labelText: 'Account',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      items: accounts.map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name, style: const TextStyle(fontSize: 12)),
                                      )).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedAccountIds[idx] = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    onPressed: () => _editTransaction(idx),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primaryLight,
                                      foregroundColor: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selected.any((b) => b) ? _importSelected : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.divider,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Import Selected Transactions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_wallet/data/services/notification_service.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/reports/views/report_view.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/data/services/csv_export_service.dart';
import 'package:smart_wallet/data/services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  @override
  void initState() {
    super.initState();
    _loadReminderPref();
  }

  Future<void> _loadReminderPref() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('reminders_enabled') ?? true;
    ref.read(remindersEnabledProvider.notifier).state = enabled;
    if (enabled) {
      await NotificationService().scheduleReminders();
    }
  }

  Future<void> _toggleReminders(bool value) async {
    ref.read(remindersEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', value);
    if (value) {
      await NotificationService().scheduleReminders();
    } else {
      await NotificationService().cancelReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(openRouterApiKeyProvider);
    final isConfigured = apiKey.isNotEmpty;
    final remindersOn = ref.watch(remindersEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              icon: Icons.check_circle_rounded,
              title: 'System Status',
              child: Column(
                children: [
                  _StatusRow(
                    icon: Icons.storage_rounded,
                    title: 'Storage',
                    subtitle: 'Offline-First (SQLite)',
                  ),
                  const SizedBox(height: 12),
                  _StatusRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Intelligence',
                    subtitle: isConfigured
                        ? 'OpenRouter Activated'
                        : 'Not Configured',
                    subtitleColor: isConfigured ? null : AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  _StatusRow(
                    icon: Icons.security_rounded,
                    title: 'Data Privacy',
                    subtitle: 'All transactions stay local',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.notifications_rounded,
              title: 'Reminders',
              trailing: Switch(
                value: remindersOn,
                onChanged: _toggleReminders,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                activeThumbColor: AppColors.primary,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remindersOn
                              ? 'Daily reminders on'
                              : 'Daily reminders off',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '12:00 PM & 8:00 PM notifications',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remindersOn)
                    TextButton(
                      onPressed: () {
                        NotificationService().showTestNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test notification sent')),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Test'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CurrencySection(),
            const SizedBox(height: 12),
            _SectionCard(
              icon: isConfigured ? Icons.vpn_key_rounded : Icons.vpn_key_off_rounded,
              title: 'OpenRouter API',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isConfigured ? 'Active' : 'Missing',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isConfigured ? AppColors.primary : AppColors.secondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConfigured
                        ? 'Your OpenRouter API key is configured. AI features are ready.'
                        : 'No API key found. Add it to your .env file and restart.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.description_rounded,
              title: 'Reports',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Generate monthly financial reports as PDF',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.table_chart_rounded,
              title: 'Google Sheets Sync',
              child: const _GoogleSheetsSyncSection(),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.info_outline_rounded,
              title: 'About',
              trailing: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.text.withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your personal income & expense ledger. Add income or scan receipts to pre-fill expense entries. Get AI-powered spending insights.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Version',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text.withValues(alpha: 0.6),
                        ),
                      ),
                      const Text(
                        '1.0.0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Data',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text.withValues(alpha: 0.6),
                        ),
                      ),
                      const Text(
                        'Offline-First',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
                if (trailing != null) ...[const Spacer(), trailing!],
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

class _CurrencySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final sym = currencySymbol(code);
    return _SectionCard(
      icon: Icons.currency_exchange_rounded,
      title: 'Currency',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPicker(context, ref, code),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$sym ($code)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Currency',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (final c in supportedCurrencies)
                  ListTile(
                    leading: Text(
                      currencySymbol(c).trim(),
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(c, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: c == current
                        ? const Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(currencyCodeProvider.notifier).state = c;
                      saveCurrencyPref(c);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
     ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.text.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor ?? AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleSheetsSyncSection extends ConsumerWidget {
  const _GoogleSheetsSyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showSyncBottomSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Configure and sync data to your Google Sheet',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GoogleSheetsSyncBottomSheet(),
    );
  }
}

class _GoogleSheetsSyncBottomSheet extends ConsumerStatefulWidget {
  const _GoogleSheetsSyncBottomSheet();

  @override
  ConsumerState<_GoogleSheetsSyncBottomSheet> createState() =>
      _GoogleSheetsSyncBottomSheetState();
}

class _GoogleSheetsSyncBottomSheetState
    extends ConsumerState<_GoogleSheetsSyncBottomSheet> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isSyncing = false;
  String _savedUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    setState(() => _isLoading = true);
    final service = ref.read(googleSheetsSyncServiceProvider);
    final url = await service.getSavedUrl();
    setState(() {
      _savedUrl = url;
      _urlController.text = url;
      _isLoading = false;
    });
  }

  Future<void> _saveUrl() async {
    final service = ref.read(googleSheetsSyncServiceProvider);
    await service.saveUrl(_urlController.text);
    setState(() {
      _savedUrl = _urlController.text.trim();
    });
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Web App URL first.')),
      );
      return;
    }

    if (!url.contains('/exec')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL must end with "/exec". Check deployment settings.')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final service = ref.read(googleSheetsSyncServiceProvider);
      final result = await service.syncDatabase(
        expenses: [],
        incomes: [],
        categories: [],
        webAppUrl: url,
      );

      if (!mounted) return;
      setState(() => _isSyncing = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Connected! Sheet: ${result.spreadsheetName ?? 'Unknown'}'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded, color: AppColors.secondary, size: 40),
            title: const Text('Connection Test Failed'),
            content: Text(
              result.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e'), backgroundColor: AppColors.secondary),
      );
    }
  }

  Future<void> _exportToCsv() async {
    setState(() => _isSyncing = true);
    try {
      List<domain.Income> incomes = [];
      List<domain.Expense> expenses = [];
      List<domain.Category> categories = [];

      try {
        incomes = await ref.read(incomeRepositoryProvider).getAllIncomes();
        expenses = await ref.read(expenseRepositoryProvider).getAllExpenses();
        categories = await ref.read(expenseRepositoryProvider).getAllCategories();
      } catch (_) {
        incomes = ref.read(allIncomesProvider).value ?? [];
        expenses = ref.read(allExpensesProvider).value ?? [];
        categories = ref.read(allCategoriesProvider).value ?? [];
      }

      await CsvExportService().exportDataToCsv(
        incomes: incomes,
        expenses: expenses,
        categories: categories,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _importFromCsv() async {
    setState(() => _isSyncing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final importResult = await CsvImportService().importDataFromCsv(
        file: file,
        incomeRepository: ref.read(incomeRepositoryProvider),
        expenseRepository: ref.read(expenseRepositoryProvider),
      );

      if (!mounted) return;

      if (importResult.success) {
        ref.invalidate(allIncomesProvider);
        ref.invalidate(allExpensesProvider);
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(allSavingsGoalsProvider);
        ref.invalidate(allBillsProvider);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
            title: const Text('Import Successful'),
            content: Text(
              'Successfully imported:\n'
              '• ${importResult.incomesImported} incomes\n'
              '• ${importResult.expensesImported} expenses\n'
              '• ${importResult.categoriesCreated} new categories.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded, color: AppColors.secondary, size: 40),
            title: const Text('Import Failed'),
            content: Text(
              importResult.errorMessage ?? 'An unknown error occurred during import.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _triggerSync() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Web App URL first.')),
      );
      return;
    }

    // Save the URL first if it has changed
    if (url != _savedUrl) {
      await _saveUrl();
    }

    setState(() => _isSyncing = true);

    List<domain.Income> incomes = [];
    List<domain.Expense> expenses = [];
    List<domain.Category> categories = [];

    try {
      incomes = await ref.read(incomeRepositoryProvider).getAllIncomes();
      expenses = await ref.read(expenseRepositoryProvider).getAllExpenses();
      categories = await ref.read(expenseRepositoryProvider).getAllCategories();
    } catch (_) {
      // Fallback just in case
      incomes = ref.read(allIncomesProvider).value ?? [];
      expenses = ref.read(allExpensesProvider).value ?? [];
      categories = ref.read(allCategoriesProvider).value ?? [];
    }


    final service = ref.read(googleSheetsSyncServiceProvider);
    final result = await service.syncDatabase(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      webAppUrl: url,
    );

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (result.success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
          title: const Text('Sync Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your incomes and expenses have been successfully synchronized to your Google Sheet.',
                textAlign: TextAlign.center,
              ),
              if (result.spreadsheetName != null && result.spreadsheetUrl != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Destination Spreadsheet:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  result.spreadsheetName!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check the tabs named "Incomes" and "Expenses" at the bottom left of your spreadsheet.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  result.spreadsheetUrl!,
                  style: const TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline_rounded, color: AppColors.secondary, size: 40),
          title: const Text('Sync Failed'),
          content: Text(
            result.errorMessage ?? 'An unknown error occurred while communicating with the server.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _copyScript() {
    const scriptCode = '''function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    if (!ss) {
      throw new Error("This Apps Script is not bound to any Google Sheet. Please open your Google Sheet, go to Extensions > Apps Script, and paste the code there.");
    }
    
    // TEST MODE: return sheet info without modifying data
    if (data.test === true) {
      return ContentService.createTextOutput(JSON.stringify({ 
        success: true,
        spreadsheetName: ss.getName(),
        spreadsheetUrl: ss.getUrl()
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    function formatHeader(sheet, headers) {
      sheet.clear();
      sheet.appendRow(headers);
      var range = sheet.getRange(1, 1, 1, headers.length);
      range.setFontWeight("bold");
      range.setBackground("#2F6F5E");
      range.setFontColor("#FFFFFF");
      sheet.setFrozenRows(1);
      sheet.getRange("A:Z").setHorizontalAlignment("left");
    }
    
    var incomes = data.incomes || [];
    var incomeSheet = ss.getSheetByName("Incomes") || ss.insertSheet("Incomes");
    formatHeader(incomeSheet, ["ID", "Date", "Source", "Amount", "Recurring", "Frequency"]);
    if (incomes.length > 0) {
      var rows = incomes.map(function(inc) {
        return [inc.id, inc.date, inc.source, inc.amount, inc.isRecurring ? "Yes" : "No", inc.frequency];
      });
      incomeSheet.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
    }
    
    var expenses = data.expenses || [];
    var expenseSheet = ss.getSheetByName("Expenses") || ss.insertSheet("Expenses");
    formatHeader(expenseSheet, ["ID", "Date", "Category", "Amount", "Note", "Source"]);
    if (expenses.length > 0) {
      var rows = expenses.map(function(exp) {
        return [exp.id, exp.date, exp.category, exp.amount, exp.note || "", exp.source];
      });
      expenseSheet.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
    }
    
    return ContentService.createTextOutput(JSON.stringify({ 
      success: true,
      spreadsheetName: ss.getName(),
      spreadsheetUrl: ss.getUrl()
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ success: false, error: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}''';

    Clipboard.setData(const ClipboardData(text: scriptCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apps Script copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Google Sheets Sync',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export your entire wallet database into a custom Google Sheet.',
              style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Instructions:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  _stepRow('1', 'Open the specific Google Sheet you want to use.'),
                  _stepRow('2', 'Go to Extensions > Apps Script (creates a bound script).'),
                  _stepRow('3', 'Paste the code snippet (click button below).'),
                  _stepRow('4', 'Deploy as Web App (Execute: Me, Access: Anyone).'),
                  _stepRow('5', 'Paste the Web App URL below.'),
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: When updating your code, you must deploy a NEW VERSION in Apps Script to apply changes.',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyScript,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Apps Script Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Google Sheets Web App URL',
                hintText: 'https://script.google.com/macros/s/.../exec',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              style: const TextStyle(fontSize: 13),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _testConnection,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text('Test Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _triggerSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Database Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            const Text(
              'Prefer a manual backup or import?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSyncing ? null : _exportToCsv,
                      icon: const Icon(Icons.file_download_rounded, size: 18),
                      label: const Text('Export CSV'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSyncing ? null : _importFromCsv,
                      icon: const Icon(Icons.file_upload_rounded, size: 18),
                      label: const Text('Import CSV'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

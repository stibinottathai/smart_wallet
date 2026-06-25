import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_wallet/data/services/notification_service.dart';
import 'package:smart_wallet/data/services/notification_coordinator.dart';
import 'package:smart_wallet/ui/features/lock/views/lock_screen.dart';
import 'package:smart_wallet/ui/features/lock/views/pin_setup_view.dart';
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
  /// Whether the device has biometric hardware + enrolled biometrics. Gates the
  /// "Unlock with biometrics" row so it only appears where it can work.
  bool _biometricCapable = false;

  @override
  void initState() {
    super.initState();
    _loadReminderPref();
    _loadLockState();
  }

  Future<void> _loadReminderPref() async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(remindersEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.remindersPrefKey) ?? true;
    ref.read(budgetAlertsEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.budgetAlertsPrefKey) ?? true;
    ref.read(dailyTipEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.dailyTipPrefKey) ?? true;
    await _syncNotifications();
  }

  Future<void> _loadLockState() async {
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isLockEnabled() && await service.hasPin();
    final biometricOn = await service.isBiometricEnabled();
    final capable = await service.canUseBiometrics();
    if (!mounted) return;
    ref.read(appLockEnabledProvider.notifier).state = enabled;
    ref.read(biometricEnabledProvider.notifier).state = biometricOn;
    setState(() => _biometricCapable = capable);
  }

  Future<void> _toggleAppLock(bool value) async {
    final service = ref.read(appLockServiceProvider);
    if (value) {
      // Enabling — set a PIN first; only flips on if the user completes setup.
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupView()),
      );
      if (created == true) {
        await _loadLockState();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App lock enabled')),
          );
        }
      }
    } else {
      // Disabling — require the user to authenticate first.
      final confirmed = await _confirmIdentity();
      if (confirmed) {
        await service.disableLock();
        ref.read(appLockEnabledProvider.notifier).state = false;
        ref.read(biometricEnabledProvider.notifier).state = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App lock disabled')),
          );
        }
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final service = ref.read(appLockServiceProvider);
    if (value && !await service.canUseBiometrics()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No biometrics enrolled on this device'),
          ),
        );
      }
      return;
    }
    await service.setBiometricEnabled(value);
    ref.read(biometricEnabledProvider.notifier).state = value;
  }

  Future<void> _changePin() async {
    // Re-authenticate, then set a fresh PIN.
    final confirmed = await _confirmIdentity();
    if (!confirmed || !mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupView()),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated')),
      );
    }
  }

  /// Pushes a [LockScreen] in verify mode; resolves true once authenticated.
  Future<bool> _confirmIdentity() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => LockScreen(
          showCancel: true,
          title: 'Confirm your PIN to continue',
          onUnlocked: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    return result ?? false;
  }

  /// Re-evaluates and re-schedules all notifications from the current data and
  /// preferences.
  Future<void> _syncNotifications() async {
    final expenses = ref.read(allExpensesProvider).value ?? [];
    final categories = ref.read(allCategoriesProvider).value ?? [];
    await NotificationCoordinator.sync(
      expenses: expenses,
      categories: categories,
      incomes: ref.read(allIncomesProvider).value ?? [],
      currencySymbol: currencySymbol(ref.read(currencyCodeProvider)),
    );
  }

  Future<void> _toggleReminders(bool value) async {
    ref.read(remindersEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.remindersPrefKey, value);
    await _syncNotifications();
  }

  Future<void> _toggleBudgetAlerts(bool value) async {
    ref.read(budgetAlertsEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.budgetAlertsPrefKey, value);
    await _syncNotifications();
  }

  Future<void> _toggleDailyTip(bool value) async {
    ref.read(dailyTipEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.dailyTipPrefKey, value);
    await _syncNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(openRouterApiKeyProvider);
    final isConfigured = apiKey.isNotEmpty;
    final remindersOn = ref.watch(remindersEnabledProvider);
    final budgetAlertsOn = ref.watch(budgetAlertsEnabledProvider);
    final dailyTipOn = ref.watch(dailyTipEnabledProvider);
    final appLockOn = ref.watch(appLockEnabledProvider);
    final biometricOn = ref.watch(biometricEnabledProvider);

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
              icon: Icons.lock_rounded,
              title: 'App Lock',
              trailing: Switch(
                value: appLockOn,
                onChanged: _toggleAppLock,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                activeThumbColor: AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appLockOn
                        ? 'Require a PIN to open the app'
                        : 'App lock off',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appLockOn
                        ? 'Smart Wallet locks when you leave it and reopens with your PIN'
                        : 'Protect your financial data with a 4-digit PIN and biometrics',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (appLockOn) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    // Biometric toggle (only where the device supports it).
                    if (_biometricCapable)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: biometricOn,
                        onChanged: _toggleBiometric,
                        activeTrackColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Unlock with biometrics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: const Text(
                          'Use fingerprint or face to unlock',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _changePin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.password_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Change PIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                          const SnackBar(
                            content: Text('Test notification sent'),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Test'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Budget Alerts',
              trailing: Switch(
                value: budgetAlertsOn,
                onChanged: _toggleBudgetAlerts,
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
                          budgetAlertsOn
                              ? 'Budget limit alerts on'
                              : 'Budget limit alerts off',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get notified (up to 4×/day) when a category reaches 80% of its monthly limit',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Daily Insight',
              trailing: Switch(
                value: dailyTipOn,
                onChanged: _toggleDailyTip,
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
                          dailyTipOn
                              ? 'Daily savings tip on'
                              : 'Daily savings tip off',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'An 8:00 AM summary of your finances with a personalised savings tip based on your data',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CurrencySection(),
            const SizedBox(height: 12),

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
              icon: Icons.swap_vertical_circle_rounded,
              title: 'CSV Data Portability',
              child: const _CsvImportExportSection(),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.info_outline_rounded,
              title: 'About',
              trailing: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: AppColors.text.withValues(alpha: 0.3),
              ),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Developer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text.withValues(alpha: 0.6),
                        ),
                      ),
                      const Text(
                        'Stibin Augustine',
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
                      title: Text(
                        c,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: c == current
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                            )
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

class _CsvImportExportSection extends ConsumerStatefulWidget {
  const _CsvImportExportSection();

  @override
  ConsumerState<_CsvImportExportSection> createState() =>
      _CsvImportExportSectionState();
}

class _CsvImportExportSectionState
    extends ConsumerState<_CsvImportExportSection> {
  bool _isProcessing = false;

  Future<({
    List<domain.Income> incomes,
    List<domain.Expense> expenses,
    List<domain.Category> categories,
    List<domain.SavingsGoal> goals,
    List<domain.Bill> bills,
  })> _collectData() async {
    List<domain.Income> incomes = [];
    List<domain.Expense> expenses = [];
    List<domain.Category> categories = [];
    List<domain.SavingsGoal> goals = [];
    List<domain.Bill> bills = [];

    try {
      incomes = await ref.read(incomeRepositoryProvider).getAllIncomes();
      expenses = await ref.read(expenseRepositoryProvider).getAllExpenses();
      categories = await ref.read(expenseRepositoryProvider).getAllCategories();
      goals = await ref.read(savingsGoalRepositoryProvider).getAllGoals();
      bills = await ref.read(billRepositoryProvider).getAllBills();
    } catch (_) {
      incomes = ref.read(allIncomesProvider).value ?? [];
      expenses = ref.read(allExpensesProvider).value ?? [];
      categories = ref.read(allCategoriesProvider).value ?? [];
      goals = ref.read(allSavingsGoalsProvider).value ?? [];
      bills = ref.read(allBillsProvider).value ?? [];
    }

    return (
      incomes: incomes,
      expenses: expenses,
      categories: categories,
      goals: goals,
      bills: bills,
    );
  }

  Future<void> _downloadCsv() async {
    setState(() => _isProcessing = true);
    try {
      final data = await _collectData();

      final service = CsvExportService();
      final csvContent = service.buildCsvContent(
        incomes: data.incomes,
        expenses: data.expenses,
        categories: data.categories,
        goals: data.goals,
        bills: data.bills,
      );

      final result = await FilePicker.saveFile(
        dialogTitle: 'Save CSV file',
        fileName: 'smart_wallet_export.csv',
        bytes: Uint8List.fromList(utf8.encode(csvContent)),
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('CSV file saved successfully'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save CSV: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Writes the export to a temp file and opens the system share sheet, which
  /// includes "Save to Drive" / Google Drive as a destination.
  Future<void> _shareCsv() async {
    setState(() => _isProcessing = true);
    try {
      final data = await _collectData();
      await CsvExportService().exportDataToCsv(
        incomes: data.incomes,
        expenses: data.expenses,
        categories: data.categories,
        goals: data.goals,
        bills: data.bills,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share CSV: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _importFromCsv() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final importResult = await CsvImportService().importDataFromCsv(
        file: file,
        incomeRepository: ref.read(incomeRepositoryProvider),
        expenseRepository: ref.read(expenseRepositoryProvider),
        savingsGoalRepository: ref.read(savingsGoalRepositoryProvider),
        billRepository: ref.read(billRepositoryProvider),
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
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 40,
            ),
            title: const Text('Import Successful'),
            content: Text(
              'Successfully imported:\n'
              '• ${importResult.incomesImported} incomes\n'
              '• ${importResult.expensesImported} expenses\n'
              '• ${importResult.categoriesCreated} new categories\n'
              '• ${importResult.budgetsImported} budget limits\n'
              '• ${importResult.goalsImported} savings goals\n'
              '• ${importResult.billsImported} bills & subscriptions.',
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
            icon: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.secondary,
              size: 40,
            ),
            title: const Text('Import Failed'),
            content: Text(
              importResult.errorMessage ??
                  'An unknown error occurred during import.',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import CSV: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Back up your full ledger to a CSV file — transactions, monthly budget limits, savings goals, and upcoming bills & subscriptions — then restore it all on a new device or after reinstalling.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.text.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _downloadCsv,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.file_download_rounded, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _importFromCsv,
                  icon: const Icon(Icons.file_upload_rounded, size: 18),
                  label: const Text('Import'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _shareCsv,
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Save to Google Drive / Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: "Save to Google Drive" opens the share sheet — pick Drive to upload. To restore, tap Import and browse to Google Drive in the file picker.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.text.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

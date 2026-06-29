import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_wallet/data/services/notification_service.dart';
import 'package:smart_wallet/data/services/notification_coordinator.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/onboarding/onboarding_view.dart';
import 'package:smart_wallet/ui/features/reports/views/report_view.dart';
import 'package:smart_wallet/ui/features/accounts/views/accounts_view.dart';
import 'package:smart_wallet/ui/features/recurring/views/recurring_view.dart';
import 'package:smart_wallet/ui/features/subscriptions/views/subscriptions_view.dart';
import 'package:smart_wallet/ui/features/forecast/views/forecast_view.dart';
import 'package:smart_wallet/ui/features/debts/views/debts_view.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/animated_section.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/data/services/csv_export_service.dart';
import 'package:smart_wallet/data/services/csv_import_service.dart';
import 'package:smart_wallet/data/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  /// Re-shows the one-time onboarding flow on demand. Pops back to Settings
  /// once finished or skipped.
  void _replayOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OnboardingView(
          onComplete: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.stibin.smartwallet',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'stibinaugustine3047@gmail.com',
      queryParameters: {'subject': 'Smart Wallet Feedback'},
    );
    await launchUrl(uri);
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Check out Smart Wallet — your personal finance manager!\nhttps://play.google.com/store/apps/details?id=com.stibin.smartwallet',
      ),
    );
  }


  /// Wraps each card with a staggered entrance animation while leaving the
  /// [SizedBox] spacers static. The cascade replays each time the Settings tab
  /// becomes active.
  List<Widget> _staggerCards(List<Widget> children, int tabIndex) {
    var i = 0;
    return children
        .map((w) => w is SizedBox
            ? w
            : AnimatedSection(index: i++, tabIndex: tabIndex, child: w))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _staggerCards([
            _AiSettingsSection(),
            const SizedBox(height: 12),
            _CurrencySection(),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Accounts & Wallets',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AccountsView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Manage cash, bank, card & UPI accounts and transfers',
                          style: TextStyle(
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
              icon: Icons.repeat_rounded,
              title: 'Recurring Transactions',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RecurringView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Auto-add rent, subscriptions & salary on a schedule',
                          style: TextStyle(
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
              icon: Icons.handshake_rounded,
              title: 'Debts & Loans',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DebtsView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Track money borrowed or lent, EMIs and payoff progress',
                          style: TextStyle(
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
              icon: Icons.subscriptions_rounded,
              title: 'Subscriptions',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SubscriptionsView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'See recurring merchants & your total monthly subscription cost',
                          style: TextStyle(
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
              icon: Icons.timeline_rounded,
              title: 'Cash Flow Forecast',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForecastView()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Project your future balance from recurring rules, bills & EMIs',
                          style: TextStyle(
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
              icon: Icons.notifications_active_rounded,
              title: 'Notifications & Battery',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const NotificationSettingsView())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reminders, budget alerts, daily insight & background delivery',
                          style: TextStyle(
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
              icon: Icons.policy_rounded,
              title: 'Privacy Policy',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => launchUrl(
                  Uri.parse('https://stibinottathai.github.io/smart-wallet-privacy-policy/'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Read how we collect, use and protect your data',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.info_outline_rounded,
              title: 'About',
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
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  _AboutInfoRow(label: 'Version', value: '1.0.2'),
                  _AboutInfoRow(label: 'Data', value: 'Offline-First'),
                  _AboutInfoRow(label: 'Developer', value: 'Stibin Augustine'),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 2),
                  _AboutActionRow(
                    icon: Icons.star_rounded,
                    label: 'Rate App',
                    onTap: _rateApp,
                  ),
                  _AboutActionRow(
                    icon: Icons.feedback_rounded,
                    label: 'Send Feedback',
                    onTap: _sendFeedback,
                  ),
                  _AboutActionRow(
                    icon: Icons.share_rounded,
                    label: 'Share App',
                    onTap: _shareApp,
                  ),
                  _AboutActionRow(
                    icon: Icons.auto_awesome_rounded,
                    label: 'View App Tour',
                    onTap: _replayOnboarding,
                  ),
                ],
              ),
            ),
          ], 4),
        ),
      ),
    );
  }
}

/// Dedicated page for notification preferences (reminders, budget alerts, daily
/// insight) and Android background-delivery / battery-optimization controls.
/// Opened from the "Notifications & Battery" tile in Settings.
class NotificationSettingsView extends ConsumerStatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  ConsumerState<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState
    extends ConsumerState<NotificationSettingsView> {
  @override
  void initState() {
    super.initState();
    _loadReminderPref();
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

  /// When the user turns a notification feature on, make sure the OS will
  /// actually deliver it in the background (exact alarms + battery exemption).
  Future<void> _ensureBackgroundDelivery() async {
    await NotificationService().requestBackgroundDeliveryPermissions();
  }

  Future<void> _toggleReminders(bool value) async {
    ref.read(remindersEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.remindersPrefKey, value);
    if (value) await _ensureBackgroundDelivery();
    await _syncNotifications();
  }

  Future<void> _toggleBudgetAlerts(bool value) async {
    ref.read(budgetAlertsEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.budgetAlertsPrefKey, value);
    if (value) await _ensureBackgroundDelivery();
    await _syncNotifications();
  }

  Future<void> _toggleDailyTip(bool value) async {
    ref.read(dailyTipEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationCoordinator.dailyTipPrefKey, value);
    if (value) await _ensureBackgroundDelivery();
    await _syncNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final remindersOn = ref.watch(remindersEnabledProvider);
    final budgetAlertsOn = ref.watch(budgetAlertsEnabledProvider);
    final dailyTipOn = ref.watch(dailyTipEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & Battery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _GroupHeader(
              icon: Icons.notifications_active_rounded,
              title: 'Reminders',
            ),
            const SizedBox(height: 8),
            _SectionCard(
              icon: Icons.notifications_rounded,
              title: 'Reminders',
              trailing: Switch(
                value: remindersOn,
                onChanged: _toggleReminders,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                activeThumbColor: AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remindersOn ? 'Daily reminders on' : 'Daily reminders off',
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
                    'A 6:40 PM summary of your finances with a personalised savings tip based on your data',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _GroupHeader(
              icon: Icons.battery_saver_rounded,
              title: 'Background Delivery',
            ),
            const SizedBox(height: 8),
            const _BackgroundDeliverySection(),
          ],
        ),
      ),
    );
  }
}

/// A small label that visually groups the cards beneath it under one heading.
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _GroupHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagnostics + one-tap fix for the #1 reason scheduled notifications don't
/// fire when the app is closed: OEM battery optimization. Also lets the user run
/// a real scheduled (not instant) test to prove background delivery works.
class _BackgroundDeliverySection extends StatefulWidget {
  const _BackgroundDeliverySection();

  @override
  State<_BackgroundDeliverySection> createState() =>
      _BackgroundDeliverySectionState();
}

class _BackgroundDeliverySectionState
    extends State<_BackgroundDeliverySection> {
  bool? _batteryOk;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = NotificationService();
    final battery = await service.isBatteryOptimizationDisabled();
    final pending = await service.pendingCount();
    if (!mounted) return;
    setState(() {
      _batteryOk = battery;
      _pending = pending;
    });
  }

  Future<void> _fix() async {
    await NotificationService().requestBackgroundDeliveryPermissions();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('If a system screen opened, allow the app to run '
            'unrestricted, then return here.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ok = _batteryOk ?? false;
    return _SectionCard(
      icon: Icons.battery_saver_rounded,
      title: 'Background Delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: ok ? AppColors.primary : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? 'Battery optimization is OFF — notifications can fire when the app is closed.'
                      : 'Battery optimization is ON — Android may block notifications while the app is closed.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_pending notification(s) currently scheduled with the system.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _fix,
              icon: const Icon(Icons.settings_suggest_rounded, size: 18),
              label: const Text('Allow background notifications'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open app settings'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: if reminders don\'t arrive when the app is closed, your device '
            'is likely killing it — turn off battery optimization above (and '
            'enable Autostart on Xiaomi/Oppo/Vivo).',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.text.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
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

class _AiSettingsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<_AiSettingsSection> {
  void _editSettings() {
    showDialog(
      context: context,
      builder: (context) => const _AiSettingsDialog(),
    );
  }

  void _showApiGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Configuration Guide'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To use the AI Assistant, you need an API key from one of the supported providers.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text('1. OpenRouter (Recommended - Free models available)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '• Go to openrouter.ai and sign up.\n'
                '• Navigate to "Keys" and click "Create Key".\n'
                '• Copy the generated key and paste it here.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text('2. Anthropic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '• Go to console.anthropic.com and sign up.\n'
                '• Navigate to Settings > API Keys and create a new key.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text('3. OpenAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '• Go to platform.openai.com and sign up.\n'
                '• Navigate to API Keys in the dashboard and create a new secret key.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(aiApiKeyProvider);
    final provider = ref.watch(aiProviderProvider);
    final isConfigured = apiKey.isNotEmpty;
    return _SectionCard(
      icon: Icons.api_rounded,
      title: 'AI Configuration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Provider',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              Text(
                provider.displayName,
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
                'API Key',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              Text(
                isConfigured ? 'Configured' : 'Not Configured',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isConfigured ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Model',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  ref.watch(aiModelProvider),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _editSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Configure AI Settings'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _showApiGuide,
              child: const Text(
                'API Configuration Guide',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSettingsDialog extends ConsumerStatefulWidget {
  const _AiSettingsDialog();

  @override
  ConsumerState<_AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends ConsumerState<_AiSettingsDialog> {
  late TextEditingController _keyCtrl;
  late TextEditingController _customModelCtrl;
  late domain.AiProvider _selectedProvider;
  String? _selectedModel;
  bool _isCustomModel = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = ref.read(aiProviderProvider);
    _keyCtrl = TextEditingController(text: ref.read(aiApiKeyProvider));
    
    final currentModel = ref.read(aiModelProvider);
    if (_selectedProvider.commonModels.contains(currentModel)) {
      _selectedModel = currentModel;
    } else if (currentModel.isEmpty &&
        _selectedProvider.commonModels.isNotEmpty) {
      // Nothing configured yet — default to the provider's first common model
      // (DeepSeek for OpenRouter) rather than the custom option.
      _selectedModel = _selectedProvider.commonModels.first;
    } else {
      _selectedModel = 'Other (Custom)';
      _isCustomModel = true;
    }
    _customModelCtrl = TextEditingController(text: _isCustomModel ? currentModel : '');
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final key = _keyCtrl.text.trim();
    final model = _isCustomModel ? _customModelCtrl.text.trim() : (_selectedModel ?? '');
    
    ref.read(aiProviderProvider.notifier).state = _selectedProvider;
    ref.read(aiApiKeyProvider.notifier).state = key;
    ref.read(aiModelProvider.notifier).state = model;
    
    saveAiProvider(_selectedProvider);
    saveAiApiKey(key);
    saveAiModel(model);
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final availableModels = [..._selectedProvider.commonModels, 'Other (Custom)'];
    if (!_isCustomModel && _selectedModel != null && !availableModels.contains(_selectedModel)) {
      _selectedModel = availableModels.first;
    }

    return AlertDialog(
      title: const Text('AI Configuration'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your preferred AI provider, model, and API key.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<domain.AiProvider>(
              isExpanded: true,
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: domain.AiProvider.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedProvider = val;
                    _selectedModel = val.commonModels.isNotEmpty ? val.commonModels.first : 'Other (Custom)';
                    _isCustomModel = _selectedModel == 'Other (Custom)';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: availableModels.contains(_selectedModel) ? _selectedModel : availableModels.first,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
              items: availableModels.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedModel = val;
                    _isCustomModel = val == 'Other (Custom)';
                  });
                }
              },
            ),
            if (_isCustomModel) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customModelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Model Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. custom-model-v1',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
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

class _AboutInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AboutActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
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
    List<domain.RecurringRule> recurringRules,
    List<domain.Debt> debts,
    List<domain.Account> accounts,
    List<domain.Transfer> transfers,
  })> _collectData() async {
    List<domain.Income> incomes = [];
    List<domain.Expense> expenses = [];
    List<domain.Category> categories = [];
    List<domain.SavingsGoal> goals = [];
    List<domain.Bill> bills = [];
    List<domain.RecurringRule> recurringRules = [];
    List<domain.Debt> debts = [];
    List<domain.Account> accounts = [];
    List<domain.Transfer> transfers = [];

    try {
      incomes = await ref.read(incomeRepositoryProvider).getAllIncomes();
      expenses = await ref.read(expenseRepositoryProvider).getAllExpenses();
      categories = await ref.read(expenseRepositoryProvider).getAllCategories();
      goals = await ref.read(savingsGoalRepositoryProvider).getAllGoals();
      bills = await ref.read(billRepositoryProvider).getAllBills();
      recurringRules = await ref.read(recurringRuleRepositoryProvider).getAllRules();
      debts = await ref.read(debtRepositoryProvider).getAllDebts();
      accounts = await ref.read(accountRepositoryProvider).getAllAccounts();
      transfers = await ref.read(transferRepositoryProvider).getAllTransfers();
    } catch (_) {
      incomes = ref.read(allIncomesProvider).value ?? [];
      expenses = ref.read(allExpensesProvider).value ?? [];
      categories = ref.read(allCategoriesProvider).value ?? [];
      goals = ref.read(allSavingsGoalsProvider).value ?? [];
      bills = ref.read(allBillsProvider).value ?? [];
      recurringRules = ref.read(allRecurringRulesProvider).value ?? [];
      debts = ref.read(allDebtsProvider).value ?? [];
      accounts = ref.read(allAccountsProvider).value ?? [];
      transfers = ref.read(allTransfersProvider).value ?? [];
    }

    return (
      incomes: incomes,
      expenses: expenses,
      categories: categories,
      goals: goals,
      bills: bills,
      recurringRules: recurringRules,
      debts: debts,
      accounts: accounts,
      transfers: transfers,
    );
  }

  /// Builds the full backup as ZIP bytes: the CSV plus every receipt image it
  /// references, bundled under `images/`.
  Future<Uint8List> _buildBackupBytes() async {
    final data = await _collectData();
    final csvContent = CsvExportService().buildCsvContent(
      incomes: data.incomes,
      expenses: data.expenses,
      categories: data.categories,
      goals: data.goals,
      bills: data.bills,
      recurringRules: data.recurringRules,
      debts: data.debts,
      accounts: data.accounts,
      transfers: data.transfers,
    );
    final imagePaths =
        data.expenses.map((e) => e.receiptImagePath).whereType<String>();
    return BackupService()
        .buildBackupZip(csvContent: csvContent, imagePaths: imagePaths);
  }

  Future<void> _downloadCsv() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _buildBackupBytes();

      final result = await FilePicker.saveFile(
        dialogTitle: 'Save backup file',
        fileName: 'smart_wallet_backup.zip',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Backup saved successfully'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save backup: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Writes the backup to a temp file and opens the system share sheet, which
  /// includes "Save to Drive" / Google Drive as a destination.
  Future<void> _shareCsv() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _buildBackupBytes();
      await BackupService().shareBackupZip(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share backup: $e')));
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
        allowedExtensions: ['zip', 'csv'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);

      // A ZIP backup carries receipt images; extract them into permanent
      // storage and re-point each expense at the restored image. A plain CSV
      // (older export) is read directly with no images.
      String csvContent;
      String? receiptImageDir;
      if (path.toLowerCase().endsWith('.zip')) {
        final extracted = await BackupService().extractBackupZip(file);
        csvContent = extracted.csvContent;
        receiptImageDir = extracted.imageDir;
      } else {
        csvContent = await file.readAsString();
      }

      final importResult = await CsvImportService().importDataFromCsvContent(
        content: csvContent,
        incomeRepository: ref.read(incomeRepositoryProvider),
        expenseRepository: ref.read(expenseRepositoryProvider),
        savingsGoalRepository: ref.read(savingsGoalRepositoryProvider),
        billRepository: ref.read(billRepositoryProvider),
        recurringRuleRepository: ref.read(recurringRuleRepositoryProvider),
        debtRepository: ref.read(debtRepositoryProvider),
        accountRepository: ref.read(accountRepositoryProvider),
        transferRepository: ref.read(transferRepositoryProvider),
        receiptImageDir: receiptImageDir,
      );

      if (!mounted) return;

      if (importResult.success) {
        ref.invalidate(allIncomesProvider);
        ref.invalidate(allExpensesProvider);
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(allSavingsGoalsProvider);
        ref.invalidate(allBillsProvider);
        ref.invalidate(allRecurringRulesProvider);
        ref.invalidate(allDebtsProvider);
        ref.invalidate(allAccountsProvider);
        ref.invalidate(allTransfersProvider);
        ref.invalidate(accountBalancesProvider);

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
              '• ${importResult.billsImported} bills & subscriptions\n'
              '• ${importResult.recurringImported} recurring rules\n'
              '• ${importResult.debtsImported} debts & loans\n'
              '• ${importResult.accountsImported} accounts\n'
              '• ${importResult.transfersImported} transfers.',
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
        ).showSnackBar(SnackBar(content: Text('Failed to import backup: $e')));
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
          'Back up everything to a single file — transactions, accounts, transfers, budgets, savings goals, bills, recurring rules, debts and your scanned receipt images — then restore it all on a new device or after reinstalling.',
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

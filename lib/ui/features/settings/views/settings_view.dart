import 'dart:convert';
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
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/data/services/csv_export_service.dart';
import 'package:smart_wallet/data/services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
    ref.read(remindersEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.remindersPrefKey) ?? true;
    ref.read(budgetAlertsEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.budgetAlertsPrefKey) ?? true;
    ref.read(dailyTipEnabledProvider.notifier).state =
        prefs.getBool(NotificationCoordinator.dailyTipPrefKey) ?? true;
    await _syncNotifications();
  }

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
    final apiKey = ref.watch(aiApiKeyProvider);
    final provider = ref.watch(aiProviderProvider);
    final isConfigured = apiKey.isNotEmpty;
    final remindersOn = ref.watch(remindersEnabledProvider);
    final budgetAlertsOn = ref.watch(budgetAlertsEnabledProvider);
    final dailyTipOn = ref.watch(dailyTipEnabledProvider);

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
                        ? '${provider.displayName} Activated'
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
            _AiSettingsSection(),
            const SizedBox(height: 20),
            const _GroupHeader(
              icon: Icons.notifications_active_rounded,
              title: 'Notifications & Battery',
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
            const SizedBox(height: 12),
            const _BackgroundDeliverySection(),
            const SizedBox(height: 20),
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
                        '1.0.2',
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
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _replayOnboarding,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'View app tour',
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
              ),
            ),
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

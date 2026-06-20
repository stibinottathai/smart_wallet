import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_wallet/data/services/notification_service.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/animations.dart';
import 'package:smart_wallet/ui/features/reports/views/report_view.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';

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
            ).fadeSlideIn(),
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
                ],
              ),
            ).fadeSlideIn(delayMs: 60),
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
            ).fadeSlideIn(delayMs: 120),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.description_rounded,
              title: 'Reports',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(
                  context,
                ).push(AppAnimations.fadeSlideUp(const ReportView())),
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
            ).fadeSlideIn(delayMs: 180),
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
            ).fadeSlideIn(delayMs: 240),
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

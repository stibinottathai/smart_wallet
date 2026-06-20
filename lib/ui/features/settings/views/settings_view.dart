import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isInitialized = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await ref.read(openRouterApiKeyProvider.notifier).saveKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OpenRouter API Key updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      FocusScope.of(context).unfocus();
    }
  }

  void _resetToDefault() async {
    await ref.read(openRouterApiKeyProvider.notifier).saveKey('');
    _apiKeyController.text = '';
    setState(() {
      _isInitialized = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default system API Key.'),
          backgroundColor: AppColors.primary,
        ),
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUsingCustomKey = ref.watch(isUsingCustomKeyProvider);

    if (!_isInitialized) {
      final currentKey = ref.read(openRouterApiKeyProvider);
      _apiKeyController.text = currentKey;
      _isInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Info Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.primary, size: 22),
                      SizedBox(width: 8.0),
                      Text(
                        'System Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  _buildStatusRow(Icons.storage, 'Storage', 'Offline-First (Drift/SQLite)'),
                  const SizedBox(height: 12.0),
                  _buildStatusRow(Icons.auto_awesome, 'AI Intelligence', 'OpenRouter AI Activated'),
                  const SizedBox(height: 12.0),
                  _buildStatusRow(Icons.security, 'Data Privacy', 'All transactions remain local'),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // AI Configuration Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 22),
                      const SizedBox(width: 8.0),
                      const Text(
                        'AI & OpenRouter Config',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: isUsingCustomKey
                              ? AppColors.secondary.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          isUsingCustomKey ? 'Custom Key' : 'Default Key',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: isUsingCustomKey ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Customize the API key used for generating monthly spending insights and scanning receipts.',
                    style: TextStyle(fontSize: 12.0, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    style: const TextStyle(fontSize: 13.0, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'OpenRouter API Key',
                      hintText: 'sk-or-v1-...',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 20.0),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isUsingCustomKey) ...[
                        TextButton(
                          onPressed: _resetToDefault,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                          ),
                          child: const Text('Reset to Default', style: TextStyle(fontSize: 13.0)),
                        ),
                        const SizedBox(width: 12.0),
                      ],
                      ElevatedButton(
                        onPressed: _saveApiKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        ),
                        child: const Text('Save Key', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            
            // Helpful Guide Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Smart Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Your personal income and expense ledger. Add income or scan receipts to instantly pre-fill expense entries. Get monthly spending insights via on-demand AI observations.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48.0),
            
            const Divider(),
            const SizedBox(height: 24.0),
            const Text(
              'Smart Wallet v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.0, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Offline-First Personal Tracker',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.0, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.0, color: AppColors.text.withValues(alpha: 0.6)),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0),
              ),
              const SizedBox(height: 2.0),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

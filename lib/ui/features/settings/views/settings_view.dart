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
  final _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load existing key into text controller
    Future.microtask(() {
      if (mounted) {
        _keyController.text = ref.read(geminiApiKeyProvider);
      }
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _saveKey() async {
    final key = _keyController.text.trim();
    await ref.read(geminiApiKeyProvider.notifier).saveKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API Key saved successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _clearKey() async {
    await ref.read(geminiApiKeyProvider.notifier).saveKey('');
    _keyController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API Key cleared.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(geminiApiKeyProvider, (_, currentKey) {
      if (_keyController.text != currentKey) {
        _keyController.text = currentKey;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
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
                      Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8.0),
                      Text(
                        'Gemini API Settings',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'To enable receipt OCR scanning and AI spending observations, paste your Gemini API Key below. You can obtain a free key from Google AI Studio.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.7), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            TextField(
              controller: _keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _keyController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearKey,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    child: const Text('Save Key'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40.0),
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/onboarding/onboarding_view.dart';

class HelpView extends StatefulWidget {
  const HelpView({super.key});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'AI Configuration',
    'Scanning & Voice',
    'Notifications',
    'Data & Backup',
    'Accounts & Setup',
  ];

  final List<_FaqItem> _faqItems = [
    // AI Configuration
    _FaqItem(
      question: 'How do I set up the AI Assistant?',
      answer:
          'To use the AI Chat, proactive insights, or automated receipt parsing, you need an API key from a supported provider:\n\n'
          '1. Go to **Settings > AI Configuration**.\n'
          '2. Select a provider (OpenRouter, Anthropic, or OpenAI).\n'
          '3. Enter your API key and save.\n\n'
          'Note: Smart Wallet requires this key to communicate directly with the AI model on your behalf.',
      category: 'AI Configuration',
      icon: Icons.vpn_key_rounded,
    ),
    _FaqItem(
      question: 'Which AI Provider/Model is recommended?',
      answer:
          'We highly recommend **OpenRouter** because they support free models like `google/gemini-2.5-flash:free` or `meta-llama/llama-3-8b-instruct:free`. '
          'This allows you to use all AI features (receipt scanning and chat) in Smart Wallet completely free of charge!',
      category: 'AI Configuration',
      icon: Icons.recommend_rounded,
    ),
    _FaqItem(
      question: 'Is my data private when using AI features?',
      answer:
          'Smart Wallet is completely **offline-first**—your transactions, accounts, and budgets are stored locally on your device in a secure SQLite database.\n\n'
          'Only queries you type/speak in the "AI Chat" tab or text extracted from scanned receipts are sent to your selected AI provider for processing. None of your database files, settings, or backups are uploaded.',
      category: 'AI Configuration',
      icon: Icons.security_rounded,
    ),

    // Scanning & Voice
    _FaqItem(
      question: 'How do I scan receipts or bills?',
      answer:
          '1. Go to the **Transactions** tab.\n'
          '2. Tap the **floating scan icon** (bottom right).\n'
          '3. Pick an image from your gallery or scan a receipt using your camera.\n\n'
          'The app uses Google ML Kit OCR on-device to read text, then uses your AI API key to automatically extract the amount, merchant, date, and category to pre-fill the transaction form.',
      category: 'Scanning & Voice',
      icon: Icons.document_scanner_rounded,
    ),
    _FaqItem(
      question: 'Why is the receipt scanner failing?',
      answer:
          'Receipt parsing requires two things:\n'
          '• A configured **AI API Key** in Settings (as the AI structures the raw OCR text).\n'
          '• A clear, well-lit photograph of the receipt.\n\n'
          'If it fails, please check your internet connection and confirm your API Key is valid under Settings.',
      category: 'Scanning & Voice',
      icon: Icons.error_outline_rounded,
    ),
    _FaqItem(
      question: 'How do I log transactions using voice commands?',
      answer:
          'Go to the **AI Chat** tab and tap the microphone icon next to the message input.\n\n'
          'Dictate your command naturally. For example: *"Spent 50 dollars for transport today"* or *"Received 1500 dollars salary"*. The AI will parse it and show a transaction confirmation card. Tap **Confirm** to save.',
      category: 'Scanning & Voice',
      icon: Icons.mic_rounded,
    ),
    _FaqItem(
      question: 'Why do voice/scan features need permissions?',
      answer:
          '• **Microphone**: Needed for voice dictation in AI Chat. Voice processing is done locally via on-device speech-to-text.\n'
          '• **Camera & Files**: Needed to capture or pick receipt photos for scanning. Your photos remain on your device.',
      category: 'Scanning & Voice',
      icon: Icons.lock_outline_rounded,
    ),

    // Notifications
    _FaqItem(
      question: 'Why are daily reminders or alerts not firing?',
      answer:
          'Android devices often kill background services to save battery, blocking scheduled notifications. To fix this:\n\n'
          '1. Go to **Settings > Notifications & Battery**.\n'
          '2. Tap **Allow background notifications** (this disables battery optimization for the app).\n'
          '3. On devices from Xiaomi, Oppo, Vivo, or OnePlus, ensure you enable **Autostart** in system settings.',
      category: 'Notifications',
      icon: Icons.notification_important_rounded,
    ),
    _FaqItem(
      question: 'What notifications can I configure?',
      answer:
          '• **Daily Reminders**: Sends a prompt at 12:00 PM and 8:00 PM to remind you to log your spending.\n'
          '• **Budget Alerts**: Warns you when category spending reaches 80% and 100% of your monthly budget.\n'
          '• **Daily Insights**: Sends a personalized financial summary and saving tip at 6:40 PM based on your spending history.',
      category: 'Notifications',
      icon: Icons.notifications_active_rounded,
    ),

    // Data & Backup
    _FaqItem(
      question: 'Where is my data stored?',
      answer:
          'Smart Wallet is an **offline-first** app. All your account details, transactions, budgets, goals, and scanned receipt images are stored locally on your device in a secure SQLite database. We do not host your financial data on external servers.',
      category: 'Data & Backup',
      icon: Icons.storage_rounded,
    ),
    _FaqItem(
      question: 'How do I backup and restore my complete profile?',
      answer:
          '1. Go to **Settings > CSV Data Portability**.\n'
          '2. Tap **Create Backup** under the Backup & Restore section.\n'
          '3. This packages your database and all scanned receipt images into a single `.zip` file. Save it to your Google Drive or local storage.\n'
          '4. To restore on a new device, tap **Restore Backup** and select that `.zip` file.',
      category: 'Data & Backup',
      icon: Icons.backup_rounded,
    ),
    _FaqItem(
      question: 'How do I export my data to Excel/Sheets?',
      answer:
          'Go to **Settings > CSV Data Portability** and tap **Export Transactions** or **Export Accounts**. The app generates clean, standardized `.csv` files that you can share and open in Microsoft Excel, Google Sheets, or any table viewer.',
      category: 'Data & Backup',
      icon: Icons.table_chart_rounded,
    ),

    // Accounts & Setup
    _FaqItem(
      question: 'How do I manage different payment wallets or cards?',
      answer:
          'Smart Wallet supports tracking balances across multiple accounts. Go to **Settings > Accounts & Wallets** to create accounts for Cash, Bank, Credit Cards, or UPI.\n\n'
          'When adding a transaction, choose the relevant account. You can also log transfers (e.g., ATM withdrawals) to move money between accounts.',
      category: 'Accounts & Setup',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _FaqItem(
      question: 'What are Recurring Transactions?',
      answer:
          'You can set up templates for automatic logs (like rent, Netflix subscriptions, or monthly salary) in **Settings > Recurring Transactions**.\n\n'
          'Every time you open the app, it checks if any recurring transactions are due, auto-logs them, and displays a confirmation message.',
      category: 'Accounts & Setup',
      icon: Icons.repeat_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _replayOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OnboardingView(onComplete: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'stibinaugustine3047@gmail.com',
      queryParameters: {'subject': 'Smart Wallet Help & Support'},
    );
    await launchUrl(uri);
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
      'https://stibinottathai.github.io/smart-wallet-privacy-policy/',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Filter items based on category and search query
    final filteredItems = _faqItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search Bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search questions or keywords...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // ── Category Chips ─────────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.card,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── FAQ List ───────────────────────────────────────────────────────
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: filteredItems.length + 1, // +1 for the footer
                    itemBuilder: (context, index) {
                      if (index == filteredItems.length) {
                        return _buildFooter();
                      }
                      final item = filteredItems[index];
                      return _FaqCard(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_center_rounded,
                size: 40,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any FAQ answering "$_searchQuery". Try selecting a different category or search term.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'STILL NEED HELP?',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have custom feedback or issues not listed here? Get in touch or review our guides directly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _SupportActionRow(
                  icon: Icons.feedback_rounded,
                  label: 'Send Email Feedback',
                  onTap: _sendFeedback,
                ),
                const Divider(height: 20),
                _SupportActionRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Replay App Tour',
                  onTap: _replayOnboarding,
                ),
                const Divider(height: 20),
                _SupportActionRow(
                  icon: Icons.policy_rounded,
                  label: 'Read Privacy Policy',
                  onTap: _openPrivacyPolicy,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  final String category;
  final IconData icon;

  _FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
  });
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;

  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isExpanded
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.item.icon,
              size: 20,
              color: _isExpanded ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          title: Text(
            widget.item.question,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: _isExpanded ? AppColors.primary : AppColors.text,
            ),
          ),
          trailing: AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: _isExpanded ? 0.5 : 0.0,
            child: Icon(
              Icons.expand_more_rounded,
              color: _isExpanded ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 16),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.answer,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text,
                      height: 1.5,
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

class _SupportActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SupportActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/proactive_insight.dart';
import '../models/chat_message.dart';

class InsightsView extends ConsumerStatefulWidget {
  const InsightsView({super.key});

  @override
  ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_welcomeMessage());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _refreshInsights() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(refreshInsightsProvider.future);
    } catch (_) {
      // Silently handle — no error shown for background refresh
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final userMsg = ChatMessage(text: query, isUser: true, timestamp: DateTime.now());
    setState(() { _messages.add(userMsg); _isTyping = true; });
    _inputCtrl.clear();
    _scrollDown();

    final incomes = ref.read(allIncomesProvider).value ?? [];
    final expenses = ref.read(allExpensesProvider).value ?? [];
    final categories = ref.read(allCategoriesProvider).value ?? [];
    final apiKey = ref.read(openRouterApiKeyProvider);
    final currencyCode = ref.read(currencyCodeProvider);
    final currencySym = currencySymbol(currencyCode);

    if (apiKey.isEmpty) {
      setState(() { _isTyping = false; });
      _addMsg("⚠️ **No API Key**\n\nConfigure one under **Settings** to enable AI Chat.", isError: true);
      return;
    }

    final chatHistory = _messages
        .take(_messages.length - 1)
        .where((m) => m.shouldIncludeInHistory)
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    try {
      final service = ref.read(insightsServiceProvider);
      final buf = StringBuffer();
      final ts = DateTime.now();
      bool first = true;

      await for (final chunk in service.streamAssistant(
        expenses: expenses, incomes: incomes, categories: categories,
        chatHistory: chatHistory, userQuery: query, apiKey: apiKey,
        currencySymbol: currencySym,
      )) {
        if (!mounted) return;
        buf.write(chunk);
        setState(() {
          if (first) {
            _isTyping = false;
            _messages.add(ChatMessage(text: buf.toString(), isUser: false, timestamp: ts));
            first = false;
          } else {
            _messages[_messages.length - 1] = ChatMessage(text: buf.toString(), isUser: false, timestamp: ts);
          }
        });
        _scrollDown();
      }

      if (mounted && buf.isEmpty) {
        setState(() => _isTyping = false);
        _addMsg("I couldn't formulate a response. Please try again.");
      }
    } catch (e) {
      if (mounted) { setState(() => _isTyping = false); _showError(e.toString()); }
    }
  }

  void _addMsg(String text, {bool isError = false}) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false, timestamp: DateTime.now(), isError: isError));
    });
    _scrollDown();
  }

  void _showError(String err) {
    final is401 = err.contains('401') || err.contains('Unauthorized');
    final is429 = err.contains('429');
    final msg = is401
        ? "⚠️ **Unauthorized (401)**\n\nYour API key is invalid or out of credits. Update it in **Settings**."
        : is429
            ? "⚠️ **Rate Limited (429)**\n\nToo many requests. Please wait a moment."
            : "⚠️ **Error**\n\nFailed to contact assistant.\n\n_Details: ${err}_";
    _addMsg(msg, isError: true);
  }

  ChatMessage _welcomeMessage() {
    return ChatMessage(
      text: "✨ Welcome! I'm your **AI Financial Assistant**\n\n"
          "Here's what I can help you with:\n\n"
          "📊 **Analyze** — Understand your spending by category, merchant, or time period\n"
          "💡 **Optimize** — Get smart saving ideas tailored to your habits\n"
          "📈 **Compare** — See how this month stacks up against previous ones\n"
          "🔍 **Explore** — Ask anything about your finances\n\n"
          "_**What would you like to explore today?**_",
      isUser: false,
      timestamp: DateTime.now(),
      isSystemGenerated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'AI Assistant',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        actions: [
          // Scan for proactive insights
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: _isRefreshing
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.tips_and_updates_rounded, size: 18),
            label: Text(
              _isRefreshing ? 'Scanning...' : 'Scan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: _isRefreshing ? null : _refreshInsights,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Clear Chat',
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add(_welcomeMessage());
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Smart Alerts Strip ───────────────────────────────────────────
          _SmartAlertsStrip(),
          // ── Chat ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
            ),
          ),
          if (_isTyping) _TypingIndicator(),
          if (!_isTyping) _QuickChips(onTap: _sendMessage),
          _InputBar(controller: _inputCtrl, onSend: _sendMessage),
        ],
      ),
    );
  }
}

// ─── Smart Alerts Strip ────────────────────────────────────────────────────

class _SmartAlertsStrip extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SmartAlertsStrip> createState() => _SmartAlertStripState();
}

class _SmartAlertStripState extends ConsumerState<_SmartAlertsStrip> {
  bool _expanded = true;

  Color _toneColor(InsightTone tone) {
    switch (tone) {
      case InsightTone.positive:
        return AppColors.primary;
      case InsightTone.caution:
        return AppColors.secondary;
      case InsightTone.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(activeInsightsProvider);
    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'All clear — no active alerts',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.notifications_active_rounded,
                              size: 13, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${insights.length}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Alert chips (collapsible)
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: insights.take(5).map((insight) {
                        final color = _toneColor(insight.tone);
                        return GestureDetector(
                          onTap: () {
                            final repo = ref.read(proactiveInsightRepositoryProvider);
                            repo.dismissInsight(insight.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.55,
                                  ),
                                  child: Text(
                                    insight.message,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppColors.text,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.close_rounded, size: 13, color: color.withValues(alpha: 0.7)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.text),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                    listBullet: const TextStyle(color: AppColors.primary, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('h:mm a').format(message.timestamp),
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(3, (i) => _dot(i)),
              const SizedBox(width: 10),
              Text(
                'Thinking...',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int i) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: Duration(milliseconds: 600 + i * 200),
        builder: (_, v, __) => Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: v),
            shape: BoxShape.circle,
          ),
        ),
        onEnd: () {},
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _QuickChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chips = ['Save money ideas', 'Analyze my food spend', 'Compare this month vs last', 'List recurring entries'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            backgroundColor: AppColors.card,
            side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            onPressed: () => onTap(c),
          ),
        )).toList(),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                onPressed: () => onSend(controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

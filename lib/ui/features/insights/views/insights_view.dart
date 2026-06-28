import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:smart_wallet/data/services/insights_service.dart';
import 'package:smart_wallet/domain/models/proactive_insight.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/features/dashboard/widgets/animated_section.dart';
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

  // ── Voice input (on-device speech-to-text) ────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_welcomeMessage());
  }

  @override
  void dispose() {
    _speech.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Toggles voice dictation. Transcribed speech is written into the input
  /// field (not auto-sent) so the user can review it before sending — important
  /// since a misheard command would otherwise log a wrong transaction.
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    }

    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone unavailable. Enable mic permission to use voice input.'),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _inputCtrl.text = result.recognizedWords;
          _inputCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputCtrl.text.length),
          );
          if (result.finalResult) _isListening = false;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
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

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    final userMsg = ChatMessage(text: query, isUser: true, timestamp: DateTime.now());
    setState(() { _messages.add(userMsg); _isTyping = true; });
    _inputCtrl.clear();
    _scrollDown();

    final incomes = ref.read(allIncomesProvider).value ?? [];
    final expenses = ref.read(allExpensesProvider).value ?? [];
    final categories = ref.read(allCategoriesProvider).value ?? [];
    final bills = ref.read(allBillsProvider).value ?? [];
    final goals = ref.read(allSavingsGoalsProvider).value ?? [];
    final apiKey = ref.read(aiApiKeyProvider);
    final aiModel = ref.read(aiModelProvider);
    final aiProvider = ref.read(aiProviderProvider);
    final currencyCode = ref.read(currencyCodeProvider);
    final currencySym = currencySymbol(currencyCode);

    if (apiKey.isEmpty) {
      setState(() { _isTyping = false; });
      _addMsg("⚠️ **No API Key**\n\nConfigure one under **Settings** to enable AI Chat.", isError: true);
      return;
    }

    // ── Actionable commands (log a new expense/income) ──────────────────────
    // If the message looks like "add 40 transport today", actually persist the
    // transaction instead of letting the model hallucinate that it did.
    if (_looksLikeActionRequest(query)) {
      AssistantAction action = AssistantAction.none();
      try {
        final service = ref.read(insightsServiceProvider);
        action = await service.parseAction(
          userQuery: query,
          categories: categories,
          apiKey: apiKey,
          aiModel: aiModel,
          aiProvider: aiProvider,
          currencySymbol: currencySym,
        );
      } catch (_) {
        // Network/parse failure — fall back to local detection below so an
        // obvious command still works (saving is local-only, so it's fine
        // offline). A genuine question will produce no action and fall through.
      }
      if (!mounted) return;
      if (!action.isAction) {
        // The model didn't classify it as a transaction. For a clear command
        // like "salary credited", recognise it locally so the card still opens
        // instead of giving a generic balance answer.
        final local = _localFallbackAction(query);
        if (local != null) action = local;
      }
      if (action.isAction) {
        _presentActionCard(action, categories, currencySym);
        return;
      }
      // Not actually an action — fall through to a normal chat answer.
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
        bills: bills, goals: goals,
        chatHistory: chatHistory, userQuery: query, apiKey: apiKey,
        aiModel: aiModel,
        aiProvider: aiProvider,
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

  /// Cheap local pre-filter so normal questions skip the extra intent-parse
  /// round-trip. We attempt action parsing when the message contains an action
  /// verb (add/spent/paid/received/salary/…) and either a number, or — for a
  /// clear logging phrase that isn't a question — no number at all, in which
  /// case the confirmation card asks for the amount (e.g. "salary credited").
  bool _looksLikeActionRequest(String query) {
    final q = query.toLowerCase();
    const verbs = [
      'add', 'log', 'record', 'spent', 'spend', 'paid', 'pay', 'bought',
      'buy', 'purchase', 'received', 'receive', 'got', 'earned', 'earn',
      'income', 'salary', 'deposit', 'expense', 'credited', 'credit',
    ];
    final hasVerb = verbs.any((v) => RegExp('\\b$v').hasMatch(q));
    if (!hasVerb) return false;
    if (RegExp(r'\d').hasMatch(q)) return true;
    // No amount given: only treat as an action if it reads like a command,
    // not a question/analysis request (those go to the chat assistant).
    return !_looksLikeQuestion(q);
  }

  /// True when the message reads like a question or analysis request rather than
  /// a command to log a transaction.
  bool _looksLikeQuestion(String q) {
    if (q.contains('?')) return true;
    const starters = [
      'how', 'what', 'when', 'where', 'why', 'which', 'who', 'can you',
      'show', 'analyze', 'analyse', 'compare', 'list', 'tell', 'give',
    ];
    final trimmed = q.trimLeft();
    return starters.any((w) => trimmed.startsWith(w));
  }

  /// Local, no-API fallback that recognises an obvious "log a transaction"
  /// command when the model's intent parser returns nothing (or is unreachable).
  /// Guarantees the confirmation card appears for clear phrases like
  /// "salary credited" even on weaker models. Returns null when the message
  /// doesn't look like a command.
  AssistantAction? _localFallbackAction(String query) {
    final q = query.toLowerCase();

    const incomeWords = [
      'salary', 'credited', 'credit', 'received', 'receive', 'income',
      'earned', 'earn', 'deposit', 'bonus', 'refund', 'interest', 'dividend',
      'allowance', 'pension', 'stipend', 'cashback', 'freelance', 'payout', 'wage',
    ];
    const expenseWords = [
      'spent', 'spend', 'paid', 'pay', 'bought', 'buy', 'purchase',
      'expense', 'bill', 'add', 'log', 'record',
    ];

    final isIncome = incomeWords.any((w) => RegExp('\\b$w').hasMatch(q));
    final isExpense = !isIncome && expenseWords.any((w) => RegExp('\\b$w').hasMatch(q));
    if (!isIncome && !isExpense) return null;

    // First number in the message becomes the amount (null when none given, in
    // which case the card asks for it).
    double? amount;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(q);
    if (match != null) amount = double.tryParse(match.group(0)!);

    if (isIncome) {
      const sources = {
        'salary': 'Salary', 'freelance': 'Freelance', 'bonus': 'Bonus',
        'refund': 'Refund', 'interest': 'Interest', 'dividend': 'Dividend',
        'gift': 'Gift', 'rent': 'Rent', 'pension': 'Pension',
        'cashback': 'Cashback', 'allowance': 'Allowance', 'wage': 'Wages',
        'stipend': 'Stipend', 'payout': 'Payout',
      };
      String? source;
      for (final e in sources.entries) {
        if (RegExp('\\b${e.key}').hasMatch(q)) {
          source = e.value;
          break;
        }
      }
      return AssistantAction(
        intent: 'add_income',
        amount: amount,
        incomeSource: source ?? 'Other',
        date: DateTime.now(),
      );
    }

    // Expense: leave category null so the card's picker resolves it; derive a
    // short note from the remaining words.
    return AssistantAction(
      intent: 'add_expense',
      amount: amount,
      note: _deriveNote(query),
      date: DateTime.now(),
    );
  }

  /// Strips verbs, fillers and numbers to leave a short note/merchant for an
  /// expense, e.g. "spent on lunch today" -> "lunch".
  String? _deriveNote(String query) {
    const stop = {
      'add', 'log', 'record', 'spent', 'spend', 'paid', 'pay', 'bought',
      'buy', 'purchase', 'for', 'on', 'today', 'yesterday', 'a', 'an', 'the',
      'of', 'rs', 'inr', 'usd', 'i', 'my', 'me', 'to', 'in', 'expense', 'bill',
    };
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) {
      final t = w.replaceAll(RegExp(r'[^a-z]'), '');
      return t.isNotEmpty && !stop.contains(t) && !RegExp(r'\d').hasMatch(w);
    }).toList();
    if (words.isEmpty) return null;
    return words.join(' ');
  }

  /// Resolves a sensible fallback category when the model couldn't match one.
  String _fallbackCategoryId(List<domain.Category> categories) {
    for (final keyword in ['other', 'misc', 'general', 'uncategor']) {
      for (final c in categories) {
        if (c.name.toLowerCase().contains(keyword)) return c.id;
      }
    }
    return categories.first.id;
  }

  String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return DateFormat('d MMM').format(d);
  }

  /// Instead of silently saving (which always defaulted to the Cash account),
  /// surface an interactive confirmation card so the user can pick which account
  /// the money comes from / goes into — and the category for expenses — before
  /// anything is committed. This is the assistant "asking" with selectable
  /// options. The actual write happens in [_persistAction] once confirmed.
  void _presentActionCard(
    AssistantAction action,
    List<domain.Category> categories,
    String currencySym,
  ) {
    setState(() => _isTyping = false);

    // A missing amount is no longer a dead end — the card shows an input field
    // so the user can type it inline instead of re-phrasing the whole command.
    if (action.isExpense && categories.isEmpty) {
      _addMsg("⚠️ You don't have any categories yet. Add one first, then I can log expenses for you.");
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        text: action.isIncome ? 'Confirm income' : 'Confirm expense',
        isUser: false,
        timestamp: DateTime.now(),
        pendingAction: action,
      ));
    });
    _scrollDown();
  }

  /// Commits a confirmed action — with the account/category the user picked in
  /// the card — and posts a confirmation bubble reflecting what was actually
  /// saved. The watched DB streams then surface the new entry on the dashboard
  /// and transactions list automatically. Returns true on success.
  Future<bool> _persistAction(AssistantAction action, String currencySym) async {
    final amount = action.amount;
    if (amount == null || amount <= 0) return false;
    final date = action.date ?? DateTime.now();

    try {
      if (action.isExpense) {
        final categories = ref.read(allCategoriesProvider).value ?? [];
        final categoryId = action.categoryId ?? _fallbackCategoryId(categories);
        final category = categories.firstWhere((c) => c.id == categoryId,
            orElse: () => categories.first);

        final expense = domain.Expense(
          id: const Uuid().v4(),
          amount: amount,
          categoryId: categoryId,
          date: date,
          note: action.note,
          // Chat-typed entries have no receipt, so they're recorded as manual
          // (the dedicated "Receipt Scans" analytics stays receipt-only).
          source: domain.ExpenseSource.manual,
          accountId: action.accountId,
        );
        await ref.read(expenseRepositoryProvider).addExpense(expense);

        final noteStr = (action.note != null && action.note!.isNotEmpty)
            ? ' · ${action.note}'
            : '';
        _addMsg(
          "✅ **Expense added**\n\n"
          "$currencySym${amount.toStringAsFixed(2)} · **${category.name}**$noteStr\n"
          "Paid from **${_accountName(action.accountId)}** · ${_friendlyDate(date)}",
          isSystemGenerated: true,
        );
      } else {
        final source = (action.incomeSource?.isNotEmpty ?? false)
            ? action.incomeSource!
            : (action.note?.isNotEmpty ?? false ? action.note! : 'Other');

        final income = domain.Income(
          id: const Uuid().v4(),
          amount: amount,
          source: source,
          date: date,
          isRecurring: false,
          frequency: domain.IncomeFrequency.oneOff,
          accountId: action.accountId,
        );
        await ref.read(incomeRepositoryProvider).addIncome(income);

        _addMsg(
          "✅ **Income added**\n\n"
          "$currencySym${amount.toStringAsFixed(2)} · **$source**\n"
          "Added to **${_accountName(action.accountId)}** · ${_friendlyDate(date)}",
          isSystemGenerated: true,
        );
      }
      return true;
    } catch (e) {
      _addMsg("⚠️ Sorry, I couldn't save that. Please try again or add it manually.", isError: true);
      return false;
    }
  }

  /// Display name for the account a transaction was attributed to. A null id
  /// falls back to the default (Cash) account, matching balance attribution.
  String _accountName(String? accountId) {
    final accounts = ref.read(allAccountsProvider).value ?? [];
    final id = accountId ?? defaultAccountId;
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return 'Cash';
  }

  void _addMsg(String text, {bool isError = false, bool isSystemGenerated = false}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        isError: isError,
        isSystemGenerated: isSystemGenerated,
      ));
    });
    _scrollDown();
  }

  void _showError(String err) {
    final lower = err.toLowerCase();
    final isOffline = lower.contains('no internet') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection') ||
        lower.contains('handshakeexception') ||
        lower.contains('timed out');
    final is401 = err.contains('401') || err.contains('Unauthorized');
    final is429 = err.contains('429');
    final msg = isOffline
        ? "📡 **No Internet Connection**\n\nThe AI assistant needs an active connection. "
            "Please check your Wi-Fi or mobile data and try again."
        : is401
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
          "➕ **Add expenses** — Say _\"add 40 transport today\"_ and I'll ask which account to use\n"
          "💰 **Add income** — Say _\"salary credited\"_ and I'll ask how much, then log it to the account you pick\n"
          "📊 **Analyze** — Understand your spending by category, merchant, or time period\n"
          "💡 **Optimize** — Get smart saving ideas tailored to your habits\n"
          "📈 **Compare** — See how this month stacks up against previous ones\n\n"
          "_**What would you like to do today?**_",
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
          AnimatedSection(index: 0, tabIndex: 2, child: _SmartAlertsStrip()),
          // ── Chat ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final Widget child;
                if (m.pendingAction != null) {
                  final sym = currencySymbol(ref.read(currencyCodeProvider));
                  child = _ActionConfirmCard(
                    key: ValueKey('action_${m.timestamp.microsecondsSinceEpoch}'),
                    action: m.pendingAction!,
                    currencySym: sym,
                    onConfirm: (finalAction) async {
                      final ok = await _persistAction(finalAction, sym);
                      // Once saved, drop the interactive card (the confirmation
                      // bubble already records the result). This stops it from
                      // re-opening or reverting to a blank form when the list
                      // rebuilds / it scrolls back into view.
                      if (ok && mounted) {
                        setState(() => _messages.remove(m));
                      }
                      return ok;
                    },
                    onCancel: () {
                      if (mounted) setState(() => _messages.remove(m));
                      _addMsg(
                        "No problem — I didn't save anything. Just tell me again when you're ready.",
                        isSystemGenerated: true,
                      );
                    },
                  );
                } else {
                  child = _ChatBubble(message: m);
                }
                return AnimatedSection(index: 1 + i, tabIndex: 2, child: child);
              },
            ),
          ),
          if (_isTyping) _TypingIndicator(),
          if (!_isTyping) _QuickChips(onTap: _sendMessage),
          _InputBar(
            controller: _inputCtrl,
            onSend: _sendMessage,
            isListening: _isListening,
            onMic: _toggleListening,
          ),
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

/// Interactive confirmation card the assistant shows before saving a parsed
/// expense/income. Lets the user pick the account (so money no longer always
/// comes out of Cash) and, for expenses, adjust the category — then commits.
enum _CardStatus { choosing, saving, done, cancelled }

class _ActionConfirmCard extends ConsumerStatefulWidget {
  final AssistantAction action;
  final String currencySym;
  final Future<bool> Function(AssistantAction) onConfirm;
  final VoidCallback onCancel;

  const _ActionConfirmCard({
    super.key,
    required this.action,
    required this.currencySym,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  ConsumerState<_ActionConfirmCard> createState() => _ActionConfirmCardState();
}

class _ActionConfirmCardState extends ConsumerState<_ActionConfirmCard>
    with AutomaticKeepAliveClientMixin {
  _CardStatus _status = _CardStatus.choosing;
  String? _accountId;
  String? _categoryId;

  /// The amount to save. Seeded from the parsed action; when the parser couldn't
  /// find one, the card shows an input field that drives this instead.
  double? _amount;
  late final TextEditingController _amountCtrl;

  bool get _isIncome => widget.action.isIncome;

  // Keep the card's selections/state alive even when it scrolls off-screen, so
  // an in-progress (or just-saved) card never reverts to a blank form.
  @override
  bool get wantKeepAlive => true;

  /// True when the parser didn't extract an amount, so we must ask for it.
  bool get _needsAmountInput =>
      widget.action.amount == null || widget.action.amount! <= 0;

  /// Context-aware prompt for the amount field, e.g. "How much salary credited?"
  /// for an income or "How much on lunch?" for an expense.
  String get _amountLabel {
    if (_isIncome) {
      final src = (widget.action.incomeSource ?? widget.action.note ?? '').trim();
      return src.isEmpty
          ? 'How much was credited?'
          : 'How much ${src.toLowerCase()} credited?';
    }
    final note = (widget.action.note ?? '').trim();
    return note.isEmpty ? 'How much did you spend?' : 'How much on ${note.toLowerCase()}?';
  }

  @override
  void initState() {
    super.initState();
    _categoryId = widget.action.categoryId;
    final parsed = widget.action.amount;
    _amount = (parsed != null && parsed > 0) ? parsed : null;
    _amountCtrl = TextEditingController();
    _amountCtrl.addListener(() {
      final v = double.tryParse(_amountCtrl.text.trim());
      setState(() => _amount = (v != null && v > 0) ? v : null);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_amount == null) return;
    setState(() => _status = _CardStatus.saving);
    final finalAction = widget.action.copyWith(
      amount: _amount,
      accountId: _accountId,
      categoryId: _isIncome ? null : _categoryId,
    );
    final ok = await widget.onConfirm(finalAction);
    if (!mounted) return;
    setState(() => _status = ok ? _CardStatus.done : _CardStatus.choosing);
  }

  void _cancel() {
    setState(() => _status = _CardStatus.cancelled);
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final accounts = (ref.watch(allAccountsProvider).value ?? [])
        .where((a) => !a.archived)
        .toList();
    final categories = ref.watch(allCategoriesProvider).value ?? [];

    // Lazily pick a sensible default account (prefer Cash) once accounts load.
    if (_accountId == null && accounts.isNotEmpty) {
      final preferred = accounts.firstWhere(
        (a) => a.id == defaultAccountId || a.type == domain.AccountType.cash,
        orElse: () => accounts.first,
      );
      _accountId = preferred.id;
    }
    if (_categoryId == null && !_isIncome && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }

    if (_status == _CardStatus.done || _status == _CardStatus.cancelled) {
      return _resolvedTile();
    }

    final action = widget.action;
    final color = _isIncome ? AppColors.primary : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: type + amount ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                      size: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isIncome ? 'Add income' : 'Add expense',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  // Only echo the amount in the header when we already have one;
                  // otherwise it's collected via the input field below.
                  if (!_needsAmountInput)
                    Text(
                      '${widget.currencySym}${_amount!.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                ],
              ),
              if (action.note != null && action.note!.isNotEmpty ||
                  (_isIncome && (action.incomeSource?.isNotEmpty ?? false))) ...[
                const SizedBox(height: 4),
                Text(
                  _isIncome
                      ? (action.incomeSource ?? action.note ?? '')
                      : action.note!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 14),

              // ── Amount input (only when the parser couldn't find one) ──────
              if (_needsAmountInput) ...[
                _label(_amountLabel),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '${widget.currencySym} ',
                    prefixStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    hintText: '0.00',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (_amount != null) _confirm();
                  },
                ),
                const SizedBox(height: 14),
              ],

              // ── Category picker (expense only) ─────────────────────────────
              if (!_isIncome && categories.isNotEmpty) ...[
                _label('Category'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((c) {
                    return _selectChip(
                      label: c.name,
                      selected: _categoryId == c.id,
                      onTap: () => setState(() => _categoryId = c.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // ── Account picker ─────────────────────────────────────────────
              _label(_isIncome ? 'Add to which account?' : 'Pay from which account?'),
              const SizedBox(height: 6),
              if (accounts.isEmpty)
                const Text(
                  'No accounts found — it will use your default account.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: accounts.map((a) {
                    return _selectChip(
                      label: a.name,
                      selected: _accountId == a.id,
                      icon: getAccountIcon(a.type),
                      onTap: () => setState(() => _accountId = a.id),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // ── Actions ────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _status == _CardStatus.saving ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_status == _CardStatus.saving || _amount == null)
                          ? null
                          : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: _status == _CardStatus.saving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _status == _CardStatus.saving
                            ? 'Saving…'
                            : (_isIncome ? 'Add income' : 'Add expense'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resolvedTile() {
    final cancelled = _status == _CardStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cancelled ? Icons.close_rounded : Icons.check_circle_rounded,
                size: 14,
                color: cancelled ? AppColors.textSecondary : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                cancelled ? 'Cancelled' : 'Saved',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _selectChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.6),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
          ],
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
    final chips = ['Add 40 transport today', 'Salary credited', 'Save money ideas', 'Analyze my food spend'];
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
  final bool isListening;
  final VoidCallback onMic;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isListening,
    required this.onMic,
  });

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
                  hintText: isListening ? 'Listening… speak now' : 'Ask or say a command…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  // Mic button lives inside the field so it's always reachable.
                  suffixIcon: IconButton(
                    icon: Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: isListening ? AppColors.error : AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: isListening ? 'Stop listening' : 'Speak',
                    onPressed: onMic,
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

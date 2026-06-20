import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import '../models/chat_message.dart';

class InsightsView extends ConsumerStatefulWidget {
   const InsightsView({super.key});

   @override
   ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add default welcome message from assistant
    _messages.add(
      ChatMessage(
        text: "Hello! I am your **AI Financial Assistant**.\n\n"
            "Ask me anything about your current balances, category spending, or get ideas on how to save money! I evaluate your local logs privately and securely.",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    // 1. Load context data (incomes, expenses, categories)
    final incomes = ref.read(allIncomesProvider).value ?? [];
    final expenses = ref.read(allExpensesProvider).value ?? [];
    final categories = ref.read(allCategoriesProvider).value ?? [];
    final apiKey = ref.read(openRouterApiKeyProvider);

    if (apiKey.isEmpty) {
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: "⚠️ **Error**: No OpenRouter API Key is configured in the codebase. Please configure the key to enable AI Chat.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // 2. Format history context
    final chatHistory = _messages
        .take(_messages.length - 1) // exclude the latest user query
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    try {
      final service = ref.read(insightsServiceProvider);
      final aiResponse = await service.askAssistant(
        expenses: expenses,
        incomes: incomes,
        categories: categories,
        chatHistory: chatHistory,
        userQuery: query,
        apiKey: apiKey,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final is401 = errStr.contains('401');
        final errorMessage = is401
            ? "⚠️ **Error: Unauthorized (401)**\n\nYour OpenRouter API Key appears to be invalid, expired, or has run out of credits.\n\nPlease check or reset your key configuration under the **Settings** view."
            : "⚠️ **Error**: Failed to contact assistant. Please verify your internet connection.\n\n_Details: ${e}_";

        setState(() {
          _messages.add(
            ChatMessage(
              text: errorMessage,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text: "Hello! I am your **AI Financial Assistant**.\n\n"
                        "Ask me anything about your current balances, category spending, or get ideas on how to save money!",
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Divider below appbar
          const Divider(height: 1.0),
          
          // Conversation messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),

          // Loading typing indicator
          if (_isTyping) _buildTypingIndicator(),

          // Quick Suggestion Chips (only when not typing)
          if (!_isTyping) _buildQuickChips(),

          // Message Input Field
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isUser 
              ? AppColors.secondary.withValues(alpha: 0.12) 
              : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12.0),
            topRight: const Radius.circular(12.0),
            bottomLeft: Radius.circular(isUser ? 12.0 : 0.0),
            bottomRight: Radius.circular(isUser ? 0.0 : 12.0),
          ),
          border: Border.all(
            color: isUser 
                ? AppColors.secondary.withValues(alpha: 0.25) 
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.text),
                strong: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                listBullet: const TextStyle(color: AppColors.primary, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 6.0),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('jm').format(message.timestamp),
                style: const TextStyle(fontSize: 9.0, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
              bottomRight: Radius.circular(12.0),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              SizedBox(width: 12.0),
              Text(
                'Financial Assistant is thinking...',
                style: TextStyle(fontSize: 12.0, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final chips = [
      '💡 Save money ideas',
      '🍔 Analyze my food spend',
      '📈 Compare this month vs last',
      '🔄 List recurring entries',
    ];

    return Container(
      height: 42.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final text = chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              label: Text(
                text,
                style: const TextStyle(fontSize: 12.0, color: AppColors.text, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                // Strip the emoji prefix for the clean API query
                final cleanText = text.substring(2);
                _sendMessage(cleanText);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _inputController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Ask your financial assistant...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
                onFieldSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: () => _sendMessage(_inputController.text),
            ),
          ],
        ),
      ),
    );
  }
}

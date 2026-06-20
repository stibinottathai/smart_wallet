import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/models.dart' as domain;

class SpendingInsight {
  final String title;
  final String observation;
  final String suggestion;

  SpendingInsight({
    required this.title,
    required this.observation,
    required this.suggestion,
  });

  factory SpendingInsight.fromJson(Map<String, dynamic> json) {
    return SpendingInsight(
      title: json['title'] ?? '',
      observation: json['observation'] ?? '',
      suggestion: json['suggestion'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'observation': observation,
        'suggestion': suggestion,
      };
}

class InsightsService {
  static const _cacheKey = 'cached_insights';
  static const _cacheTimeKey = 'cached_insights_time';

  Future<List<SpendingInsight>?> getCachedInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => SpendingInsight.fromJson(item)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCachedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheTimeKey);
  }

  Future<List<SpendingInsight>> generateInsights({
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    required String apiKey,
    String currencySymbol = '\$',
  }) async {
    if (expenses.isEmpty) {
      return [
        SpendingInsight(
          title: 'Not enough data',
          observation: 'We couldn\'t find any expense records.',
          suggestion: 'Tap the + button to add your first expense and start tracking your spending.',
        )
      ];
    }

    final now = DateTime.now();
    final currentPeriodStart = now.subtract(const Duration(days: 30));
    final previousPeriodStart = now.subtract(const Duration(days: 60));

    // 1. Group expenses by category
    final Map<String, double> currentCategorySpend = {};
    final Map<String, double> previousCategorySpend = {};
    double totalCurrent = 0.0;
    double totalPrevious = 0.0;

    for (final exp in expenses) {
      if (exp.date.isAfter(currentPeriodStart) && exp.date.isBefore(now)) {
        currentCategorySpend[exp.categoryId] = (currentCategorySpend[exp.categoryId] ?? 0.0) + exp.amount;
        totalCurrent += exp.amount;
      } else if (exp.date.isAfter(previousPeriodStart) && exp.date.isBefore(currentPeriodStart)) {
        previousCategorySpend[exp.categoryId] = (previousCategorySpend[exp.categoryId] ?? 0.0) + exp.amount;
        totalPrevious += exp.amount;
      }
    }

    // Map Category IDs to Names
    final categoryMap = {for (var c in categories) c.id: c.name};

    // 2. Build local summary description
    final buffer = StringBuffer();
    buffer.writeln('Local transaction summary (last 60 days):');
    buffer.writeln('Total spend (last 30 days): $totalCurrent');
    buffer.writeln('Total spend (previous 30 days): $totalPrevious');
    buffer.writeln('Category breakdown (current month vs last month):');

    final allCatIds = {...currentCategorySpend.keys, ...previousCategorySpend.keys};
    for (final catId in allCatIds) {
      final name = categoryMap[catId] ?? 'Unknown';
      final current = currentCategorySpend[catId] ?? 0.0;
      final previous = previousCategorySpend[catId] ?? 0.0;
      final changePercent = previous > 0 ? ((current - previous) / previous) * 100 : (current > 0 ? 100.0 : 0.0);
      final sign = changePercent >= 0 ? '+' : '';
      buffer.writeln('- $name: Current spend $current, Previous spend $previous ($sign${changePercent.toStringAsFixed(1)}%)');
    }

    // 3. Request OpenRouter
    try {
      final prompt = 'Analyze the following aggregated local spending summary. '
          'Identify the 2-3 biggest drivers of spend or month-over-month growth, and provide direct, actionable advice on where to cut back. '
          'Observation cards must state facts plainly (e.g., "Dining is up 32% this month"). '
          'Suggestions must offer concrete, specific numbers/actions. '
          'Crucial: Always use $currencySymbol as the currency symbol for all monetary amounts in the response. Do not use \$ or USD unless that is the active currency.\n\n'
          '${buffer.toString()}\n\n'
          'Respond with ONLY a JSON array matching this schema:\n'
          '[\n'
          '  {\n'
          '    "title": "string (the category name or spending driver)",\n'
          '    "observation": "string (plain observation, e.g. Dining is up 32% this month)",\n'
          '    "suggestion": "string (one concrete action to cut back, e.g. Cook at home on weekends to save ~\$150")\n'
          '  }\n'
          ']';

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/stibinottathai/smart_wallet',
          'X-Title': 'Smart Wallet',
        },
        body: jsonEncode({
          'model': dotenv.env['OPENROUTER_MODEL'] ?? 'deepseek/deepseek-chat-v3-0324',
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'response_format': {
            'type': 'json_object',
          },
        }),
      );

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response.body, response.statusCode);
        throw Exception('OpenRouter responded with code ${response.statusCode}: $detail');
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Empty choices returned from OpenRouter');
      }

      final content = choices[0]['message']['content'] as String?;
      if (content == null) {
        throw Exception('Null content returned from OpenRouter');
      }

      final List<dynamic> decoded = jsonDecode(content.trim());
      final list = decoded.map((item) => SpendingInsight.fromJson(item)).toList();

      if (list.isNotEmpty) {
        // Cache the result
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
        await prefs.setString(_cacheTimeKey, now.toLocal().toString().substring(0, 16));
      }

      return list;
    } catch (e) {
      // Fallback in case of networking/API failures - return a local heuristic-based card
      final growthCats = allCatIds.map((id) {
        final current = currentCategorySpend[id] ?? 0.0;
        final previous = previousCategorySpend[id] ?? 0.0;
        final diff = current - previous;
        return MapEntry(id, diff);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topGrowthId = growthCats.isNotEmpty ? growthCats.first.key : null;
      final topGrowthName = topGrowthId != null ? categoryMap[topGrowthId] : 'Unknown';
      final topGrowthVal = topGrowthId != null ? currentCategorySpend[topGrowthId] ?? 0.0 : 0.0;

      return [
        SpendingInsight(
          title: 'Insights Offline',
          observation: topGrowthId != null
              ? '$topGrowthName is currently your leading spend area at $currencySymbol$topGrowthVal.'
              : 'Total spend for the past 30 days is $currencySymbol$totalCurrent.',
          suggestion: 'Ensure your OpenRouter API key is configured and check your network connection to generate advanced on-demand insights.',
        )
      ];
    }
  }

  /// Extracts a user-friendly error detail from a non-200 OpenRouter response.
  String _extractErrorDetail(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      final err = decoded['error'];
      if (err is Map) {
        final message = err['message'] ?? err['code'] ?? body;
        return message.toString();
      }
    } catch (_) {}
    return body.length > 200 ? 'HTTP $statusCode (see logs)' : body;
  }

  /// Builds a compact, aggregated financial summary instead of listing
  /// every individual transaction. This dramatically reduces prompt size.
  String _buildFinancialContext({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required String currencySymbol,
  }) {
    final categoryMap = {for (var c in categories) c.id: c.name};
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));

    // Filter to recent data only
    final recentExpenses = expenses.where((e) => e.date.isAfter(cutoff)).toList();
    final recentIncomes = incomes.where((e) => e.date.isAfter(cutoff)).toList();

    // Aggregate expenses by category
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};
    for (final e in recentExpenses) {
      final name = categoryMap[e.categoryId] ?? 'Uncategorized';
      categoryTotals[name] = (categoryTotals[name] ?? 0.0) + e.amount;
      categoryCounts[name] = (categoryCounts[name] ?? 0) + 1;
    }

    // Aggregate incomes by source
    final Map<String, double> sourceTotals = {};
    for (final i in recentIncomes) {
      sourceTotals[i.source] = (sourceTotals[i.source] ?? 0.0) + i.amount;
    }

    double totalIncome = recentIncomes.fold(0.0, (sum, item) => sum + item.amount);
    double totalExpense = recentExpenses.fold(0.0, (sum, item) => sum + item.amount);

    final buf = StringBuffer();
    buf.writeln('Financial Summary (last 90 days):');
    buf.writeln('Total Income: $currencySymbol${totalIncome.toStringAsFixed(2)}');
    buf.writeln('Total Expenses: $currencySymbol${totalExpense.toStringAsFixed(2)}');
    buf.writeln('Net Balance: $currencySymbol${(totalIncome - totalExpense).toStringAsFixed(2)}');
    buf.writeln();
    buf.writeln('Spending by Category:');
    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCats) {
      buf.writeln('- ${entry.key}: $currencySymbol${entry.value.toStringAsFixed(2)} (${categoryCounts[entry.key]} transactions)');
    }
    buf.writeln();
    buf.writeln('Income by Source:');
    for (final entry in sourceTotals.entries) {
      buf.writeln('- ${entry.key}: $currencySymbol${entry.value.toStringAsFixed(2)}');
    }

    // Include only the 10 most recent individual transactions for context
    final recentTxns = recentExpenses.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (recentTxns.isNotEmpty) {
      buf.writeln();
      buf.writeln('Recent Transactions (last ${recentTxns.length > 10 ? 10 : recentTxns.length}):');
      for (final e in recentTxns.take(10)) {
        final catName = categoryMap[e.categoryId] ?? 'Uncategorized';
        final noteStr = e.note != null ? ' - ${e.note}' : '';
        buf.writeln('- ${e.date.toString().substring(0, 10)}: $currencySymbol${e.amount.toStringAsFixed(2)} ($catName$noteStr)');
      }
    }

    return buf.toString();
  }

  /// Streams the assistant response token-by-token via SSE.
  /// This provides a much faster perceived response time since the user
  /// sees text appearing immediately instead of waiting for the full reply.
  Stream<String> streamAssistant({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required List<Map<String, String>> chatHistory,
    required String userQuery,
    required String apiKey,
    String currencySymbol = '\$',
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API key is empty. Please configure a valid OpenRouter API key.');
    }

    final financialContext = _buildFinancialContext(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      currencySymbol: currencySymbol,
    );

    final systemPrompt = "You are a concise, friendly AI financial assistant for Smart Wallet.\n"
        "The user's configured currency is $currencySymbol. Always format monetary values using this currency symbol.\n"
        "Use the data below to answer questions. Be brief and practical.\n\n"
        "$financialContext\n\n"
        "Rules: Keep replies short (2-4 bullet points max). Use Markdown formatting.";

    // Build payload messages
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt}
    ];

    // Limit chat history to last 10 messages to keep payload small
    final recentHistory = chatHistory.length > 10
        ? chatHistory.sublist(chatHistory.length - 10)
        : chatHistory;

    for (final msg in recentHistory) {
      messages.add({
        'role': msg['role'] == 'model' ? 'assistant' : 'user',
        'content': msg['text']!,
      });
    }

    messages.add({'role': 'user', 'content': userQuery});

    // Retry logic for transient errors
    const maxRetries = 2;
    const retryableStatusCodes = {429, 500, 502, 503};

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final client = http.Client();
      try {
        final request = http.Request(
          'POST',
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        );
        request.headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/stibinottathai/smart_wallet',
          'X-Title': 'Smart Wallet',
        });
        request.body = jsonEncode({
          'model': dotenv.env['OPENROUTER_MODEL'] ?? 'deepseek/deepseek-chat-v3-0324',
          'messages': messages,
          'stream': true,
          'max_tokens': 512,
        });

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          if (retryableStatusCodes.contains(streamedResponse.statusCode) && attempt < maxRetries) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
          final detail = _extractErrorDetail(body, streamedResponse.statusCode);
          throw Exception('OpenRouter responded with code ${streamedResponse.statusCode}: $detail');
        }

        // Parse SSE stream
        String buffer = '';
        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          buffer += chunk;
          // SSE events are separated by double newlines
          while (buffer.contains('\n')) {
            final lineEnd = buffer.indexOf('\n');
            final line = buffer.substring(0, lineEnd).trim();
            buffer = buffer.substring(lineEnd + 1);

            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              if (data == '[DONE]') return;

              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                final choices = json['choices'] as List<dynamic>?;
                if (choices != null && choices.isNotEmpty) {
                  final delta = choices[0]['delta'] as Map<String, dynamic>?;
                  final content = delta?['content'] as String?;
                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
                }
              } catch (_) {
                // Skip malformed JSON chunks
              }
            }
          }
        }
        return; // Successfully streamed, exit retry loop
      } finally {
        client.close();
      }
    }
  }

  /// Non-streaming fallback — kept for backward compatibility with tests.
  Future<String> askAssistant({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required List<Map<String, String>> chatHistory,
    required String userQuery,
    required String apiKey,
    String currencySymbol = '\$',
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamAssistant(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      chatHistory: chatHistory,
      userQuery: userQuery,
      apiKey: apiKey,
      currencySymbol: currencySymbol,
    )) {
      buffer.write(chunk);
    }
    final result = buffer.toString();
    return result.isEmpty
        ? "I'm sorry, I couldn't formulate a response. Please try again."
        : result;
  }
}

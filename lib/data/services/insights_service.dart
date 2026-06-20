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
          'Observation cards must state facts plainly (e.g., "Dining is up 32% this month"). Suggestions must offer concrete, specific numbers/actions.\n\n'
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
        throw Exception('OpenRouter responded with code ${response.statusCode}');
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
              ? '$topGrowthName is currently your leading spend area at $topGrowthVal.'
              : 'Total spend for the past 30 days is $totalCurrent.',
          suggestion: 'Ensure your OpenRouter API key is configured and check your network connection to generate advanced on-demand insights.',
        )
      ];
    }
  }

  Future<String> askAssistant({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required List<Map<String, String>> chatHistory,
    required String userQuery,
    required String apiKey,
  }) async {
    try {
      final categoryMap = {for (var c in categories) c.id: c.name};

      // 1. Build a text-based ledger log context of the user's data
      final expenseSummary = expenses.isEmpty
          ? "No expense records."
          : expenses.map((e) {
              final catName = categoryMap[e.categoryId] ?? 'Uncategorized';
              final noteStr = e.note != null ? " (Note: ${e.note})" : "";
              return "- Date: ${e.date.toString().substring(0, 10)}, Amount: \$${e.amount.toStringAsFixed(2)}, Category: $catName$noteStr";
            }).join('\n');

      final incomeSummary = incomes.isEmpty
          ? "No income records."
          : incomes.map((e) {
              final recurringStr = e.isRecurring ? " (Recurring, Frequency: ${e.frequency.displayName})" : " (One-off)";
              return "- Date: ${e.date.toString().substring(0, 10)}, Amount: \$${e.amount.toStringAsFixed(2)}, Source: ${e.source}$recurringStr";
            }).join('\n');

      // Calculate totals
      double totalIncome = incomes.fold(0.0, (sum, item) => sum + item.amount);
      double totalExpense = expenses.fold(0.0, (sum, item) => sum + item.amount);
      double balance = totalIncome - totalExpense;

      // 2. Formulate the system instruction
      final systemPrompt = "You are a helpful, professional, and friendly AI financial assistant for Smart Wallet.\n"
          "The user's transaction data is stored locally offline, and privacy is fully respected. "
          "Use the following transaction summary context to answer the user's questions and provide custom money-saving suggestions.\n\n"
          "Financial Summary:\n"
          "- Total Income: \$${totalIncome.toStringAsFixed(2)}\n"
          "- Total Expenses: \$${totalExpense.toStringAsFixed(2)}\n"
          "- Net Balance: \$${balance.toStringAsFixed(2)}\n\n"
          "Incomes Log:\n"
          "$incomeSummary\n\n"
          "Expenses Log:\n"
          "$expenseSummary\n\n"
          "Guidelines:\n"
          "1. Give concise, friendly, and practical replies. Avoid long walls of text.\n"
          "2. Answer custom user questions using their transaction lists.\n"
          "3. Provide realistic ideas on how they can save money (e.g. identify high categories, recurring leaks, etc.).\n"
          "4. Output format should use standard Markdown (bold, lists, etc.) for visual formatting in the app.";

      // Build payload messages
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': systemPrompt,
        }
      ];

      for (final msg in chatHistory) {
        messages.add({
          'role': msg['role'] == 'model' ? 'assistant' : 'user',
          'content': msg['text']!,
        });
      }

      messages.add({
        'role': 'user',
        'content': userQuery,
      });

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
          'messages': messages,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenRouter responded with code ${response.statusCode}');
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Empty choices returned from OpenRouter');
      }

      final content = choices[0]['message']['content'] as String?;
      return content ?? "I'm sorry, I couldn't formulate a response. Please try again.";
    } catch (e) {
      return "Error contacting financial assistant: $e\n\nPlease check your network connection and try again.";
    }
  }
}

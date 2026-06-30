import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/models/proactive_insight.dart';
import '../repositories/proactive_insight_repository_impl.dart';
import 'subscription_detection_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fact schemas — mirrors the spec exactly
// ─────────────────────────────────────────────────────────────────────────────

/// Runs the local rule engine against current financial data and returns
/// a list of structured fact maps (one per triggered event).
List<Map<String, dynamic>> runRuleEngine({
  required List<domain.Expense> expenses,
  required List<domain.Income> incomes,
  required List<domain.Category> categories,
  required List<domain.Bill> bills,
  required List<domain.SavingsGoal> goals,
  List<domain.Investment> investments = const [],
}) {
  final facts = <Map<String, dynamic>>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final categoryMap = {for (final c in categories) c.id: c};

  // ── 1. budget_threshold ──────────────────────────────────────────────────
  // Category spend ≥ 80% of monthly budget limit
  final currentMonthStart = DateTime(now.year, now.month, 1);
  final Map<String, double> monthSpend = {};
  for (final e in expenses) {
    if (!e.date.isBefore(currentMonthStart)) {
      monthSpend[e.categoryId] = (monthSpend[e.categoryId] ?? 0) + e.amount;
    }
  }
  for (final cat in categories) {
    final limit = cat.budgetLimit;
    if (limit == null || limit <= 0) continue;
    final spent = monthSpend[cat.id] ?? 0.0;
    final percent = (spent / limit * 100).round();
    if (percent >= 80) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysLeft = daysInMonth - now.day;
      facts.add({
        'trigger_type': 'budget_threshold',
        'category': cat.name,
        'spent': spent.round(),
        'limit': limit.round(),
        'percent': percent,
        'days_left_in_month': daysLeft,
      });
    }
  }

  // ── 2. large_transaction ─────────────────────────────────────────────────
  // Single expense > 5× the 30-day category average — check last 3 days
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final threeDaysAgo = now.subtract(const Duration(days: 3));
  final Map<String, List<double>> cat30DayAmounts = {};
  for (final e in expenses) {
    if (e.date.isAfter(thirtyDaysAgo)) {
      cat30DayAmounts.putIfAbsent(e.categoryId, () => []).add(e.amount);
    }
  }
  for (final e in expenses) {
    if (!e.date.isAfter(threeDaysAgo)) continue;
    final amounts = cat30DayAmounts[e.categoryId] ?? [];
    if (amounts.length < 2) continue;
    // Remove current transaction to compute the average of "other" transactions
    final others = List<double>.from(amounts)..remove(e.amount);
    if (others.isEmpty) continue;
    final avg = others.reduce((a, b) => a + b) / others.length;
    if (avg <= 0) continue;
    final multiple = e.amount / avg;
    if (multiple >= 5) {
      final catName = categoryMap[e.categoryId]?.name ?? 'Unknown';
      facts.add({
        'trigger_type': 'large_transaction',
        'category': catName,
        'amount': e.amount.round(),
        'category_average': avg.round(),
        'multiple': double.parse(multiple.toStringAsFixed(1)),
      });
      break; // Only one large-transaction alert at a time
    }
  }

  // ── 3. recurring_detected ────────────────────────────────────────────────
  // Same amount + category appears ≥ 3 times within 35 days
  final thirtyFiveDaysAgo = now.subtract(const Duration(days: 35));
  final Map<String, List<domain.Expense>> groupedRecurring = {};
  for (final e in expenses) {
    if (!e.date.isAfter(thirtyFiveDaysAgo)) continue;
    final key = '${e.categoryId}::${e.amount.toStringAsFixed(0)}';
    groupedRecurring.putIfAbsent(key, () => []).add(e);
  }
  for (final entry in groupedRecurring.entries) {
    final group = entry.value;
    if (group.length < 3) continue;
    group.sort((a, b) => a.date.compareTo(b.date));
    final spans = <int>[];
    for (int i = 1; i < group.length; i++) {
      spans.add(group[i].date.difference(group[i - 1].date).inDays);
    }
    final avgInterval = spans.reduce((a, b) => a + b) ~/ spans.length;
    final merchantNote = group.last.note ?? categoryMap[group.last.categoryId]?.name ?? 'Unknown';
    facts.add({
      'trigger_type': 'recurring_detected',
      'merchant': merchantNote,
      'amount': group.last.amount.round(),
      'occurrences': group.length,
      'interval_days': avgInterval,
    });
    break; // One recurring alert at a time
  }

  // ── 4. goal_stalled ──────────────────────────────────────────────────────
  // No income-tagged contribution to a goal in 21+ days
  // (We approximate by checking if the goal's currentAmount hasn't grown –
  //  since we don't track per-goal contributions, we flag all goals where
  //  the updatedAt equivalent is missing. Instead we use a simple heuristic:
  //  if goal.currentAmount < goal.targetAmount and goal was created > 21 days ago)
  // A more precise implementation would require a contribution log table.
  // For now we detect stalled goals by checking if currentAmount == 0 and
  // goal was added (we don't store createdAt, so we check daysLeft heuristic).
  for (final goal in goals) {
    if (goal.currentAmount >= goal.targetAmount) continue;
    final daysToTarget = goal.targetDate.difference(today).inDays;
    if (daysToTarget < 0) continue; // Expired goal — skip
    // Heuristic: flag if goal progress is <20% and target is >30 days away
    // (no creation timestamp available, so we skip the 21-day check here)
    final progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0.0;
    if (progress < 0.05 && daysToTarget > 30) {
      facts.add({
        'trigger_type': 'goal_stalled',
        'goal_name': goal.name,
        'days_since_last_contribution': 21, // conservative estimate
        'current_amount': goal.currentAmount.round(),
        'target_amount': goal.targetAmount.round(),
      });
      break;
    }
  }

  // ── 5. bill_upcoming ─────────────────────────────────────────────────────
  // Unpaid bill due within 5 days
  for (final bill in bills) {
    if (bill.isPaid) continue;
    final daysUntilDue = bill.dueDate.difference(today).inDays;
    if (daysUntilDue >= 0 && daysUntilDue <= 5) {
      // Estimate balance after paying this bill
      final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
      final totalExpense = expenses.fold(0.0, (s, e) => s + e.amount);
      final currentBalance = totalIncome - totalExpense;
      final projectedAfter = (currentBalance - bill.amount).round();
      facts.add({
        'trigger_type': 'bill_upcoming',
        'bill_name': bill.name,
        'amount': bill.amount.round(),
        'due_in_days': daysUntilDue,
        'projected_balance_after': projectedAfter,
      });
      break; // One bill alert at a time
    }
  }

  // ── 6. spend_forecast ────────────────────────────────────────────────────
  // Projected month total > 110% of last month, based on daily pace
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);
  double lastMonthTotal = 0;
  final Map<String, double> currentDriverSpend = {};
  for (final e in expenses) {
    if (!e.date.isBefore(lastMonthStart) && !e.date.isAfter(lastMonthEnd)) {
      lastMonthTotal += e.amount;
    }
    if (!e.date.isBefore(currentMonthStart)) {
      currentDriverSpend[e.categoryId] =
          (currentDriverSpend[e.categoryId] ?? 0) + e.amount;
    }
  }
  if (lastMonthTotal > 0 && now.day > 3) {
    final daysElapsed = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentSpend = monthSpend.values.fold(0.0, (a, b) => a + b);
    final dailyRate = currentSpend / daysElapsed;
    final projected = (dailyRate * daysInMonth).round();
    if (projected > lastMonthTotal * 1.1) {
      final topDriverId = currentDriverSpend.entries.isEmpty
          ? null
          : (currentDriverSpend.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
      final driverName = topDriverId != null
          ? categoryMap[topDriverId]?.name ?? 'Unknown'
          : 'Unknown';
      facts.add({
        'trigger_type': 'spend_forecast',
        'projected_month_total': projected,
        'last_month_total': lastMonthTotal.round(),
        'driver_category': driverName,
      });
    }
  }

  // ── 7. savings_streak ────────────────────────────────────────────────────
  // 3+ consecutive days with zero expenses.
  // The window starts at TODAY so that any expense dated today immediately
  // resets the streak to 0 — preventing stale "no-spend" alerts.
  final expenseDays = expenses
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet();
  int streak = 0;
  DateTime checkDay = today; // ← include today in the look-back
  while (!expenseDays.contains(checkDay) && streak < 30) {
    streak++;
    checkDay = checkDay.subtract(const Duration(days: 1));
  }
  if (streak >= 3) {
    facts.add({
      'trigger_type': 'savings_streak',
      'metric': 'no_spend_days',
      'count': streak,
    });
  }

  // ── 8. subscriptions ─────────────────────────────────────────────────────
  // Auto-detected recurring merchants: surface the total monthly cost and the
  // single biggest price increase so the AI can narrate them as cards.
  final subs = SubscriptionDetectionService.detect(
    expenses: expenses,
    categories: categories,
    now: now,
  );
  final activeSubs = subs.where((s) => s.isActive).toList();
  if (activeSubs.length >= 2) {
    final monthlyTotal = activeSubs.fold<double>(0, (s, x) => s + x.monthlyCost);
    facts.add({
      'trigger_type': 'subscription_summary',
      'monthly_total': monthlyTotal.round(),
      'count': activeSubs.length,
      'largest_merchant': activeSubs.first.merchant, // sorted by monthly cost desc
      'largest_monthly': activeSubs.first.monthlyCost.round(),
    });
  }
  Subscription? topHike;
  for (final s in activeSubs) {
    if (!s.hasPriceHike) continue;
    if (topHike == null || s.priceHikePercent > topHike.priceHikePercent) topHike = s;
  }
  if (topHike != null) {
    facts.add({
      'trigger_type': 'subscription_price_hike',
      'category': topHike.merchant,
      'merchant': topHike.merchant,
      'old_amount': topHike.previousAmount!.round(),
      'new_amount': topHike.amount.round(),
      'percent': topHike.priceHikePercent.round(),
    });
  }

  // ── 9. investment_portfolio ──────────────────────────────────────────────
  // Surfaces three kinds of portfolio alerts so the AI can narrate them as
  // calm, factual cards without making predictions:
  //   * portfolio_drawdown — overall unrealised loss ≥ 5%
  //   * portfolio_rally    — overall unrealised gain ≥ 15%
  //   * portfolio_concentration — one holding makes up ≥ 60% of total value
  // Fires only when at least two holdings exist (a single bet doesn't need a
  // concentration warning, and "your one investment is down" is noise).
  final activeInvestments = investments.where((i) => !i.isClosed).toList();
  if (activeInvestments.length >= 2) {
    final totalInvested =
        activeInvestments.fold<double>(0, (s, i) => s + i.investedAmount);
    final totalCurrent =
        activeInvestments.fold<double>(0, (s, i) => s + i.currentValue);
    if (totalInvested > 0) {
      final gain = totalCurrent - totalInvested;
      final pct = gain / totalInvested * 100;
      if (pct <= -5) {
        facts.add({
          'trigger_type': 'portfolio_drawdown',
          'invested': totalInvested.round(),
          'current_value': totalCurrent.round(),
          'unrealised_loss': gain.abs().round(),
          'percent': pct.round(),
          'holdings_count': activeInvestments.length,
        });
      } else if (pct >= 15) {
        facts.add({
          'trigger_type': 'portfolio_rally',
          'invested': totalInvested.round(),
          'current_value': totalCurrent.round(),
          'unrealised_gain': gain.round(),
          'percent': pct.round(),
          'holdings_count': activeInvestments.length,
        });
      }

      // Concentration: largest holding's share of current portfolio value.
      final largest = activeInvestments
          .reduce((a, b) => a.currentValue >= b.currentValue ? a : b);
      if (totalCurrent > 0) {
        final share = largest.currentValue / totalCurrent * 100;
        if (share >= 60) {
          facts.add({
            'trigger_type': 'portfolio_concentration',
            'largest_holding': largest.name,
            'largest_type': largest.type.displayName,
            'largest_value': largest.currentValue.round(),
            'portfolio_value': totalCurrent.round(),
            'percent': share.round(),
            'holdings_count': activeInvestments.length,
          });
        }
      }
    }
  }

  return facts;
}

// ─────────────────────────────────────────────────────────────────────────────
// LLM caller + orchestrator
// ─────────────────────────────────────────────────────────────────────────────

const _singleInsightSystemPrompt = '''
You are the proactive insight engine for Smart Wallet, a personal finance app. You receive a JSON object describing one financial event already detected by the app's rule engine. Your only job is to turn that structured fact into a short, calm insight shown as a card in the app.

RULES:
- Voice: warm, calm, non-alarming. No financial-advisor jargon. No exclamation marks. No urgency words like "URGENT" or "WARNING".
- Length: 1–2 sentences, max 30 words for the main message.
- Use only numbers present in the input. Never invent or round in a way that changes the figure.
- Currency is set by the app. Use the currency symbol provided.
- Avoid commanding language — no "should", "must", "need to". Prefer "might", "could", "worth a look".
- End with a soft, optional next step phrased as a light suggestion or question — never a command.
- If there is no natural action to suggest, set suggested_action and action_label to null.
- Output STRICT JSON only. No markdown, no preamble, no trailing text.

OUTPUT SCHEMA:
{
  "message": string,
  "tone": "positive" | "neutral" | "caution",
  "suggested_action": string | null,
  "action_label": string | null
}
''';

const _digestSystemPrompt = '''
You are the digest generator for Smart Wallet, a personal finance app. You receive a JSON array of financial facts collected over a period (daily, weekly, or monthly), plus the period type. Write one short digest summarizing the period.

RULES:
- Voice: calm, plain, second person ("you"). No hype, no urgency.
- Structure: one headline stat, one notable trend or comparison, and one light optional tip — in that order, combined into 2–3 short sentences total.
- Use only numbers present in the input facts. Never invent figures.
- Currency is set by the app. Use the currency symbol provided.
- Do not list every fact — pick the most relevant 1–2 and summarize the rest only if it changes the takeaway.
- No commanding language. Tip should be a soft suggestion, not an instruction.
- Output STRICT JSON only, no markdown, no preamble.

OUTPUT SCHEMA:
{
  "headline": string,
  "message": string,
  "tone": "positive" | "neutral" | "caution"
}
''';

// ─────────────────────────────────────────────────────────────────────────────
// Utility — robust JSON extraction from model output
// ─────────────────────────────────────────────────────────────────────────────

/// Strips markdown code fences and extracts the first JSON object from [text].
/// Models sometimes return ```json\n{...}\n``` despite json_object format hint.
Map<String, dynamic>? _extractJson(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  var s = text.trim();

  // Remove leading/trailing markdown fences (```json ... ``` or ``` ... ```)
  s = s.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: false), '');
  s = s.replaceAll(RegExp(r'\s*```\s*$', multiLine: false), '');
  s = s.trim();

  // Fast path — try parsing directly
  try {
    return jsonDecode(s) as Map<String, dynamic>;
  } catch (_) {}

  // Fallback — extract the first {...} block using a greedy regex
  final match = RegExp(r'\{[\s\S]+\}').firstMatch(s);
  if (match == null) return null;
  try {
    return jsonDecode(match.group(0)!) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

class ProactiveInsightService {
  /// Trigger types whose facts are time-sensitive: if the rule engine does NOT
  /// fire them in a given run, any cached DB row must be expired immediately.
  static const _timeSensitiveTypes = {
    'savings_streak',
    'budget_threshold',
    'goal_stalled',
    'portfolio_drawdown',
    'portfolio_rally',
    'portfolio_concentration',
  };

  /// Orchestrates: run rule engine → expire stale time-sensitive rows →
  /// call LLM for each new fact → upsert into DB.
  /// Safe to call on app start or after a transaction — dedup is handled by the repo.
  Future<void> generateAndStoreInsights({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required List<domain.Bill> bills,
    required List<domain.SavingsGoal> goals,
    List<domain.Investment> investments = const [],
    required String apiKey,
    required String aiModel,
    required domain.AiProvider aiProvider,
    required String currencySymbol,
    required ProactiveInsightRepository repository,
  }) async {
    if (apiKey.trim().isEmpty) return;

    final facts = runRuleEngine(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      bills: bills,
      goals: goals,
      investments: investments,
    );

    // ─ Freshness gate ──────────────────────────────────────────────────────────
    // For every time-sensitive type that was NOT produced by the rule engine
    // this run, immediately dismiss any lingering DB row so it is never shown
    // with stale data.
    final firedTypes = facts.map((f) => f['trigger_type'] as String).toSet();
    for (final sensitiveType in _timeSensitiveTypes) {
      if (!firedTypes.contains(sensitiveType)) {
        await repository.expireInsightsByType(sensitiveType);
      }
    }

    for (final fact in facts) {
      try {
        final insight = await _callLlmForInsight(
          fact: fact,
          apiKey: apiKey,
          aiModel: aiModel,
          aiProvider: aiProvider,
          currencySymbol: currencySymbol,
        );
        if (insight != null) {
          await repository.upsertInsight(insight);
        }
      } catch (_) {
        // Silently drop failed LLM calls — don't surface errors to the user
      }
    }
  }

  /// Calls OpenRouter with the single-insight system prompt + fact JSON.
  /// Returns null if the JSON output is malformed or the call fails.
  Future<ProactiveInsight?> _callLlmForInsight({
    required Map<String, dynamic> fact,
    required String apiKey,
    required String aiModel,
    required domain.AiProvider aiProvider,
    required String currencySymbol,
  }) async {
    final userMessage =
        'Currency symbol: $currencySymbol\n\nInput:\n${jsonEncode(fact)}';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (aiProvider == domain.AiProvider.anthropic) {
      headers['x-api-key'] = apiKey;
      headers['anthropic-version'] = '2023-06-01';
    } else {
      headers['Authorization'] = 'Bearer $apiKey';
      headers['HTTP-Referer'] = 'https://github.com/stibinottathai/smart_wallet';
      headers['X-Title'] = 'Smart Wallet';
    }

    final Map<String, dynamic> payload = {
      'model': aiModel,
      'messages': [
        {'role': 'user', 'content': userMessage},
      ],
      'max_tokens': 200,
    };
    if (aiProvider == domain.AiProvider.anthropic) {
      payload['system'] = _singleInsightSystemPrompt;
    } else {
      payload['messages'].insert(0, {'role': 'system', 'content': _singleInsightSystemPrompt});
      payload['response_format'] = {'type': 'json_object'};
    }

    final response = await http.post(
      Uri.parse(aiProvider.endpoint),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) return null;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      String? content;
      if (aiProvider == domain.AiProvider.anthropic) {
        final contentList = body['content'] as List<dynamic>?;
        if (contentList != null && contentList.isNotEmpty) {
          content = contentList[0]['text'] as String?;
        }
      } else {
        final choices = body['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          content = choices[0]['message']['content'] as String?;
        }
      }
      
      if (content == null) return null;
      content = content.trim().replaceAll('```json', '').replaceAll('```', '').trim();

      final parsed = _extractJson(content);
      if (parsed == null) return null;
      final message = parsed['message'] as String?;
      final toneStr = parsed['tone'] as String?;
      if (message == null || message.isEmpty) return null;

      return ProactiveInsight(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        triggerType: fact['trigger_type'] as String,
        category: fact['category'] as String?,
        message: message,
        tone: InsightTone.fromString(toneStr ?? 'neutral'),
        suggestedAction: parsed['suggested_action'] as String?,
        actionLabel: parsed['action_label'] as String?,
      );
    } catch (_) {
      return null; // Malformed JSON — drop silently
    }
  }

  /// Generates a digest (daily/weekly/monthly) from a list of facts.
  /// Returns a [ProactiveInsight] with triggerType='digest' or null on failure.
  Future<ProactiveInsight?> generateDigest({
    required String period, // 'daily' | 'weekly' | 'monthly'
    required List<Map<String, dynamic>> facts,
    required String apiKey,
    required String aiModel,
    required domain.AiProvider aiProvider,
    required String currencySymbol,
  }) async {
    if (apiKey.trim().isEmpty || facts.isEmpty) return null;

    final userMessage = jsonEncode({
      'period': period,
      'currency_symbol': currencySymbol,
      'facts': facts,
    });

    try {
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (aiProvider == domain.AiProvider.anthropic) {
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        headers['HTTP-Referer'] = 'https://github.com/stibinottathai/smart_wallet';
        headers['X-Title'] = 'Smart Wallet';
      }

      final Map<String, dynamic> payload = {
        'model': aiModel,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 250,
      };
      if (aiProvider == domain.AiProvider.anthropic) {
        payload['system'] = _digestSystemPrompt;
      } else {
        payload['messages'].insert(0, {'role': 'system', 'content': _digestSystemPrompt});
        payload['response_format'] = {'type': 'json_object'};
      }

      final response = await http.post(
        Uri.parse(aiProvider.endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      String? content;
      if (aiProvider == domain.AiProvider.anthropic) {
        final contentList = body['content'] as List<dynamic>?;
        if (contentList != null && contentList.isNotEmpty) {
          content = contentList[0]['text'] as String?;
        }
      } else {
        final choices = body['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          content = choices[0]['message']['content'] as String?;
        }
      }
      
      if (content == null) return null;
      content = content.trim().replaceAll('```json', '').replaceAll('```', '').trim();

      final parsed = _extractJson(content);
      if (parsed == null) return null;
      final message = parsed['message'] as String?;
      final headline = parsed['headline'] as String?;
      if (message == null || message.isEmpty) return null;

      return ProactiveInsight(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        triggerType: 'digest_$period',
        category: null,
        message: headline != null ? '$headline\n$message' : message,
        tone: InsightTone.fromString(parsed['tone'] as String? ?? 'neutral'),
        suggestedAction: null,
        actionLabel: null,
      );
    } catch (_) {
      return null;
    }
  }
}

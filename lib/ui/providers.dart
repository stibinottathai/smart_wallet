import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/income_repository_impl.dart';
import '../data/repositories/savings_goal_repository_impl.dart';
import '../data/repositories/bill_repository_impl.dart';
import '../data/repositories/proactive_insight_repository_impl.dart';
import '../data/repositories/health_score_repository_impl.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/transfer_repository_impl.dart';
import '../data/repositories/recurring_rule_repository_impl.dart';
import '../data/repositories/debt_repository_impl.dart';
import '../data/repositories/investment_repository_impl.dart';
import '../data/services/investment_transfer_service.dart';
import '../data/services/recurring_transaction_service.dart';
import '../data/services/subscription_detection_service.dart';
import '../data/services/currency_conversion_service.dart';
import '../data/services/database.dart' hide ProactiveInsight;
import '../data/services/insights_service.dart';
import '../data/services/proactive_insight_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/pdf_report_service.dart';
import '../data/services/receipt_scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/currency_utils.dart';
import '../domain/models/models.dart' as domain;
import '../domain/models/proactive_insight.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/income_repository.dart';
import '../domain/repositories/savings_goal_repository.dart';
import '../domain/repositories/bill_repository.dart';
import '../domain/repositories/health_score_repository.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/transfer_repository.dart';
import '../domain/repositories/recurring_rule_repository.dart';
import '../domain/repositories/debt_repository.dart';
import '../domain/repositories/investment_repository.dart';
import '../data/services/financial_health_service.dart';

// Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Repositories
final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return IncomeRepositoryImpl(db);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseRepositoryImpl(db);
});

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SavingsGoalRepositoryImpl(db);
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BillRepositoryImpl(db);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepositoryImpl(db);
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransferRepositoryImpl(db);
});

final recurringRuleRepositoryProvider = Provider<RecurringRuleRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringRuleRepositoryImpl(db);
});

final recurringTransactionServiceProvider = Provider<RecurringTransactionService>((ref) {
  return RecurringTransactionService();
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DebtRepositoryImpl(db);
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestmentRepositoryImpl(db);
});

final investmentTransferServiceProvider =
    Provider<InvestmentTransferService>((ref) {
  return InvestmentTransferService(ref.watch(transferRepositoryProvider));
});

final currencyConversionServiceProvider = Provider<CurrencyConversionService>((ref) {
  return CurrencyConversionService();
});

// Services
final receiptScanServiceProvider = Provider<ReceiptScanService>((ref) {
  return ReceiptScanService();
});

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService();
});

final proactiveInsightRepositoryProvider = Provider<ProactiveInsightRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProactiveInsightRepository(db);
});

final proactiveInsightServiceProvider = Provider<ProactiveInsightService>((ref) {
  return ProactiveInsightService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  final db = ref.watch(databaseProvider);
  final currencyCode = ref.watch(currencyCodeProvider);
  return PdfReportService(db, currencyCode: currencyCode);
});

final healthScoreRepositoryProvider = Provider<HealthScoreRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HealthScoreRepositoryImpl(db);
});

final healthScoreServiceProvider = Provider<FinancialHealthService>((ref) {
  final code = ref.watch(currencyCodeProvider);
  return FinancialHealthService(currencySymbol: currencySymbol(code));
});


// Streams
final allIncomesProvider = StreamProvider<List<domain.Income>>((ref) {
  final repo = ref.watch(incomeRepositoryProvider);
  return repo.watchAllIncomes();
});

final allExpensesProvider = StreamProvider<List<domain.Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllExpenses();
});

final allCategoriesProvider = StreamProvider<List<domain.Category>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllCategories();
});

final allSavingsGoalsProvider = StreamProvider<List<domain.SavingsGoal>>((ref) {
  final repo = ref.watch(savingsGoalRepositoryProvider);
  return repo.watchAllGoals();
});

final allBillsProvider = StreamProvider<List<domain.Bill>>((ref) {
  final repo = ref.watch(billRepositoryProvider);
  return repo.watchAllBills();
});

final allAccountsProvider = StreamProvider<List<domain.Account>>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAllAccounts();
});

final allTransfersProvider = StreamProvider<List<domain.Transfer>>((ref) {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.watchAllTransfers();
});

final allRecurringRulesProvider = StreamProvider<List<domain.RecurringRule>>((ref) {
  final repo = ref.watch(recurringRuleRepositoryProvider);
  return repo.watchAllRules();
});

final allDebtsProvider = StreamProvider<List<domain.Debt>>((ref) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchAllDebts();
});

final allInvestmentsProvider = StreamProvider<List<domain.Investment>>((ref) {
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchAllInvestments();
});

/// Wallets the user actually spends from — every active account except the
/// hidden `acc_investments` system wallet that holds investment cost basis.
const String _kInvestmentAccountId = 'acc_investments';

/// Total liquid cash across every user-visible account. This is the "Available
/// Cash" surfaced on the dashboard and used as the cash leg of net worth.
/// Investments are intentionally excluded — they're tracked separately at
/// their current market value via [investmentAssetsValueProvider].
final availableCashProvider = Provider<double>((ref) {
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final balances = ref.watch(accountBalancesProvider);
  double total = 0;
  for (final a in accounts) {
    if (a.archived) continue;
    if (a.id == _kInvestmentAccountId) continue;
    total += balances[a.id] ?? 0;
  }
  return total;
});

/// Sum of every active investment's **current market value** (not cost basis).
/// This is the investment-asset leg of net worth — unrealized gains/losses are
/// captured automatically because [Investment.currentValue] is what the user
/// last marked the holding at.
final investmentAssetsValueProvider = Provider<double>((ref) {
  final investments = ref.watch(allInvestmentsProvider).value ?? const [];
  return investments
      .where((i) => !i.isClosed)
      .fold<double>(0, (s, i) => s + i.currentValue);
});

/// Available Cash + Investments at current value — the headline number for
/// the dashboard's wealth summary. Liabilities (debts) are surfaced
/// separately in the Net Worth view rather than netted here.
final totalNetWorthProvider = Provider<double>((ref) {
  return ref.watch(availableCashProvider) +
      ref.watch(investmentAssetsValueProvider);
});

/// Subscriptions auto-detected from expense history (recurring merchants).
final detectedSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  final expenses = ref.watch(allExpensesProvider).value ?? const [];
  final categories = ref.watch(allCategoriesProvider).value ?? const [];
  return SubscriptionDetectionService.detect(
    expenses: expenses,
    categories: categories,
  );
});

/// Runs the recurring-transaction catch-up once and returns how many entries
/// were posted. Read this on app launch; the resulting expenses/incomes flow
/// back into the watch streams automatically.
final processRecurringProvider = FutureProvider.autoDispose<RecurringPostResult>((ref) async {
  final service = ref.read(recurringTransactionServiceProvider);
  return service.processDue(
    ruleRepository: ref.read(recurringRuleRepositoryProvider),
    expenseRepository: ref.read(expenseRepositoryProvider),
    incomeRepository: ref.read(incomeRepositoryProvider),
  );
});

/// Fallback account that legacy (pre-multi-account) transactions are attributed
/// to. Transactions with a null [accountId] count against this account's
/// balance so totals stay consistent.
const String defaultAccountId = 'acc_cash';

/// Current balance per account id, derived from opening balance, incomes,
/// expenses and transfers. Returns an empty map until the underlying data has
/// loaded.
final accountBalancesProvider = Provider<Map<String, double>>((ref) {
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final expenses = ref.watch(allExpensesProvider).value ?? const [];
  final incomes = ref.watch(allIncomesProvider).value ?? const [];
  final transfers = ref.watch(allTransfersProvider).value ?? const [];

  final balances = <String, double>{
    for (final a in accounts) a.id: a.openingBalance,
  };

  void add(String? accountId, double delta) {
    final id = (accountId == null || !balances.containsKey(accountId))
        ? defaultAccountId
        : accountId;
    if (!balances.containsKey(id)) return; // no accounts loaded yet
    balances[id] = (balances[id] ?? 0) + delta;
  }

  for (final inc in incomes) {
    add(inc.accountId, inc.amount);
  }
  for (final exp in expenses) {
    add(exp.accountId, -exp.amount);
  }
  for (final t in transfers) {
    add(t.fromAccountId, -t.amount);
    add(t.toAccountId, t.amount);
  }

  return balances;
});

/// The ID of the account marked as default. Falls back to [defaultAccountId]
/// ('acc_cash') if no account has [isDefault] set, ensuring backwards compat.
final defaultAccountIdProvider = Provider<String>((ref) {
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final found = accounts.where((a) => a.isDefault).firstOrNull;
  return found?.id ?? defaultAccountId;
});

// ── Income Sources ──────────────────────────────────────────────────────────
// Stored in SharedPreferences so users can manage them independently of the DB.
// 'Other' is always appended at the end of the form dropdown and is NOT stored.

const String _kIncomeSourcesPrefKey = 'income_sources_v3';
const String _kLegacyIncomeSourcesPrefKey = 'income_sources_v2';

final List<domain.Category> _kDefaultIncomeSources = [
  const domain.Category(id: 'inc_salary', name: 'Salary', icon: 'payments', color: '#6BAE6E', isDefault: true),
  const domain.Category(id: 'inc_freelance', name: 'Freelance', icon: 'computer', color: '#688F80', isDefault: true),
  const domain.Category(id: 'inc_business', name: 'Business', icon: 'business', color: '#2F6F5E', isDefault: true),
  const domain.Category(id: 'inc_sale', name: 'Sale', icon: 'shopping_bag', color: '#4A90C4', isDefault: true),
  const domain.Category(id: 'inc_investment', name: 'Investment', icon: 'trending_up', color: '#7B5EA7', isDefault: true),
];

class IncomeSourcesNotifier extends StateNotifier<List<domain.Category>> {
  IncomeSourcesNotifier() : super(List.from(_kDefaultIncomeSources)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kIncomeSourcesPrefKey);
    if (stored != null) {
      try {
        final list = jsonDecode(stored) as List;
        state = list.map((e) {
          final id = e['id'] as String;
          final defaultMatch = _kDefaultIncomeSources.where((d) => d.id == id).firstOrNull;
          if (defaultMatch != null) return defaultMatch;
          
          return domain.Category(
            id: id,
            name: e['name'] as String,
            icon: e['icon'] as String,
            color: e['color'] as String,
          );
        }).toList();
      } catch (_) {
        state = List.from(_kDefaultIncomeSources);
        await _save();
      }
    } else {
      // Check for legacy string-based sources to migrate
      final legacyStored = prefs.getString(_kLegacyIncomeSourcesPrefKey);
      if (legacyStored != null) {
        try {
          final legacyList = List<String>.from((jsonDecode(legacyStored) as List).cast<String>());
          state = legacyList.map((name) {
            // Find a match in defaults or assign a default icon/color
            final defaultMatch = _kDefaultIncomeSources.where((d) => d.name == name).firstOrNull;
            return defaultMatch ?? domain.Category(
              id: 'inc_${name.toLowerCase().replaceAll(' ', '_')}',
              name: name,
              icon: 'payments',
              color: '#6BAE6E',
            );
          }).toList();
        } catch (_) {
          state = List.from(_kDefaultIncomeSources);
        }
      } else {
        state = List.from(_kDefaultIncomeSources);
      }
      await _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((c) => {
      'id': c.id,
      'name': c.name,
      'icon': c.icon,
      'color': c.color,
    }).toList();
    await prefs.setString(_kIncomeSourcesPrefKey, jsonEncode(list));
  }

  Future<void> add(domain.Category source) async {
    if (state.length >= 15) return;
    state = [...state, source];
    await _save();
  }

  Future<void> updateItem(int index, domain.Category newCategory) async {
    if (index < 0 || index >= state.length) return;
    final list = List<domain.Category>.from(state);
    list[index] = newCategory;
    state = list;
    await _save();
  }

  Future<void> delete(int index) async {
    if (index < 0 || index >= state.length) return;
    final list = List<domain.Category>.from(state);
    list.removeAt(index);
    state = list;
    await _save();
  }

  /// Replaces the entire list (used by backup restore).
  Future<void> replaceAll(List<domain.Category> sources) async {
    state = List.from(sources);
    await _save();
  }
}

final incomeSourcesProvider =
    StateNotifierProvider<IncomeSourcesNotifier, List<domain.Category>>(
        (ref) => IncomeSourcesNotifier());

// AI Settings
// Default to OpenRouter + DeepSeek so the app is usable out of the box (and the
// config dialog shows DeepSeek selected rather than "Other (Custom)").
const _defaultAiModel = 'deepseek/deepseek-chat';
domain.AiProvider _initialAiProvider = domain.AiProvider.openRouter;
String _initialAiApiKey = '';
String _initialAiModel = _defaultAiModel;

Future<void> loadAiSettingsPref() async {
  final prefs = await SharedPreferences.getInstance();
  _initialAiProvider = domain.AiProvider.fromString(prefs.getString('ai_provider') ?? 'openRouter');
  _initialAiApiKey = prefs.getString('ai_api_key') ?? '';
  final savedModel = prefs.getString('ai_model');
  _initialAiModel =
      (savedModel == null || savedModel.isEmpty) ? _defaultAiModel : savedModel;
}

Future<void> saveAiProvider(domain.AiProvider provider) async {
  _initialAiProvider = provider;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ai_provider', provider.name);
}

Future<void> saveAiApiKey(String key) async {
  _initialAiApiKey = key;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ai_api_key', key);
}

Future<void> saveAiModel(String model) async {
  _initialAiModel = model;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ai_model', model);
}

final aiProviderProvider = StateProvider<domain.AiProvider>((ref) => _initialAiProvider);
final aiApiKeyProvider = StateProvider<String>((ref) => _initialAiApiKey);
final aiModelProvider = StateProvider<String>((ref) => _initialAiModel);

final remindersEnabledProvider = StateProvider<bool>((ref) => true);

final budgetAlertsEnabledProvider = StateProvider<bool>((ref) => true);

final dailyTipEnabledProvider = StateProvider<bool>((ref) => true);

final activeTabIndexProvider = StateProvider<int>((ref) => 0);

final analysisDateRangeProvider = StateProvider<(DateTime, DateTime)?>((ref) {
  final now = DateTime.now();
  return (DateTime(now.year, now.month - 5, 1), DateTime(now.year, now.month + 1, 0));
});

/// Message queued by a smart-alert action button to be auto-sent in the AI
/// chat as soon as the chat tab is shown. Cleared after the chat sends it.
final pendingChatMessageProvider = StateProvider<String?>((ref) => null);

/// Stream of non-dismissed proactive insight cards, newest first.
final activeInsightsProvider = StreamProvider<List<ProactiveInsight>>((ref) {
  final repo = ref.watch(proactiveInsightRepositoryProvider);
  return repo.watchActiveInsights();
});

final financialHealthScoreProvider = FutureProvider<domain.FinancialHealthScore>((ref) async {
  final incomes = ref.watch(allIncomesProvider).value ?? [];
  final expenses = ref.watch(allExpensesProvider).value ?? [];
  final categories = ref.watch(allCategoriesProvider).value ?? [];
  final goals = ref.watch(allSavingsGoalsProvider).value ?? [];
  final bills = ref.watch(allBillsProvider).value ?? [];
  final service = ref.watch(healthScoreServiceProvider);
  final repo = ref.watch(healthScoreRepositoryProvider);

  final now = DateTime.now();
  final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final lastMonth = DateTime(now.year, now.month - 1, 1);
  final lastMonthStr = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';

  final previousSnapshot = await repo.getSnapshot(lastMonthStr);

  final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
  final totalExpense = expenses.fold(0.0, (s, e) => s + e.amount);
  final netBalance = totalIncome - totalExpense;

  final score = service.compute(
    incomes: incomes,
    expenses: expenses,
    categories: categories,
    goals: goals,
    bills: bills,
    netBalance: netBalance,
    previousSnapshot: previousSnapshot,
  );

  // Save snapshot for the current month
  await repo.saveSnapshot(score, currentMonth);

  return score;
});

/// Automatically triggers the rule engine + LLM pipeline on app launch and
/// whenever the number of expenses or incomes changes (new transaction added or
/// deleted). Watched by DashboardView to stay alive. Capped at 3 runs per day
/// so the AI is not called excessively. Skipped when no API key is configured
/// or there is no transaction data yet.
final autoInsightRefreshProvider = FutureProvider<void>((ref) async {
  // Re-run this provider whenever the transaction or holdings counts change,
  // so portfolio drawdowns/rallies surface as soon as the user updates a
  // current value — not only when a new expense or income is logged.
  final expCount = (ref.watch(allExpensesProvider).value ?? []).length;
  final incCount = (ref.watch(allIncomesProvider).value ?? []).length;
  final invCount = (ref.watch(allInvestmentsProvider).value ?? []).length;
  if (expCount == 0 && incCount == 0 && invCount == 0) return;

  final apiKey = ref.read(aiApiKeyProvider);
  if (apiKey.isEmpty) return;

  // ── Daily rate limit: max 3 auto-refreshes per calendar day ─────────────
  const _dateKey  = 'insight_auto_refresh_date';
  const _countKey = 'insight_auto_refresh_count';
  const _maxPerDay = 3;

  final prefs   = await SharedPreferences.getInstance();
  final today   = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final savedDate  = prefs.getString(_dateKey) ?? '';
  final savedCount = (savedDate == todayStr) ? (prefs.getInt(_countKey) ?? 0) : 0;

  if (savedCount >= _maxPerDay) return;

  await prefs.setString(_dateKey, todayStr);
  await prefs.setInt(_countKey, savedCount + 1);
  // ─────────────────────────────────────────────────────────────────────────

  final service = ref.read(proactiveInsightServiceProvider);
  final repo = ref.read(proactiveInsightRepositoryProvider);
  final expenses = ref.read(allExpensesProvider).value ?? [];
  final incomes = ref.read(allIncomesProvider).value ?? [];
  final categories = ref.read(allCategoriesProvider).value ?? [];
  final bills = ref.read(allBillsProvider).value ?? [];
  final goals = ref.read(allSavingsGoalsProvider).value ?? [];
  final investments = ref.read(allInvestmentsProvider).value ?? [];
  final aiModel = ref.read(aiModelProvider);
  final aiProvider = ref.read(aiProviderProvider);
  final code = ref.read(currencyCodeProvider);
  final sym = currencySymbol(code);

  await service.generateAndStoreInsights(
    expenses: expenses,
    incomes: incomes,
    categories: categories,
    bills: bills,
    goals: goals,
    investments: investments,
    apiKey: apiKey,
    aiModel: aiModel,
    aiProvider: aiProvider,
    currencySymbol: sym,
    repository: repo,
  );
});

/// Call this to trigger the rule engine + LLM pipeline and refresh cards.
final refreshInsightsProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.read(proactiveInsightServiceProvider);
  final repo = ref.read(proactiveInsightRepositoryProvider);
  final expenses = ref.read(allExpensesProvider).value ?? [];
  final incomes = ref.read(allIncomesProvider).value ?? [];
  final categories = ref.read(allCategoriesProvider).value ?? [];
  final bills = ref.read(allBillsProvider).value ?? [];
  final goals = ref.read(allSavingsGoalsProvider).value ?? [];
  final investments = ref.read(allInvestmentsProvider).value ?? [];
  final apiKey = ref.read(aiApiKeyProvider);
  final aiModel = ref.read(aiModelProvider);
  final aiProvider = ref.read(aiProviderProvider);
  final code = ref.read(currencyCodeProvider);
  final sym = currencySymbol(code);

  await service.generateAndStoreInsights(
    expenses: expenses,
    incomes: incomes,
    categories: categories,
    bills: bills,
    goals: goals,
    investments: investments,
    apiKey: apiKey,
    aiModel: aiModel,
    aiProvider: aiProvider,
    currencySymbol: sym,
    repository: repo,
  );
});

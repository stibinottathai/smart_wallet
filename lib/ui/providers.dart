import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/income_repository_impl.dart';
import '../data/repositories/savings_goal_repository_impl.dart';
import '../data/repositories/bill_repository_impl.dart';
import '../data/repositories/proactive_insight_repository_impl.dart';
import '../data/repositories/health_score_repository_impl.dart';
import '../data/services/database.dart' hide ProactiveInsight;
import '../data/services/insights_service.dart';
import '../data/services/proactive_insight_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/pdf_report_service.dart';
import '../data/services/receipt_scan_service.dart';
import 'core/currency_utils.dart';
import '../domain/models/models.dart' as domain;
import '../domain/models/proactive_insight.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/income_repository.dart';
import '../domain/repositories/savings_goal_repository.dart';
import '../domain/repositories/bill_repository.dart';
import '../domain/repositories/health_score_repository.dart';
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

// OpenRouter API Key — reads directly from the .env file
final openRouterApiKeyProvider = Provider<String>((ref) {
  return dotenv.env['OPENROUTER_API_KEY'] ?? '';
});

final remindersEnabledProvider = StateProvider<bool>((ref) => true);

final budgetAlertsEnabledProvider = StateProvider<bool>((ref) => true);

final dailyTipEnabledProvider = StateProvider<bool>((ref) => true);

final activeTabIndexProvider = StateProvider<int>((ref) => 0);

final analysisDateRangeProvider = StateProvider<(DateTime, DateTime)?>((ref) {
  final now = DateTime.now();
  return (DateTime(now.year, now.month - 5, 1), DateTime(now.year, now.month + 1, 0));
});

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

/// Call this to trigger the rule engine + LLM pipeline and refresh cards.
final refreshInsightsProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.read(proactiveInsightServiceProvider);
  final repo = ref.read(proactiveInsightRepositoryProvider);
  final expenses = ref.read(allExpensesProvider).value ?? [];
  final incomes = ref.read(allIncomesProvider).value ?? [];
  final categories = ref.read(allCategoriesProvider).value ?? [];
  final bills = ref.read(allBillsProvider).value ?? [];
  final goals = ref.read(allSavingsGoalsProvider).value ?? [];
  final apiKey = ref.read(openRouterApiKeyProvider);
  final code = ref.read(currencyCodeProvider);
  final sym = currencySymbol(code);

  await service.generateAndStoreInsights(
    expenses: expenses,
    incomes: incomes,
    categories: categories,
    bills: bills,
    goals: goals,
    apiKey: apiKey,
    currencySymbol: sym,
    repository: repo,
  );
});

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/income_repository_impl.dart';
import '../data/repositories/savings_goal_repository_impl.dart';
import '../data/repositories/bill_repository_impl.dart';
import '../data/services/database.dart';
import '../data/services/insights_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/pdf_report_service.dart';
import '../data/services/receipt_scan_service.dart';
import '../domain/models/models.dart' as domain;
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/income_repository.dart';
import '../domain/repositories/savings_goal_repository.dart';
import '../domain/repositories/bill_repository.dart';

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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  final db = ref.watch(databaseProvider);
  return PdfReportService(db);
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

final remindersEnabledProvider = StateProvider<bool>((ref) => false);

final analysisDateRangeProvider = StateProvider<(DateTime, DateTime)?>((ref) {
  final now = DateTime.now();
  return (DateTime(now.year, now.month - 5, 1), DateTime(now.year, now.month + 1, 0));
});

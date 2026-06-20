import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/income_repository_impl.dart';
import '../data/services/database.dart';
import '../data/services/insights_service.dart';
import '../data/services/receipt_scan_service.dart';
import '../domain/models/models.dart' as domain;
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/income_repository.dart';

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

// Services
final receiptScanServiceProvider = Provider<ReceiptScanService>((ref) {
  return ReceiptScanService();
});

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService();
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

// Gemini API Key State Management
final geminiApiKeyProvider = StateNotifierProvider<GeminiApiKeyNotifier, String>((ref) {
  return GeminiApiKeyNotifier();
});

class GeminiApiKeyNotifier extends StateNotifier<String> {
  static const _key = 'gemini_api_key_pref';

  GeminiApiKeyNotifier() : super(const String.fromEnvironment('GEMINI_API_KEY')) {
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_key);
    if (savedKey != null && savedKey.isNotEmpty) {
      state = savedKey;
    }
  }

  Future<void> saveKey(String newKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newKey);
    state = newKey;
  }
}

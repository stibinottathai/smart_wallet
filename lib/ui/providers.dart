import 'package:flutter_dotenv/flutter_dotenv.dart';
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

// OpenRouter API Key State Management
final isUsingCustomKeyProvider = StateProvider<bool>((ref) => false);

final openRouterApiKeyProvider = StateNotifierProvider<OpenRouterApiKeyNotifier, String>((ref) {
  return OpenRouterApiKeyNotifier(ref);
});

class OpenRouterApiKeyNotifier extends StateNotifier<String> {
  static const _key = 'openrouter_api_key_pref';
  final Ref _ref;

  OpenRouterApiKeyNotifier(this._ref) : super(dotenv.env['OPENROUTER_API_KEY'] ?? '') {
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    var savedKey = prefs.getString(_key);
    if (savedKey == null || savedKey.isEmpty) {
      // Migrate from legacy Gemini preference if it exists
      final legacyKey = prefs.getString('gemini_api_key_pref');
      if (legacyKey != null && legacyKey.isNotEmpty) {
        savedKey = legacyKey;
        await prefs.setString(_key, legacyKey);
        await prefs.remove('gemini_api_key_pref'); // clean up legacy key
      }
    }
    if (savedKey != null && savedKey.isNotEmpty) {
      state = savedKey;
      _ref.read(isUsingCustomKeyProvider.notifier).state = true;
    } else {
      state = dotenv.env['OPENROUTER_API_KEY'] ?? '';
      _ref.read(isUsingCustomKeyProvider.notifier).state = false;
    }
  }

  Future<void> saveKey(String newKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (newKey.trim().isEmpty) {
      await prefs.remove(_key);
      state = dotenv.env['OPENROUTER_API_KEY'] ?? '';
      _ref.read(isUsingCustomKeyProvider.notifier).state = false;
    } else {
      await prefs.setString(_key, newKey.trim());
      state = newKey.trim();
      _ref.read(isUsingCustomKeyProvider.notifier).state = true;
    }
  }
}


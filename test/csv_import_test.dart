import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/domain/repositories/expense_repository.dart';
import 'package:smart_wallet/domain/repositories/income_repository.dart';
import 'package:smart_wallet/data/services/csv_import_service.dart';

class FakeIncomeRepository implements IncomeRepository {
  final List<domain.Income> incomes = [];

  @override
  Future<List<domain.Income>> getAllIncomes() async => incomes;

  @override
  Future<void> addIncome(domain.Income income) async {
    incomes.add(income);
  }

  @override
  Future<void> updateIncome(domain.Income income) async {
    final index = incomes.indexWhere((element) => element.id == income.id);
    if (index != -1) {
      incomes[index] = income;
    }
  }

  @override
  Future<void> deleteIncome(String id) async {
    incomes.removeWhere((element) => element.id == id);
  }

  @override
  Future<List<domain.Income>> getIncomesBetween(DateTime start, DateTime end) async => [];

  @override
  Stream<List<domain.Income>> watchAllIncomes() => Stream.value(incomes);
}

class FakeExpenseRepository implements ExpenseRepository {
  final List<domain.Expense> expenses = [];
  final List<domain.Category> categories = [
    const domain.Category(id: 'cat_dining', name: 'Dining & Drinks', icon: 'rest', color: '#B56'),
  ];

  @override
  Future<List<domain.Expense>> getAllExpenses() async => expenses;

  @override
  Future<List<domain.Category>> getAllCategories() async => categories;

  @override
  Future<void> addExpense(domain.Expense expense) async {
    expenses.add(expense);
  }

  @override
  Future<void> updateExpense(domain.Expense expense) async {
    final index = expenses.indexWhere((element) => element.id == expense.id);
    if (index != -1) {
      expenses[index] = expense;
    }
  }

  @override
  Future<void> addCategory(domain.Category category) async {
    categories.add(category);
  }

  @override
  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((element) => element.id == id);
  }

  @override
  Future<List<domain.Expense>> getExpensesBetween(DateTime start, DateTime end) async => [];

  @override
  Future<domain.Category?> getCategoryById(String id) async {
    return categories.firstWhere((element) => element.id == id);
  }

  @override
  Future<void> updateCategory(domain.Category category) async {}

  @override
  Stream<List<domain.Category>> watchAllCategories() => Stream.value(categories);

  @override
  Stream<List<domain.Expense>> watchAllExpenses() => Stream.value(expenses);
}

void main() {
  group('CSV Import Service Tests', () {
    late FakeIncomeRepository incomeRepo;
    late FakeExpenseRepository expenseRepo;
    late CsvImportService importService;

    setUp(() {
      incomeRepo = FakeIncomeRepository();
      expenseRepo = FakeExpenseRepository();
      importService = CsvImportService();
    });

    test('Parses and imports Incomes and Expenses correctly', () async {
      const csvContent = '''
--- INCOMES ---
ID,Date,Source,Amount,Recurring,Frequency
inc_1,2026-06-10,Salary,5000,Yes,Monthly
inc_2,2026-06-12,Freelance,120,No,One-off

--- EXPENSES ---
ID,Date,Category,Amount,Note,Source
exp_1,2026-06-11,Dining & Drinks,45.5,"dinner with friends",manual
exp_2,2026-06-13,Shopping,79.9,"new shoes",manual
''';

      final result = await importService.importDataFromCsvContent(
        content: csvContent,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
      );

      expect(result.success, isTrue);
      expect(result.incomesImported, 2);
      expect(result.expensesImported, 2);
      expect(result.categoriesCreated, 1);

      // Verify Incomes
      expect(incomeRepo.incomes.length, 2);
      expect(incomeRepo.incomes[0].id, 'inc_1');
      expect(incomeRepo.incomes[0].source, 'Salary');
      expect(incomeRepo.incomes[0].amount, 5000.0);
      expect(incomeRepo.incomes[0].isRecurring, isTrue);
      expect(incomeRepo.incomes[0].frequency, domain.IncomeFrequency.monthly);

      // Verify Expenses
      expect(expenseRepo.expenses.length, 2);
      expect(expenseRepo.expenses[0].id, 'exp_1');
      expect(expenseRepo.expenses[0].categoryId, 'cat_dining');
      expect(expenseRepo.expenses[0].amount, 45.5);
      expect(expenseRepo.expenses[0].note, 'dinner with friends');

      // Verify New Category created
      expect(expenseRepo.categories.any((c) => c.name == 'Shopping'), isTrue);
      final shoppingCat = expenseRepo.categories.firstWhere((c) => c.name == 'Shopping');
      expect(expenseRepo.expenses[1].categoryId, shoppingCat.id);
    });

    test('Duplicates are updated (upserted) instead of inserted twice', () async {
      // Add initial data
      await incomeRepo.addIncome(domain.Income(
        id: 'inc_1',
        date: DateTime(2026, 6, 10),
        source: 'Old Salary',
        amount: 4500,
        isRecurring: true,
        frequency: domain.IncomeFrequency.monthly,
      ));

      const csvContent = '''
--- INCOMES ---
ID,Date,Source,Amount,Recurring,Frequency
inc_1,2026-06-10,Salary,5000,Yes,Monthly
''';

      final result = await importService.importDataFromCsvContent(
        content: csvContent,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
      );

      expect(result.success, isTrue);
      expect(result.incomesImported, 1);
      expect(incomeRepo.incomes.length, 1);
      expect(incomeRepo.incomes[0].source, 'Salary');
      expect(incomeRepo.incomes[0].amount, 5000.0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/domain/repositories/expense_repository.dart';
import 'package:smart_wallet/domain/repositories/income_repository.dart';
import 'package:smart_wallet/domain/repositories/savings_goal_repository.dart';
import 'package:smart_wallet/domain/repositories/bill_repository.dart';
import 'package:smart_wallet/data/services/csv_import_service.dart';
import 'package:smart_wallet/data/services/csv_export_service.dart';

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
  Future<void> updateCategory(domain.Category category) async {
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) categories[index] = category;
  }

  @override
  Stream<List<domain.Category>> watchAllCategories() => Stream.value(categories);

  @override
  Stream<List<domain.Expense>> watchAllExpenses() => Stream.value(expenses);
}

class FakeSavingsGoalRepository implements SavingsGoalRepository {
  final List<domain.SavingsGoal> goals = [];

  @override
  Future<List<domain.SavingsGoal>> getAllGoals() async => goals;

  @override
  Future<void> addGoal(domain.SavingsGoal goal) async => goals.add(goal);

  @override
  Future<void> updateGoal(domain.SavingsGoal goal) async {
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i != -1) goals[i] = goal;
  }

  @override
  Future<void> deleteGoal(String id) async =>
      goals.removeWhere((g) => g.id == id);

  @override
  Stream<List<domain.SavingsGoal>> watchAllGoals() => Stream.value(goals);
}

class FakeBillRepository implements BillRepository {
  final List<domain.Bill> bills = [];

  @override
  Future<List<domain.Bill>> getAllBills() async => bills;

  @override
  Future<void> addBill(domain.Bill bill) async => bills.add(bill);

  @override
  Future<void> updateBill(domain.Bill bill) async {
    final i = bills.indexWhere((b) => b.id == bill.id);
    if (i != -1) bills[i] = bill;
  }

  @override
  Future<void> deleteBill(String id) async =>
      bills.removeWhere((b) => b.id == id);

  @override
  Stream<List<domain.Bill>> watchAllBills() => Stream.value(bills);
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

    test('Round-trips budgets, savings goals and bills via export + import', () async {
      final goalRepo = FakeSavingsGoalRepository();
      final billRepo = FakeBillRepository();

      // Source data, including a category that carries a monthly budget limit.
      final categories = [
        const domain.Category(
          id: 'cat_dining',
          name: 'Dining & Drinks',
          icon: 'rest',
          color: '#B56',
          budgetLimit: 300.0,
        ),
      ];
      final goals = [
        domain.SavingsGoal(
          id: 'goal_1',
          name: 'Emergency Fund',
          targetAmount: 10000,
          currentAmount: 2500,
          targetDate: DateTime(2026, 12, 31),
          color: '#2F6F5E',
        ),
      ];
      final bills = [
        domain.Bill(
          id: 'bill_1',
          name: 'Netflix',
          amount: 15.99,
          dueDate: DateTime(2026, 7, 1),
          isPaid: false,
          frequency: domain.BillFrequency.monthly,
          categoryId: 'cat_dining',
        ),
      ];

      final csv = CsvExportService().buildCsvContent(
        incomes: const [],
        expenses: const [],
        categories: categories,
        goals: goals,
        bills: bills,
      );

      final result = await importService.importDataFromCsvContent(
        content: csv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
        savingsGoalRepository: goalRepo,
        billRepository: billRepo,
      );

      expect(result.success, isTrue);
      expect(result.budgetsImported, 1);
      expect(result.goalsImported, 1);
      expect(result.billsImported, 1);

      // Budget limit restored onto the existing category.
      final dining = expenseRepo.categories.firstWhere((c) => c.id == 'cat_dining');
      expect(dining.budgetLimit, 300.0);

      // Savings goal restored.
      expect(goalRepo.goals.length, 1);
      expect(goalRepo.goals[0].name, 'Emergency Fund');
      expect(goalRepo.goals[0].targetAmount, 10000);
      expect(goalRepo.goals[0].currentAmount, 2500);

      // Bill restored, with its category re-linked by name.
      expect(billRepo.bills.length, 1);
      expect(billRepo.bills[0].name, 'Netflix');
      expect(billRepo.bills[0].amount, 15.99);
      expect(billRepo.bills[0].frequency, domain.BillFrequency.monthly);
      expect(billRepo.bills[0].categoryId, 'cat_dining');
    });
  });
}

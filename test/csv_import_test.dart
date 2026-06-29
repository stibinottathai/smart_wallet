import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/domain/repositories/expense_repository.dart';
import 'package:smart_wallet/domain/repositories/income_repository.dart';
import 'package:smart_wallet/domain/repositories/savings_goal_repository.dart';
import 'package:smart_wallet/domain/repositories/bill_repository.dart';
import 'package:smart_wallet/domain/repositories/recurring_rule_repository.dart';
import 'package:smart_wallet/domain/repositories/debt_repository.dart';
import 'package:smart_wallet/domain/repositories/account_repository.dart';
import 'package:smart_wallet/domain/repositories/transfer_repository.dart';
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

class FakeRecurringRuleRepository implements RecurringRuleRepository {
  final List<domain.RecurringRule> rules = [];

  @override
  Future<List<domain.RecurringRule>> getAllRules() async => rules;

  @override
  Future<void> addRule(domain.RecurringRule rule) async => rules.add(rule);

  @override
  Future<void> updateRule(domain.RecurringRule rule) async {
    final i = rules.indexWhere((r) => r.id == rule.id);
    if (i != -1) rules[i] = rule;
  }

  @override
  Future<void> deleteRule(String id) async =>
      rules.removeWhere((r) => r.id == id);

  @override
  Stream<List<domain.RecurringRule>> watchAllRules() => Stream.value(rules);
}

class FakeDebtRepository implements DebtRepository {
  final List<domain.Debt> debts = [];

  @override
  Future<List<domain.Debt>> getAllDebts() async => debts;

  @override
  Future<void> addDebt(domain.Debt debt) async => debts.add(debt);

  @override
  Future<void> updateDebt(domain.Debt debt) async {
    final i = debts.indexWhere((d) => d.id == debt.id);
    if (i != -1) debts[i] = debt;
  }

  @override
  Future<void> deleteDebt(String id) async =>
      debts.removeWhere((d) => d.id == id);

  @override
  Stream<List<domain.Debt>> watchAllDebts() => Stream.value(debts);
}

class FakeAccountRepository implements AccountRepository {
  final List<domain.Account> accounts;
  FakeAccountRepository([List<domain.Account>? seed]) : accounts = seed ?? [];

  @override
  Future<List<domain.Account>> getAllAccounts() async => accounts;

  @override
  Future<void> addAccount(domain.Account account) async => accounts.add(account);

  @override
  Future<void> updateAccount(domain.Account account) async {
    final i = accounts.indexWhere((a) => a.id == account.id);
    if (i != -1) accounts[i] = account;
  }

  @override
  Future<void> deleteAccount(String id) async =>
      accounts.removeWhere((a) => a.id == id);

  @override
  Stream<List<domain.Account>> watchAllAccounts() => Stream.value(accounts);

  @override
  Future<void> setDefaultAccount(String id) async {
    for (var i = 0; i < accounts.length; i++) {
      accounts[i] = accounts[i].copyWith(isDefault: accounts[i].id == id);
    }
  }
}

class FakeTransferRepository implements TransferRepository {
  final List<domain.Transfer> transfers = [];

  @override
  Future<List<domain.Transfer>> getAllTransfers() async => transfers;

  @override
  Future<void> addTransfer(domain.Transfer transfer) async =>
      transfers.add(transfer);

  @override
  Future<void> updateTransfer(domain.Transfer transfer) async {
    final i = transfers.indexWhere((t) => t.id == transfer.id);
    if (i != -1) transfers[i] = transfer;
  }

  @override
  Future<void> deleteTransfer(String id) async =>
      transfers.removeWhere((t) => t.id == id);

  @override
  Stream<List<domain.Transfer>> watchAllTransfers() => Stream.value(transfers);
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

    test('Round-trips recurring rules and debts via export + import', () async {
      final ruleRepo = FakeRecurringRuleRepository();
      final debtRepo = FakeDebtRepository();

      final rules = [
        domain.RecurringRule(
          id: 'rule_1',
          type: domain.RecurringType.expense,
          title: 'Rent, monthly',
          amount: 1200,
          categoryId: 'cat_dining',
          accountId: 'acc_cash',
          note: 'Flat "A"',
          frequency: domain.RecurrenceFrequency.monthly,
          intervalCount: 1,
          nextDueDate: DateTime(2026, 7, 1),
        ),
        domain.RecurringRule(
          id: 'rule_2',
          type: domain.RecurringType.income,
          title: 'Salary',
          amount: 5000,
          source: 'Employer',
          frequency: domain.RecurrenceFrequency.monthly,
          intervalCount: 1,
          nextDueDate: DateTime(2026, 7, 5),
          isActive: false,
        ),
      ];
      final debts = [
        domain.Debt(
          id: 'debt_1',
          name: 'Car Loan',
          type: domain.DebtType.borrowed,
          counterparty: 'Bank, Ltd.',
          principalAmount: 20000,
          paidAmount: 7500,
          interestRate: 8.5,
          emiAmount: 450,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2028, 1, 1),
          color: '#2F6F5E',
          note: 'Sedan',
        ),
      ];

      final csv = CsvExportService().buildCsvContent(
        incomes: const [],
        expenses: const [],
        categories: const [],
        recurringRules: rules,
        debts: debts,
      );

      final result = await importService.importDataFromCsvContent(
        content: csv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
        recurringRuleRepository: ruleRepo,
        debtRepository: debtRepo,
      );

      expect(result.success, isTrue);
      expect(result.recurringImported, 2);
      expect(result.debtsImported, 1);

      // Recurring rules restored with their fields intact (incl. quoted text).
      expect(ruleRepo.rules.length, 2);
      final rent = ruleRepo.rules.firstWhere((r) => r.id == 'rule_1');
      expect(rent.type, domain.RecurringType.expense);
      expect(rent.title, 'Rent, monthly');
      expect(rent.amount, 1200);
      expect(rent.categoryId, 'cat_dining');
      expect(rent.accountId, 'acc_cash');
      expect(rent.note, 'Flat "A"');
      expect(rent.frequency, domain.RecurrenceFrequency.monthly);
      expect(rent.nextDueDate, DateTime(2026, 7, 1));
      final salary = ruleRepo.rules.firstWhere((r) => r.id == 'rule_2');
      expect(salary.type, domain.RecurringType.income);
      expect(salary.source, 'Employer');
      expect(salary.isActive, isFalse);

      // Debt restored, including nullable + quoted fields.
      expect(debtRepo.debts.length, 1);
      final loan = debtRepo.debts[0];
      expect(loan.name, 'Car Loan');
      expect(loan.type, domain.DebtType.borrowed);
      expect(loan.counterparty, 'Bank, Ltd.');
      expect(loan.principalAmount, 20000);
      expect(loan.paidAmount, 7500);
      expect(loan.interestRate, 8.5);
      expect(loan.emiAmount, 450);
      expect(loan.dueDate, DateTime(2028, 1, 1));
      expect(loan.color, '#2F6F5E');
      expect(loan.note, 'Sedan');
    });

    test('Round-trips accounts and transfers via export + import', () async {
      // Seed a default account so importing the same id updates (not duplicates).
      final accountRepo = FakeAccountRepository([
        const domain.Account(
          id: 'acc_cash',
          name: 'Cash',
          type: domain.AccountType.cash,
          color: '#4F5B56',
        ),
      ]);
      final transferRepo = FakeTransferRepository();

      final accounts = [
        const domain.Account(
          id: 'acc_cash',
          name: 'Wallet Cash',
          type: domain.AccountType.cash,
          color: '#4F5B56',
          openingBalance: 100,
          sortOrder: 0,
        ),
        const domain.Account(
          id: 'acc_hdfc',
          name: 'HDFC, Savings',
          type: domain.AccountType.bank,
          color: '#2F6F5E',
          openingBalance: 5000,
          archived: true,
          sortOrder: 2,
        ),
      ];
      final transfers = [
        domain.Transfer(
          id: 'tr_1',
          fromAccountId: 'acc_cash',
          toAccountId: 'acc_hdfc',
          amount: 250,
          date: DateTime(2026, 6, 20),
          note: 'Deposit, cash',
        ),
      ];

      final csv = CsvExportService().buildCsvContent(
        incomes: const [],
        expenses: const [],
        categories: const [],
        accounts: accounts,
        transfers: transfers,
      );

      final result = await importService.importDataFromCsvContent(
        content: csv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
        accountRepository: accountRepo,
        transferRepository: transferRepo,
      );

      expect(result.success, isTrue);
      expect(result.accountsImported, 2);
      expect(result.transfersImported, 1);

      // Existing default account was updated in place, custom one added.
      expect(accountRepo.accounts.length, 2);
      final cash = accountRepo.accounts.firstWhere((a) => a.id == 'acc_cash');
      expect(cash.name, 'Wallet Cash');
      expect(cash.openingBalance, 100);
      final hdfc = accountRepo.accounts.firstWhere((a) => a.id == 'acc_hdfc');
      expect(hdfc.name, 'HDFC, Savings');
      expect(hdfc.type, domain.AccountType.bank);
      expect(hdfc.archived, isTrue);
      expect(hdfc.sortOrder, 2);

      // Transfer restored.
      expect(transferRepo.transfers.length, 1);
      final tr = transferRepo.transfers[0];
      expect(tr.fromAccountId, 'acc_cash');
      expect(tr.toAccountId, 'acc_hdfc');
      expect(tr.amount, 250);
      expect(tr.note, 'Deposit, cash');
    });

    test('Round-trips expense account + scan metadata', () async {
      final categories = [
        const domain.Category(
            id: 'cat_dining', name: 'Dining & Drinks', icon: 'rest', color: '#B56'),
      ];
      final expenses = [
        domain.Expense(
          id: 'exp_scan',
          amount: 32.5,
          categoryId: 'cat_dining',
          date: DateTime(2026, 6, 14),
          note: 'Lunch',
          source: domain.ExpenseSource.aiScan,
          aiConfidence: 0.92,
          accountId: 'acc_hdfc',
          receiptImagePath: '/data/receipts/r1.jpg',
        ),
      ];

      final csv = CsvExportService().buildCsvContent(
        incomes: const [],
        expenses: expenses,
        categories: categories,
      );

      final result = await importService.importDataFromCsvContent(
        content: csv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
      );

      expect(result.success, isTrue);
      expect(result.expensesImported, 1);

      final imported = expenseRepo.expenses.firstWhere((e) => e.id == 'exp_scan');
      expect(imported.source, domain.ExpenseSource.aiScan);
      expect(imported.aiConfidence, 0.92);
      expect(imported.accountId, 'acc_hdfc');
      // Exported as a bare filename; with no image dir it stays the basename.
      expect(imported.receiptImagePath, 'r1.jpg');
    });

    test('Re-points receipt image to the extracted images dir on import', () async {
      final categories = [
        const domain.Category(
            id: 'cat_dining', name: 'Dining & Drinks', icon: 'rest', color: '#B56'),
      ];
      final expenses = [
        domain.Expense(
          id: 'exp_r',
          amount: 10,
          categoryId: 'cat_dining',
          date: DateTime(2026, 6, 14),
          source: domain.ExpenseSource.aiScan,
          receiptImagePath: '/data/user/0/app/cache/abc123.jpg',
        ),
      ];

      final csv = CsvExportService().buildCsvContent(
        incomes: const [],
        expenses: expenses,
        categories: categories,
      );

      // The original device path is reduced to a bare filename for portability.
      expect(csv.contains('abc123.jpg'), isTrue);
      expect(csv.contains('/data/user/0/app/cache/'), isFalse);

      final result = await importService.importDataFromCsvContent(
        content: csv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
        receiptImageDir: '/docs/receipts',
      );

      expect(result.success, isTrue);
      final imported = expenseRepo.expenses.firstWhere((e) => e.id == 'exp_r');
      expect(imported.receiptImagePath, '/docs/receipts/abc123.jpg');
    });

    test('Still imports a legacy CSV without the appended columns', () async {
      // Old export format: 6-column expenses, 6-column incomes, no new sections.
      const legacyCsv = '''
--- INCOMES ---
ID,Date,Source,Amount,Recurring,Frequency
inc_1,2026-06-10,Salary,5000,Yes,Monthly

--- EXPENSES ---
ID,Date,Category,Amount,Note,Source
exp_1,2026-06-11,Dining & Drinks,45.5,"dinner",manual
''';

      final result = await importService.importDataFromCsvContent(
        content: legacyCsv,
        incomeRepository: incomeRepo,
        expenseRepository: expenseRepo,
      );

      expect(result.success, isTrue);
      expect(result.incomesImported, 1);
      expect(result.expensesImported, 1);
      // Missing appended fields default to null, not crash.
      expect(incomeRepo.incomes[0].accountId, isNull);
      expect(expenseRepo.expenses[0].accountId, isNull);
      expect(expenseRepo.expenses[0].receiptImagePath, isNull);
    });
  });
}

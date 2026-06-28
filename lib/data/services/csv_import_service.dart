import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/income_repository.dart';
import '../../domain/repositories/savings_goal_repository.dart';
import '../../domain/repositories/bill_repository.dart';
import '../../domain/repositories/recurring_rule_repository.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/transfer_repository.dart';

class CsvImportResult {
  final bool success;
  final int incomesImported;
  final int expensesImported;
  final int categoriesCreated;
  final int budgetsImported;
  final int goalsImported;
  final int billsImported;
  final int recurringImported;
  final int debtsImported;
  final int accountsImported;
  final int transfersImported;
  final String? errorMessage;

  CsvImportResult({
    required this.success,
    this.incomesImported = 0,
    this.expensesImported = 0,
    this.categoriesCreated = 0,
    this.budgetsImported = 0,
    this.goalsImported = 0,
    this.billsImported = 0,
    this.recurringImported = 0,
    this.debtsImported = 0,
    this.accountsImported = 0,
    this.transfersImported = 0,
    this.errorMessage,
  });
}

class CsvImportService {
  Future<CsvImportResult> importDataFromCsv({
    required File file,
    required IncomeRepository incomeRepository,
    required ExpenseRepository expenseRepository,
    SavingsGoalRepository? savingsGoalRepository,
    BillRepository? billRepository,
    RecurringRuleRepository? recurringRuleRepository,
    DebtRepository? debtRepository,
    AccountRepository? accountRepository,
    TransferRepository? transferRepository,
    String? receiptImageDir,
  }) async {
    try {
      final content = await file.readAsString();
      return importDataFromCsvContent(
        content: content,
        incomeRepository: incomeRepository,
        expenseRepository: expenseRepository,
        savingsGoalRepository: savingsGoalRepository,
        billRepository: billRepository,
        recurringRuleRepository: recurringRuleRepository,
        debtRepository: debtRepository,
        accountRepository: accountRepository,
        transferRepository: transferRepository,
        receiptImageDir: receiptImageDir,
      );
    } catch (e) {
      return CsvImportResult(
        success: false,
        errorMessage: 'Failed to read file: ${e.toString()}',
      );
    }
  }

  Future<CsvImportResult> importDataFromCsvContent({
    required String content,
    required IncomeRepository incomeRepository,
    required ExpenseRepository expenseRepository,
    SavingsGoalRepository? savingsGoalRepository,
    BillRepository? billRepository,
    RecurringRuleRepository? recurringRuleRepository,
    DebtRepository? debtRepository,
    AccountRepository? accountRepository,
    TransferRepository? transferRepository,
    String? receiptImageDir,
  }) async {
    try {
      final lines = content.split(RegExp(r'\r?\n'));

      int incomesImported = 0;
      int expensesImported = 0;
      int categoriesCreated = 0;
      int budgetsImported = 0;
      int goalsImported = 0;
      int billsImported = 0;
      int recurringImported = 0;
      int debtsImported = 0;
      int accountsImported = 0;
      int transfersImported = 0;

      // Fetch all existing data for lookup
      final existingCategories = await expenseRepository.getAllCategories();
      final existingIncomes = await incomeRepository.getAllIncomes();
      final existingExpenses = await expenseRepository.getAllExpenses();
      final existingGoals = await savingsGoalRepository?.getAllGoals() ?? [];
      final existingBills = await billRepository?.getAllBills() ?? [];
      final existingRules = await recurringRuleRepository?.getAllRules() ?? [];
      final existingDebts = await debtRepository?.getAllDebts() ?? [];
      final existingAccounts = await accountRepository?.getAllAccounts() ?? [];
      final existingTransfers = await transferRepository?.getAllTransfers() ?? [];

      final categoryNameMap = {
        for (var c in existingCategories) c.name.trim().toLowerCase(): c
      };
      final categoryIdMap = {for (var c in existingCategories) c.id: c};
      final incomeIdSet = {for (var inc in existingIncomes) inc.id};
      final expenseIdSet = {for (var exp in existingExpenses) exp.id};
      final goalIdSet = {for (var g in existingGoals) g.id};
      final billIdSet = {for (var b in existingBills) b.id};
      final ruleIdSet = {for (var r in existingRules) r.id};
      final debtIdSet = {for (var d in existingDebts) d.id};
      final accountIdSet = {for (var a in existingAccounts) a.id};
      final transferIdSet = {for (var t in existingTransfers) t.id};

      // 'categories' | 'accounts' | 'incomes' | 'expenses' | 'goals' | 'bills' |
      // 'recurring' | 'debts' | 'transfers'
      String currentSection = '';

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        if (line == '--- CATEGORIES ---') {
          currentSection = 'categories';
          continue;
        } else if (line == '--- INCOMES ---') {
          currentSection = 'incomes';
          continue;
        } else if (line == '--- EXPENSES ---') {
          currentSection = 'expenses';
          continue;
        } else if (line == '--- SAVINGS GOALS ---') {
          currentSection = 'goals';
          continue;
        } else if (line == '--- BILLS ---') {
          currentSection = 'bills';
          continue;
        } else if (line == '--- RECURRING RULES ---') {
          currentSection = 'recurring';
          continue;
        } else if (line == '--- DEBTS ---') {
          currentSection = 'debts';
          continue;
        } else if (line == '--- ACCOUNTS ---') {
          currentSection = 'accounts';
          continue;
        } else if (line == '--- TRANSFERS ---') {
          currentSection = 'transfers';
          continue;
        }

        // Skip headers
        if (line.startsWith('ID,Date,Source,Amount,Recurring,Frequency') ||
            line.startsWith('ID,Date,Category,Amount,Note,Source') ||
            line.startsWith('ID,Name,Icon,Color,BudgetLimit') ||
            line.startsWith('ID,Name,TargetAmount,CurrentAmount,TargetDate,Color') ||
            line.startsWith('ID,Name,Amount,DueDate,IsPaid,Frequency,Category') ||
            line.startsWith('ID,Type,Title,Amount,CategoryId,Source,AccountId') ||
            line.startsWith('ID,Name,Type,Counterparty,PrincipalAmount') ||
            line.startsWith('ID,Name,Type,Color,OpeningBalance') ||
            line.startsWith('ID,FromAccountId,ToAccountId,Amount')) {
          continue;
        }

        // Parse CSV row
        final row = _parseCsvLine(line);
        if (row.isEmpty) continue;

        if (currentSection == 'categories') {
          if (row.length < 4) continue;

          final id = row[0].trim();
          final name = row[1].trim();
          final icon = row[2].trim();
          final color = row[3].trim();
          final budgetStr = row.length > 4 ? row[4].trim() : '';
          final rollover = row.length > 5 && row[5].trim().toLowerCase() == 'yes';
          if (id.isEmpty || name.isEmpty) continue;

          final budgetLimit =
              budgetStr.isNotEmpty ? double.tryParse(budgetStr) : null;
          final hasBudget = budgetLimit != null;

          final existing = categoryIdMap[id];
          if (existing != null) {
            final updated = existing.copyWith(
              name: name,
              icon: icon.isNotEmpty ? icon : existing.icon,
              color: color.isNotEmpty ? color : existing.color,
              budgetLimit: budgetLimit,
              clearBudgetLimit: !hasBudget,
              rolloverEnabled: rollover,
            );
            await expenseRepository.updateCategory(updated);
            categoryIdMap[id] = updated;
            categoryNameMap[name.toLowerCase()] = updated;
          } else {
            final newCategory = domain.Category(
              id: id,
              name: name,
              icon: icon.isNotEmpty ? icon : 'category',
              color: color.isNotEmpty ? color : '#4A90E2',
              isDefault: false,
              budgetLimit: budgetLimit,
              rolloverEnabled: rollover,
            );
            await expenseRepository.addCategory(newCategory);
            categoryIdMap[id] = newCategory;
            categoryNameMap[name.toLowerCase()] = newCategory;
            categoriesCreated++;
          }
          if (hasBudget) budgetsImported++;
        } else if (currentSection == 'incomes') {
          if (row.length < 6) continue;

          final id = row[0].trim();
          final dateStr = row[1].trim();
          final source = row[2].trim();
          final amountStr = row[3].trim();
          final isRecurringStr = row[4].trim();
          final frequencyStr = row[5].trim();

          final accountId = row.length > 6 ? row[6].trim() : '';
          final origCurrency = row.length > 7 ? row[7].trim() : '';
          final origAmount = row.length > 8 ? row[8].trim() : '';

          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          final amount = double.tryParse(amountStr) ?? 0.0;
          final isRecurring = isRecurringStr.toLowerCase() == 'yes';

          final frequency = domain.IncomeFrequency.values.firstWhere(
            (f) => f.displayName.toLowerCase() == frequencyStr.toLowerCase() || f.name.toLowerCase() == frequencyStr.toLowerCase(),
            orElse: () => domain.IncomeFrequency.oneOff,
          );

          final income = domain.Income(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            date: date,
            source: source.isNotEmpty ? source : 'Imported Income',
            amount: amount,
            isRecurring: isRecurring,
            frequency: frequency,
            accountId: accountId.isNotEmpty ? accountId : null,
            originalCurrency: origCurrency.isNotEmpty ? origCurrency : null,
            originalAmount: origAmount.isNotEmpty ? double.tryParse(origAmount) : null,
            isSynced: false,
          );

          if (incomeIdSet.contains(income.id)) {
            await incomeRepository.updateIncome(income);
          } else {
            await incomeRepository.addIncome(income);
            incomeIdSet.add(income.id);
          }
          incomesImported++;

        } else if (currentSection == 'expenses') {
          if (row.length < 6) continue;

          final id = row[0].trim();
          final dateStr = row[1].trim();
          final categoryName = row[2].trim();
          final amountStr = row[3].trim();
          final note = row[4].trim();
          final sourceStr = row[5].trim();
          final accountId = row.length > 6 ? row[6].trim() : '';
          final receiptName = row.length > 7 ? row[7].trim() : '';
          // Re-point the receipt filename at the folder its image was extracted
          // to (ZIP backup). Without an image dir (plain CSV) keep the bare name.
          final receiptPath = receiptName.isEmpty
              ? ''
              : (receiptImageDir != null ? '$receiptImageDir/$receiptName' : receiptName);
          final aiConfidenceStr = row.length > 8 ? row[8].trim() : '';
          final origCurrency = row.length > 9 ? row[9].trim() : '';
          final origAmount = row.length > 10 ? row[10].trim() : '';

          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          final amount = double.tryParse(amountStr) ?? 0.0;

          final cleanedCategoryName = categoryName.isNotEmpty ? categoryName : 'Uncategorized';
          final categoryKey = cleanedCategoryName.toLowerCase();

          String categoryId;
          if (categoryNameMap.containsKey(categoryKey)) {
            categoryId = categoryNameMap[categoryKey]!.id;
          } else {
            // Create new category
            categoryId = 'cat_${cleanedCategoryName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
            if (categoryId.length > 50) {
              categoryId = categoryId.substring(0, 50);
            }
            // Ensure unique category ID
            if (categoryIdMap.containsKey(categoryId)) {
              categoryId = 'cat_${const Uuid().v4().substring(0, 8)}';
            }
            final newCategory = domain.Category(
              id: categoryId,
              name: cleanedCategoryName,
              icon: 'category',
              color: '#4A90E2',
              isDefault: false,
            );
            await expenseRepository.addCategory(newCategory);
            categoryNameMap[categoryKey] = newCategory;
            categoryIdMap[categoryId] = newCategory;
            categoriesCreated++;
          }

          final source = domain.ExpenseSource.values.firstWhere(
            (s) => s.name.toLowerCase() == sourceStr.toLowerCase(),
            orElse: () => domain.ExpenseSource.manual,
          );

          final expense = domain.Expense(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            date: date,
            categoryId: categoryId,
            amount: amount,
            note: note,
            source: source,
            accountId: accountId.isNotEmpty ? accountId : null,
            receiptImagePath: receiptPath.isNotEmpty ? receiptPath : null,
            aiConfidence: aiConfidenceStr.isNotEmpty ? double.tryParse(aiConfidenceStr) : null,
            originalCurrency: origCurrency.isNotEmpty ? origCurrency : null,
            originalAmount: origAmount.isNotEmpty ? double.tryParse(origAmount) : null,
            isSynced: false,
          );

          if (expenseIdSet.contains(expense.id)) {
            await expenseRepository.updateExpense(expense);
          } else {
            await expenseRepository.addExpense(expense);
            expenseIdSet.add(expense.id);
          }
          expensesImported++;
        } else if (currentSection == 'goals') {
          if (savingsGoalRepository == null) continue;
          if (row.length < 6) continue;

          final id = row[0].trim();
          final name = row[1].trim();
          final targetStr = row[2].trim();
          final currentStr = row[3].trim();
          final dateStr = row[4].trim();
          final color = row[5].trim();

          final goal = domain.SavingsGoal(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            name: name.isNotEmpty ? name : 'Imported Goal',
            targetAmount: double.tryParse(targetStr) ?? 0.0,
            currentAmount: double.tryParse(currentStr) ?? 0.0,
            targetDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
            color: color.isNotEmpty ? color : '#4A90E2',
          );

          if (goalIdSet.contains(goal.id)) {
            await savingsGoalRepository.updateGoal(goal);
          } else {
            await savingsGoalRepository.addGoal(goal);
            goalIdSet.add(goal.id);
          }
          goalsImported++;
        } else if (currentSection == 'bills') {
          if (billRepository == null) continue;
          if (row.length < 6) continue;

          final id = row[0].trim();
          final name = row[1].trim();
          final amountStr = row[2].trim();
          final dueStr = row[3].trim();
          final isPaidStr = row[4].trim();
          final frequencyStr = row[5].trim();
          final categoryName = row.length > 6 ? row[6].trim() : '';

          final frequency = domain.BillFrequency.values.firstWhere(
            (f) => f.displayName.toLowerCase() == frequencyStr.toLowerCase() || f.name.toLowerCase() == frequencyStr.toLowerCase(),
            orElse: () => domain.BillFrequency.oneOff,
          );

          String? categoryId;
          if (categoryName.isNotEmpty) {
            final match = categoryNameMap[categoryName.toLowerCase()];
            categoryId = match?.id;
          }

          final bill = domain.Bill(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            name: name.isNotEmpty ? name : 'Imported Bill',
            amount: double.tryParse(amountStr) ?? 0.0,
            dueDate: DateTime.tryParse(dueStr) ?? DateTime.now(),
            isPaid: isPaidStr.toLowerCase() == 'yes',
            frequency: frequency,
            categoryId: categoryId,
          );

          if (billIdSet.contains(bill.id)) {
            await billRepository.updateBill(bill);
          } else {
            await billRepository.addBill(bill);
            billIdSet.add(bill.id);
          }
          billsImported++;
        } else if (currentSection == 'recurring') {
          if (recurringRuleRepository == null) continue;
          if (row.length < 11) continue;

          final id = row[0].trim();
          final type = domain.RecurringType.fromJson(row[1].trim());
          final title = row[2].trim();
          final amount = double.tryParse(row[3].trim()) ?? 0.0;
          final categoryId = row[4].trim();
          final source = row[5].trim();
          final accountId = row[6].trim();
          final note = row[7].trim();
          final frequency = domain.RecurrenceFrequency.fromJson(row[8].trim());
          final intervalCount = int.tryParse(row[9].trim()) ?? 1;
          final nextDue = DateTime.tryParse(row[10].trim()) ?? DateTime.now();
          final endDate = row.length > 11 && row[11].trim().isNotEmpty
              ? DateTime.tryParse(row[11].trim())
              : null;
          final lastPosted = row.length > 12 && row[12].trim().isNotEmpty
              ? DateTime.tryParse(row[12].trim())
              : null;
          final isActive =
              row.length > 13 ? row[13].trim().toLowerCase() == 'yes' : true;

          final rule = domain.RecurringRule(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            type: type,
            title: title.isNotEmpty ? title : 'Imported Rule',
            amount: amount,
            categoryId: categoryId.isNotEmpty ? categoryId : null,
            source: source.isNotEmpty ? source : null,
            accountId: accountId.isNotEmpty ? accountId : null,
            note: note.isNotEmpty ? note : null,
            frequency: frequency,
            intervalCount: intervalCount < 1 ? 1 : intervalCount,
            nextDueDate: nextDue,
            endDate: endDate,
            lastPostedDate: lastPosted,
            isActive: isActive,
          );

          if (ruleIdSet.contains(rule.id)) {
            await recurringRuleRepository.updateRule(rule);
          } else {
            await recurringRuleRepository.addRule(rule);
            ruleIdSet.add(rule.id);
          }
          recurringImported++;
        } else if (currentSection == 'debts') {
          if (debtRepository == null) continue;
          if (row.length < 11) continue;

          final id = row[0].trim();
          final name = row[1].trim();
          final type = domain.DebtType.fromJson(row[2].trim());
          final counterparty = row[3].trim();
          final principal = double.tryParse(row[4].trim()) ?? 0.0;
          final paid = double.tryParse(row[5].trim()) ?? 0.0;
          final interest = row[6].trim().isNotEmpty ? double.tryParse(row[6].trim()) : null;
          final emi = row[7].trim().isNotEmpty ? double.tryParse(row[7].trim()) : null;
          final startDate = DateTime.tryParse(row[8].trim()) ?? DateTime.now();
          final dueDate = row.length > 9 && row[9].trim().isNotEmpty
              ? DateTime.tryParse(row[9].trim())
              : null;
          final color = row.length > 10 && row[10].trim().isNotEmpty
              ? row[10].trim()
              : '#4A90E2';
          final isClosed =
              row.length > 11 ? row[11].trim().toLowerCase() == 'yes' : false;
          final note = row.length > 12 ? row[12].trim() : '';

          final debt = domain.Debt(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            name: name.isNotEmpty ? name : 'Imported Debt',
            type: type,
            counterparty: counterparty.isNotEmpty ? counterparty : null,
            principalAmount: principal,
            paidAmount: paid,
            interestRate: interest,
            emiAmount: emi,
            startDate: startDate,
            dueDate: dueDate,
            color: color,
            isClosed: isClosed,
            note: note.isNotEmpty ? note : null,
          );

          if (debtIdSet.contains(debt.id)) {
            await debtRepository.updateDebt(debt);
          } else {
            await debtRepository.addDebt(debt);
            debtIdSet.add(debt.id);
          }
          debtsImported++;
        } else if (currentSection == 'accounts') {
          if (accountRepository == null) continue;
          if (row.length < 4) continue;

          final id = row[0].trim();
          final name = row[1].trim();
          final type = domain.AccountType.fromJson(row[2].trim());
          final color = row[3].trim();
          final openingStr = row.length > 4 ? row[4].trim() : '';
          final archived =
              row.length > 5 && row[5].trim().toLowerCase() == 'yes';
          final sortOrder = row.length > 6 ? (int.tryParse(row[6].trim()) ?? 0) : 0;
          if (id.isEmpty) continue;

          final account = domain.Account(
            id: id,
            name: name.isNotEmpty ? name : 'Imported Account',
            type: type,
            color: color.isNotEmpty ? color : '#4F5B56',
            openingBalance: double.tryParse(openingStr) ?? 0.0,
            archived: archived,
            sortOrder: sortOrder,
          );

          if (accountIdSet.contains(account.id)) {
            await accountRepository.updateAccount(account);
          } else {
            await accountRepository.addAccount(account);
            accountIdSet.add(account.id);
          }
          accountsImported++;
        } else if (currentSection == 'transfers') {
          if (transferRepository == null) continue;
          if (row.length < 5) continue;

          final id = row[0].trim();
          final fromId = row[1].trim();
          final toId = row[2].trim();
          final amount = double.tryParse(row[3].trim()) ?? 0.0;
          final date = DateTime.tryParse(row[4].trim()) ?? DateTime.now();
          final note = row.length > 5 ? row[5].trim() : '';
          if (fromId.isEmpty || toId.isEmpty) continue;

          final transfer = domain.Transfer(
            id: id.isNotEmpty ? id : const Uuid().v4(),
            fromAccountId: fromId,
            toAccountId: toId,
            amount: amount,
            date: date,
            note: note.isNotEmpty ? note : null,
          );

          if (transferIdSet.contains(transfer.id)) {
            await transferRepository.updateTransfer(transfer);
          } else {
            await transferRepository.addTransfer(transfer);
            transferIdSet.add(transfer.id);
          }
          transfersImported++;
        }
      }

      return CsvImportResult(
        success: true,
        incomesImported: incomesImported,
        expensesImported: expensesImported,
        categoriesCreated: categoriesCreated,
        budgetsImported: budgetsImported,
        goalsImported: goalsImported,
        billsImported: billsImported,
        recurringImported: recurringImported,
        debtsImported: debtsImported,
        accountsImported: accountsImported,
        transfersImported: transfersImported,
      );
    } catch (e) {
      return CsvImportResult(
        success: false,
        errorMessage: 'Import failed: ${e.toString()}',
      );
    }
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(currentField.toString());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }
    result.add(currentField.toString());
    return result;
  }
}

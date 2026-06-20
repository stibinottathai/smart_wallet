import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/income_repository.dart';

class CsvImportResult {
  final bool success;
  final int incomesImported;
  final int expensesImported;
  final int categoriesCreated;
  final String? errorMessage;

  CsvImportResult({
    required this.success,
    this.incomesImported = 0,
    this.expensesImported = 0,
    this.categoriesCreated = 0,
    this.errorMessage,
  });
}

class CsvImportService {
  Future<CsvImportResult> importDataFromCsv({
    required File file,
    required IncomeRepository incomeRepository,
    required ExpenseRepository expenseRepository,
  }) async {
    try {
      final content = await file.readAsString();
      return importDataFromCsvContent(
        content: content,
        incomeRepository: incomeRepository,
        expenseRepository: expenseRepository,
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
  }) async {
    try {
      final lines = content.split(RegExp(r'\r?\n'));
      
      int incomesImported = 0;
      int expensesImported = 0;
      int categoriesCreated = 0;

      // Fetch all existing data for lookup
      final existingCategories = await expenseRepository.getAllCategories();
      final existingIncomes = await incomeRepository.getAllIncomes();
      final existingExpenses = await expenseRepository.getAllExpenses();

      final categoryNameMap = {
        for (var c in existingCategories) c.name.trim().toLowerCase(): c
      };
      final incomeIdSet = {for (var inc in existingIncomes) inc.id};
      final expenseIdSet = {for (var exp in existingExpenses) exp.id};

      String currentSection = ''; // 'incomes' or 'expenses'
      
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        if (line == '--- INCOMES ---') {
          currentSection = 'incomes';
          continue;
        } else if (line == '--- EXPENSES ---') {
          currentSection = 'expenses';
          continue;
        }

        // Skip headers
        if (line.startsWith('ID,Date,Source,Amount,Recurring,Frequency') ||
            line.startsWith('ID,Date,Category,Amount,Note,Source')) {
          continue;
        }

        // Parse CSV row
        final row = _parseCsvLine(line);
        if (row.isEmpty) continue;

        if (currentSection == 'incomes') {
          if (row.length < 6) continue;
          
          final id = row[0].trim();
          final dateStr = row[1].trim();
          final source = row[2].trim();
          final amountStr = row[3].trim();
          final isRecurringStr = row[4].trim();
          final frequencyStr = row[5].trim();

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
            if (existingCategories.any((c) => c.id == categoryId)) {
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
            isSynced: false,
          );

          if (expenseIdSet.contains(expense.id)) {
            await expenseRepository.updateExpense(expense);
          } else {
            await expenseRepository.addExpense(expense);
            expenseIdSet.add(expense.id);
          }
          expensesImported++;
        }
      }

      return CsvImportResult(
        success: true,
        incomesImported: incomesImported,
        expensesImported: expensesImported,
        categoriesCreated: categoriesCreated,
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

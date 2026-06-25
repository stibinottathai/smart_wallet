import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/models.dart' as domain;

class CsvExportService {
  String buildCsvContent({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    List<domain.SavingsGoal> goals = const [],
    List<domain.Bill> bills = const [],
  }) {
    final StringBuffer buffer = StringBuffer();

    // Build category map (id -> name) for human-readable references.
    final categoryMap = {for (var c in categories) c.id: c.name};

    // Export Categories (with monthly budget limits). Listed first so that an
    // import can restore categories and their budgets before linking expenses
    // and bills back to them.
    buffer.writeln('--- CATEGORIES ---');
    buffer.writeln('ID,Name,Icon,Color,BudgetLimit');
    for (final cat in categories) {
      final budget = cat.budgetLimit != null ? '${cat.budgetLimit}' : '';
      buffer.writeln(
          '${cat.id},"${cat.name}",${cat.icon},${cat.color},$budget');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Incomes
    buffer.writeln('--- INCOMES ---');
    buffer.writeln('ID,Date,Source,Amount,Recurring,Frequency');
    for (final inc in incomes) {
      buffer.writeln('${inc.id},${inc.date.toIso8601String().substring(0, 10)},"${inc.source}",${inc.amount},${inc.isRecurring ? "Yes" : "No"},${inc.frequency.displayName}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Expenses
    buffer.writeln('--- EXPENSES ---');
    buffer.writeln('ID,Date,Category,Amount,Note,Source');
    for (final exp in expenses) {
      final catName = categoryMap[exp.categoryId] ?? 'Uncategorized';
      final note = exp.note?.replaceAll('"', '""') ?? '';
      buffer.writeln('${exp.id},${exp.date.toIso8601String().substring(0, 10)},"$catName",${exp.amount},"$note",${exp.source.name}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Savings Goals
    buffer.writeln('--- SAVINGS GOALS ---');
    buffer.writeln('ID,Name,TargetAmount,CurrentAmount,TargetDate,Color');
    for (final goal in goals) {
      buffer.writeln(
          '${goal.id},"${goal.name}",${goal.targetAmount},${goal.currentAmount},${goal.targetDate.toIso8601String().substring(0, 10)},${goal.color}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Upcoming Bills & Subscriptions
    buffer.writeln('--- BILLS ---');
    buffer.writeln('ID,Name,Amount,DueDate,IsPaid,Frequency,Category');
    for (final bill in bills) {
      final catName = bill.categoryId != null
          ? (categoryMap[bill.categoryId] ?? '')
          : '';
      buffer.writeln(
          '${bill.id},"${bill.name}",${bill.amount},${bill.dueDate.toIso8601String().substring(0, 10)},${bill.isPaid ? "Yes" : "No"},${bill.frequency.displayName},"$catName"');
    }

    return buffer.toString();
  }

  Future<void> exportDataToCsv({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    List<domain.SavingsGoal> goals = const [],
    List<domain.Bill> bills = const [],
  }) async {
    final csvContent = buildCsvContent(
      incomes: incomes,
      expenses: expenses,
      categories: categories,
      goals: goals,
      bills: bills,
    );

    // Save to temp file and share. The system share sheet lets the user pick
    // any destination, including "Save to Drive" / Google Drive.
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/smart_wallet_export.csv');
    await file.writeAsString(csvContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Smart Wallet Data Export',
      ),
    );
  }
}

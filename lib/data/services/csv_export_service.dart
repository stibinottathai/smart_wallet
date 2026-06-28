import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/models.dart' as domain;

class CsvExportService {
  /// Wraps a text field in quotes and escapes embedded quotes so values
  /// containing commas/quotes survive a round-trip.
  String _q(String? value) => '"${(value ?? '').replaceAll('"', '""')}"';

  /// Formats a nullable date as an ISO date (yyyy-MM-dd), or '' when null.
  String _date(DateTime? d) => d == null ? '' : d.toIso8601String().substring(0, 10);

  /// Formats a nullable number, or '' when null.
  String _num(num? v) => v == null ? '' : '$v';

  /// The last path segment (handles `/` and `\`). Receipt paths are exported as
  /// a bare filename so they match the `images/<filename>` entries in a ZIP
  /// backup and can be re-pointed on import.
  String _basename(String? path) =>
      (path == null || path.isEmpty) ? '' : path.split(RegExp(r'[\\/]')).last;

  String buildCsvContent({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    List<domain.SavingsGoal> goals = const [],
    List<domain.Bill> bills = const [],
    List<domain.RecurringRule> recurringRules = const [],
    List<domain.Debt> debts = const [],
    List<domain.Account> accounts = const [],
    List<domain.Transfer> transfers = const [],
  }) {
    final StringBuffer buffer = StringBuffer();

    // Build category map (id -> name) for human-readable references.
    final categoryMap = {for (var c in categories) c.id: c.name};

    // Export Categories (with monthly budget limits). Listed first so that an
    // import can restore categories and their budgets before linking expenses
    // and bills back to them.
    buffer.writeln('--- CATEGORIES ---');
    buffer.writeln('ID,Name,Icon,Color,BudgetLimit,Rollover');
    for (final cat in categories) {
      final budget = cat.budgetLimit != null ? '${cat.budgetLimit}' : '';
      buffer.writeln(
          '${cat.id},${_q(cat.name)},${cat.icon},${cat.color},$budget,${cat.rolloverEnabled ? "Yes" : "No"}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Accounts (wallets / money sources). Listed early so transactions
    // and transfers can be re-linked to them on import.
    buffer.writeln('--- ACCOUNTS ---');
    buffer.writeln('ID,Name,Type,Color,OpeningBalance,Archived,SortOrder');
    for (final acc in accounts) {
      buffer.writeln(
          '${acc.id},${_q(acc.name)},${acc.type.name},${acc.color},${acc.openingBalance},${acc.archived ? "Yes" : "No"},${acc.sortOrder}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Incomes. AccountId + original-currency columns are appended after
    // the legacy columns so older exports remain importable.
    buffer.writeln('--- INCOMES ---');
    buffer.writeln('ID,Date,Source,Amount,Recurring,Frequency,AccountId,OriginalCurrency,OriginalAmount');
    for (final inc in incomes) {
      buffer.writeln('${inc.id},${inc.date.toIso8601String().substring(0, 10)},${_q(inc.source)},${inc.amount},${inc.isRecurring ? "Yes" : "No"},${inc.frequency.displayName},${_q(inc.accountId)},${_q(inc.originalCurrency)},${_num(inc.originalAmount)}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Expenses. AccountId, receipt-scan metadata (image path, AI
    // confidence) and original-currency columns are appended so scanned
    // expenses keep their classification and older exports still import.
    buffer.writeln('--- EXPENSES ---');
    buffer.writeln('ID,Date,Category,Amount,Note,Source,AccountId,ReceiptImagePath,AiConfidence,OriginalCurrency,OriginalAmount');
    for (final exp in expenses) {
      final catName = categoryMap[exp.categoryId] ?? 'Uncategorized';
      buffer.writeln('${exp.id},${exp.date.toIso8601String().substring(0, 10)},${_q(catName)},${exp.amount},${_q(exp.note)},${exp.source.name},${_q(exp.accountId)},${_q(_basename(exp.receiptImagePath))},${_num(exp.aiConfidence)},${_q(exp.originalCurrency)},${_num(exp.originalAmount)}');
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

    buffer.writeln();
    buffer.writeln();

    // Export Recurring Rules (auto-posting expense/income templates). CategoryId
    // and AccountId are kept as raw ids — categories are imported first (same
    // ids preserved) and the default accounts keep stable ids across reinstall.
    buffer.writeln('--- RECURRING RULES ---');
    buffer.writeln(
        'ID,Type,Title,Amount,CategoryId,Source,AccountId,Note,Frequency,IntervalCount,NextDueDate,EndDate,LastPostedDate,IsActive');
    for (final r in recurringRules) {
      buffer.writeln(
          '${r.id},${r.type.name},${_q(r.title)},${r.amount},${_q(r.categoryId)},${_q(r.source)},${_q(r.accountId)},${_q(r.note)},${r.frequency.name},${r.intervalCount},${_date(r.nextDueDate)},${_date(r.endDate)},${_date(r.lastPostedDate)},${r.isActive ? "Yes" : "No"}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Debts & Loans (money borrowed or lent, with repayment progress).
    buffer.writeln('--- DEBTS ---');
    buffer.writeln(
        'ID,Name,Type,Counterparty,PrincipalAmount,PaidAmount,InterestRate,EmiAmount,StartDate,DueDate,Color,IsClosed,Note');
    for (final d in debts) {
      buffer.writeln(
          '${d.id},${_q(d.name)},${d.type.name},${_q(d.counterparty)},${d.principalAmount},${d.paidAmount},${_num(d.interestRate)},${_num(d.emiAmount)},${_date(d.startDate)},${_date(d.dueDate)},${d.color},${d.isClosed ? "Yes" : "No"},${_q(d.note)}');
    }

    buffer.writeln();
    buffer.writeln();

    // Export Transfers (money moved between accounts). Listed last since they
    // reference accounts defined earlier in the file.
    buffer.writeln('--- TRANSFERS ---');
    buffer.writeln('ID,FromAccountId,ToAccountId,Amount,Date,Note');
    for (final t in transfers) {
      buffer.writeln(
          '${t.id},${t.fromAccountId},${t.toAccountId},${t.amount},${_date(t.date)},${_q(t.note)}');
    }

    return buffer.toString();
  }

  Future<void> exportDataToCsv({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    List<domain.SavingsGoal> goals = const [],
    List<domain.Bill> bills = const [],
    List<domain.RecurringRule> recurringRules = const [],
    List<domain.Debt> debts = const [],
    List<domain.Account> accounts = const [],
    List<domain.Transfer> transfers = const [],
  }) async {
    final csvContent = buildCsvContent(
      incomes: incomes,
      expenses: expenses,
      categories: categories,
      goals: goals,
      bills: bills,
      recurringRules: recurringRules,
      debts: debts,
      accounts: accounts,
      transfers: transfers,
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

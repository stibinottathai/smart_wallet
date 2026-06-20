import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/models.dart' as domain;

class CsvExportService {
  String buildCsvContent({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
  }) {
    final StringBuffer buffer = StringBuffer();

    // Export Incomes
    buffer.writeln('--- INCOMES ---');
    buffer.writeln('ID,Date,Source,Amount,Recurring,Frequency');
    for (final inc in incomes) {
      buffer.writeln('${inc.id},${inc.date.toIso8601String().substring(0, 10)},"${inc.source}",${inc.amount},${inc.isRecurring ? "Yes" : "No"},${inc.frequency.displayName}');
    }

    buffer.writeln();
    buffer.writeln();

    // Build category map
    final categoryMap = {for (var c in categories) c.id: c.name};

    // Export Expenses
    buffer.writeln('--- EXPENSES ---');
    buffer.writeln('ID,Date,Category,Amount,Note,Source');
    for (final exp in expenses) {
      final catName = categoryMap[exp.categoryId] ?? 'Uncategorized';
      final note = exp.note?.replaceAll('"', '""') ?? '';
      buffer.writeln('${exp.id},${exp.date.toIso8601String().substring(0, 10)},"$catName",${exp.amount},"$note",${exp.source.name}');
    }

    return buffer.toString();
  }

  Future<void> exportDataToCsv({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
  }) async {
    final csvContent = buildCsvContent(
      incomes: incomes,
      expenses: expenses,
      categories: categories,
    );

    // Save to temp file and share
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

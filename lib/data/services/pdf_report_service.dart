import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import '../../domain/models/models.dart' as domain;
import '../repositories/expense_repository_impl.dart';
import '../repositories/income_repository_impl.dart';
import 'database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Currency label helper
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the best currency label for use inside a PDF rendered with a
/// Latin-script TrueType font (Roboto).
///
/// Roboto covers the full Latin-1 block plus many Unicode currency signs:
///   ✅ $ £ € ¥ ₹  — rendered correctly as Unicode symbols
///   ❌ Arabic-script symbols (د.إ  ﷼  د.ك  د.ب) — replaced with the
///      ISO 4217 code so the PDF doesn't show garbled boxes.
String _pdfCurrencyLabel(String code) {
  const arabicScriptCodes = {'AED', 'SAR', 'QAR', 'KWD', 'OMR', 'BHD'};
  if (arabicScriptCodes.contains(code)) {
    // Return the 3-letter ISO code + non-breaking space — clean and unambiguous
    return '$code ';
  }
  // For all other currencies the Unicode symbol is within Roboto's coverage
  return currencySymbol(code);
}

class PdfReportService {
  final AppDatabase _db;

  /// The currency code is injected by the Riverpod provider which watches
  /// [currencyCodeProvider], so this field is always the currently selected
  /// currency — no stale-value risk.
  final String currencyCode;

  PdfReportService(this._db, {this.currencyCode = 'AED'});

  Future<File> generateReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final expenseRepo = ExpenseRepositoryImpl(_db);
    final incomeRepo = IncomeRepositoryImpl(_db);

    final adjustedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final adjustedStart = DateTime(start.year, start.month, start.day);

    final expenses = await expenseRepo.getExpensesBetween(adjustedStart, adjustedEnd);
    final incomes = await incomeRepo.getIncomesBetween(adjustedStart, adjustedEnd);
    final dbCategories = await _db.select(_db.categories).get();
    final catMap = {for (final c in dbCategories) c.id: _toDomainCategory(c)};

    final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
    final totalExpense = expenses.fold(0.0, (s, e) => s + e.amount);
    final netBalance = totalIncome - totalExpense;

    // Load Roboto TTF from assets (copied from Flutter's material_fonts cache).
    // Roboto covers all currency symbols used by this app EXCEPT Arabic-script
    // ones (AED, SAR, etc.) — those fall back to the ISO code via
    // _pdfCurrencyLabel(). Using rootBundle ensures the font is bundled in the
    // app and never causes a "head table not found" error.
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final baseFont = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(boldFontData);

    // Resolve the label once — used throughout the document
    final sym = _pdfCurrencyLabel(currencyCode);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'SmartWallet',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          _buildHeader(start, adjustedEnd),
          pw.SizedBox(height: 24),
          _buildSummary(totalIncome, totalExpense, netBalance, incomes.length, expenses.length, sym),
          pw.SizedBox(height: 32),
          if (incomes.isNotEmpty) ...[
            _buildSectionTitle('Income Entries'),
            pw.SizedBox(height: 8),
            _buildIncomeTable(incomes, sym),
            pw.SizedBox(height: 24),
          ],
          if (expenses.isNotEmpty) ...[
            _buildSectionTitle('Expense Entries'),
            pw.SizedBox(height: 8),
            _buildExpenseTable(expenses, catMap, sym),
            pw.SizedBox(height: 24),
          ],
          if (expenses.isNotEmpty) ...[
            _buildSectionTitle('Category Breakdown'),
            pw.SizedBox(height: 8),
            _buildCategoryTable(expenses, catMap, totalExpense, sym),
          ],
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/smart_wallet_report_$dateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> shareReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final file = await generateReport(start: start, end: end);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'SmartWallet Report (${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)})',
      ),
    );
  }

  Future<void> openReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final file = await generateReport(start: start, end: end);
    await OpenFile.open(file.path);
  }

  domain.Category _toDomainCategory(Category dbCat) {
    return domain.Category(
      id: dbCat.id,
      name: dbCat.name,
      icon: dbCat.icon,
      color: dbCat.color,
      isDefault: dbCat.isDefault,
    );
  }

  pw.Widget _buildHeader(DateTime start, DateTime end) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Financial Report',
          style: pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generated ${DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
        ),
        pw.Divider(height: 24, thickness: 1, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _buildSummary(
    double income,
    double expense,
    double net,
    int incCount,
    int expCount,
    String sym,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _summaryItem('Total Income', '$sym${income.toStringAsFixed(2)}', PdfColors.green700, '$incCount entries'),
          _summaryItem('Total Expenses', '$sym${expense.toStringAsFixed(2)}', PdfColors.red700, '$expCount entries'),
          _summaryItem(
            'Net Balance',
            '$sym${net.toStringAsFixed(2)}',
            net >= 0 ? PdfColors.green700 : PdfColors.red700,
            net >= 0 ? 'Surplus' : 'Deficit',
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value, PdfColor color, String sub) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 2),
        pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green800,
      ),
    );
  }

  pw.Widget _buildIncomeTable(List<domain.Income> incomes, String sym) {
    final headers = ['Source', 'Date', 'Recurring', 'Amount'];
    final rows = incomes.map((i) => [
      i.source,
      DateFormat('MMM d, yyyy').format(i.date),
      i.isRecurring ? i.frequency.displayName : '-',
      '$sym${i.amount.toStringAsFixed(2)}',
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
      headers: headers,
      data: rows,
    );
  }

  pw.Widget _buildExpenseTable(
    List<domain.Expense> expenses,
    Map<String, domain.Category> catMap,
    String sym,
  ) {
    final headers = ['Category', 'Date', 'Note', 'Amount'];
    final rows = expenses.map((e) {
      final cat = catMap[e.categoryId];
      return [
        cat?.name ?? 'Uncategorized',
        DateFormat('MMM d, yyyy').format(e.date),
        e.note ?? '-',
        '$sym${e.amount.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      headers: headers,
      data: rows,
    );
  }

  pw.Widget _buildCategoryTable(
    List<domain.Expense> expenses,
    Map<String, domain.Category> catMap,
    double total,
    String sym,
  ) {
    final spend = <String, double>{};
    for (final e in expenses) {
      spend[e.categoryId] = (spend[e.categoryId] ?? 0) + e.amount;
    }
    final sorted = spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final headers = ['Category', 'Amount', '%'];
    final rows = sorted.map((e) {
      final cat = catMap[e.key];
      final pct = total > 0 ? (e.value / total * 100) : 0.0;
      return [
        cat?.name ?? 'Uncategorized',
        '$sym${e.value.toStringAsFixed(2)}',
        '${pct.toStringAsFixed(1)}%',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      headers: headers,
      data: rows,
    );
  }
}

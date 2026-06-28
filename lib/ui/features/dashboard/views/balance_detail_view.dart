import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/balance_header_card.dart';
import 'package:smart_wallet/ui/features/entries/views/transaction_detail_view.dart';

/// Opened by tapping the balance card on the dashboard. Shows a swipeable
/// carousel of summary cards (Balance → Expense → Income) for a selected month,
/// lets the user step through previous months with the ‹ › arrows, and lists
/// that month's transactions below.
class BalanceDetailView extends ConsumerStatefulWidget {
  /// The month to open on. Defaults to the current month.
  final DateTime? initialMonth;

  const BalanceDetailView({super.key, this.initialMonth});

  @override
  ConsumerState<BalanceDetailView> createState() => _BalanceDetailViewState();
}

class _BalanceDetailViewState extends ConsumerState<BalanceDetailView> {
  late DateTime _month; // first day of the selected month
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMonth ?? DateTime.now();
    _month = DateTime(m.year, m.month);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Opens a calendar so the user can jump straight to any month/date instead of
  /// stepping with the arrows. The selected date's month becomes the active one.
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _month.isAfter(now) ? now : _month;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month + 1, 0), // end of current month
      helpText: 'Select a date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));
    final incomes = ref.watch(allIncomesProvider).valueOrNull ?? const [];
    final expenses = ref.watch(allExpensesProvider).valueOrNull ?? const [];
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final categoryMap = {for (final c in categories) c.id: c};

    bool inMonth(DateTime d) => d.year == _month.year && d.month == _month.month;

    final monthExpenses = expenses.where((e) => inMonth(e.date)).toList();
    final monthIncomes = incomes.where((i) => inMonth(i.date)).toList();

    final totalExpense = monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final totalIncome = monthIncomes.fold<double>(0, (s, i) => s + i.amount);
    final balance = totalIncome - totalExpense;
    final spentPercent = totalIncome > 0
        ? (totalExpense / totalIncome).clamp(0.0, 1.0)
        : (totalExpense > 0 ? 1.0 : 0.0);

    // Merge both kinds of entries, newest first.
    final entries = <_Entry>[
      ...monthExpenses.map(_Entry.expense),
      ...monthIncomes.map(_Entry.income),
    ]..sort((a, b) => b.date.compareTo(a.date));

    // Flatten into day-grouped rows for the list.
    final rows = <Object>[];
    String? prevKey;
    for (final e in entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      if (key != prevKey) {
        rows.add(_dayLabel(e.date));
        prevKey = key;
      }
      rows.add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Balance Details')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 4),
          SizedBox(
            height: 212,
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                BalanceHeaderCard(
                  balance: balance,
                  percent: spentPercent,
                  income: totalIncome,
                  expense: totalExpense,
                  symbol: symbol,
                ),
                _MetricCard(
                  label: 'EXPENSE',
                  amount: totalExpense,
                  symbol: symbol,
                  color: AppColors.secondary,
                  icon: Icons.north_east_rounded,
                  subtitle:
                      '${monthExpenses.length} transaction${monthExpenses.length == 1 ? '' : 's'} this month',
                ),
                _MetricCard(
                  label: 'INCOME',
                  amount: totalIncome,
                  symbol: symbol,
                  color: AppColors.primary,
                  icon: Icons.south_west_rounded,
                  subtitle:
                      '${monthIncomes.length} entr${monthIncomes.length == 1 ? 'y' : 'ies'} this month',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDots(),
          const SizedBox(height: 8),
          _buildListHeader(entries.length),
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is String) return _buildDayHeader(row);
                      return _buildEntryTile(row as _Entry, categoryMap, symbol);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Month selector ─────────────────────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrowButton(Icons.chevron_left_rounded, () => _changeMonth(-1)),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              constraints: const BoxConstraints(minWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Don't allow stepping into the future (no data there).
          _arrowButton(
            Icons.chevron_right_rounded,
            _isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? AppColors.text : AppColors.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Page indicator ──────────────────────────────────────────────────────────
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── Transaction list ─────────────────────────────────────────────────────────
  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Text(
            'Transactions',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text.withValues(alpha: 0.45),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.divider.withValues(alpha: 0.25))),
        ],
      ),
    );
  }

  Widget _buildEntryTile(
    _Entry e,
    Map<String, domain.Category> categoryMap,
    String symbol,
  ) {
    final isExpense = e.isExpense;
    final Color color;
    final IconData icon;
    final String title;
    final String amountText;

    if (isExpense) {
      final exp = e.expense!;
      final cat = categoryMap[exp.categoryId];
      color = cat != null
          ? Color(int.parse(cat.color.replaceAll('#', '0xFF')))
          : AppColors.textSecondary;
      icon = getCategoryIcon(cat?.icon);
      title = cat?.name ?? 'Uncategorized';
      amountText = '-$symbol${exp.amount.toStringAsFixed(2)}';
    } else {
      final inc = e.income!;
      color = AppColors.primary;
      icon = Icons.attach_money_rounded;
      title = inc.source;
      amountText = '+$symbol${inc.amount.toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionDetailView(
                  initialExpense: isExpense ? e.expense : null,
                  initialIncome: isExpense ? null : e.income,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy').format(e.date),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isExpense ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 28,
              color: AppColors.text.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions in ${DateFormat('MMMM yyyy').format(_month)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7 && diff > 0) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }
}

/// A unified income/expense entry used to merge both streams into one list.
class _Entry {
  final DateTime date;
  final domain.Expense? expense;
  final domain.Income? income;

  bool get isExpense => expense != null;

  _Entry.expense(domain.Expense e)
      : expense = e,
        income = null,
        date = e.date;

  _Entry.income(domain.Income i)
      : income = i,
        expense = null,
        date = i.date;
}

/// Gradient summary card for the Expense / Income pages of the carousel, styled
/// to match [BalanceHeaderCard].
class _MetricCard extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color color;
  final IconData icon;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.color,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, dark],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$symbol${amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

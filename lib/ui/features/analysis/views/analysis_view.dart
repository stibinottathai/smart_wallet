import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import '../widgets/section_card.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/net_worth_line_chart.dart';
import '../widgets/savings_rate_card.dart';
import '../widgets/income_breakdown_pie.dart';
import '../widgets/weekday_spending_chart.dart';
import '../widgets/budget_utilization_chart.dart';
import '../widgets/top_spending_days_card.dart';
import '../widgets/expense_source_pie.dart';

class AnalysisView extends ConsumerStatefulWidget {
  const AnalysisView({super.key});

  @override
  ConsumerState<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends ConsumerState<AnalysisView> {
  DateTime? _customStart;
  DateTime? _customEnd;
  String _activeChip = '6M';

  final _chips = ['1M', '3M', '6M', '1Y', 'All'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyChip('6M'));
  }

  void _applyChip(String chip) {
    setState(() {
      _activeChip = chip;
      _customStart = null;
      _customEnd = null;
    });
    _updateRange();
  }

  void _updateRange() {
    final now = DateTime.now();
    (DateTime, DateTime) range;
    if (_customStart != null && _customEnd != null) {
      range = (_customStart!, _customEnd!);
    } else {
      switch (_activeChip) {
        case '1M':
          range = (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month + 1, 0));
        case '3M':
          range = (DateTime(now.year, now.month - 3, 1), DateTime(now.year, now.month + 1, 0));
        case '1Y':
          range = (DateTime(now.year - 1, now.month, 1), DateTime(now.year, now.month + 1, 0));
        case 'All':
          range = (DateTime(2000), DateTime(2100));
        default: // 6M
          range = (DateTime(now.year, now.month - 5, 1), DateTime(now.year, now.month + 1, 0));
      }
    }
    ref.read(analysisDateRangeProvider.notifier).state = range;
  }

  Future<void> _pickStart() async {
    final current = ref.read(analysisDateRangeProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current?.$1 ?? DateTime.now().subtract(const Duration(days: 180)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary, onPrimary: Colors.white,
            surface: AppColors.card, onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked;
        _activeChip = '';
      });
      if (_customEnd != null && _customStart!.isAfter(_customEnd!)) {
        _customEnd = _customStart;
      }
      _updateRange();
    }
  }

  Future<void> _pickEnd() async {
    final current = ref.read(analysisDateRangeProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current?.$2 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary, onPrimary: Colors.white,
            surface: AppColors.card, onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customEnd = picked;
        _activeChip = '';
      });
      if (_customStart != null && _customEnd!.isBefore(_customStart!)) {
        _customStart = _customEnd;
      }
      _updateRange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final range = ref.watch(analysisDateRangeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: incomesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (incomes) {
          return expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('$err')),
            data: (expenses) {
              return categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('$err')),
                data: (categories) {
                  final now = DateTime.now();
                  final start = range?.$1 ?? DateTime(now.year, now.month - 5, 1);
                  final end = range?.$2 ?? DateTime(now.year, now.month + 1, 0);

                  final filteredExpenses = expenses.where((e) =>
                    !e.date.isBefore(start) && !e.date.isAfter(end)
                  ).toList();
                  final filteredIncomes = incomes.where((e) =>
                    !e.date.isBefore(start) && !e.date.isAfter(end)
                  ).toList();

                  final totalIncome = filteredIncomes.fold(0.0, (s, i) => s + i.amount);
                  final totalExpense = filteredExpenses.fold(0.0, (s, e) => s + e.amount);

                  // Last period for savings rate comparison (same length before start)
                  final periodDays = end.difference(start).inDays + 1;
                  final lastStart = start.subtract(Duration(days: periodDays));
                  final lastEnd = start.subtract(const Duration(days: 1));
                  final lastIncomes = incomes.where((e) =>
                    !e.date.isBefore(lastStart) && !e.date.isAfter(lastEnd)
                  ).toList();
                  final lastExpenses = expenses.where((e) =>
                    !e.date.isBefore(lastStart) && !e.date.isAfter(lastEnd)
                  ).toList();
                  final lastIncomeTotal = lastIncomes.fold(0.0, (s, i) => s + i.amount);
                  final lastExpenseTotal = lastExpenses.fold(0.0, (s, e) => s + e.amount);

                  // Category spend map
                  final categorySpend = <String, double>{};
                  for (final exp in filteredExpenses) {
                    categorySpend[exp.categoryId] = (categorySpend[exp.categoryId] ?? 0) + exp.amount;
                  }
                  final catMap = {for (var c in categories) c.id: c};

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RepaintBoundary(
                          child: _DateRangeBar(
                            activeChip: _activeChip,
                            chips: _chips,
                            customStart: _customStart,
                            customEnd: _customEnd,
                            onChipTap: _applyChip,
                            onPickStart: _pickStart,
                            onPickEnd: _pickEnd,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RepaintBoundary(
                          child: MoMCard(
                            currentMonthExpenses: _currentMonthExpenses(filteredExpenses),
                            lastMonthExpenses: _lastMonthExpenses(filteredExpenses),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (totalIncome > 0 || totalExpense > 0)
                          RepaintBoundary(
                            child: SavingsRateCard(
                              totalIncome: totalIncome,
                              totalExpense: totalExpense,
                              lastIncome: lastIncomeTotal,
                              lastExpense: lastExpenseTotal,
                            ),
                          ),
                        if (totalIncome > 0 || totalExpense > 0) const SizedBox(height: 16),
                        RepaintBoundary(
                          child: SectionCard(
                            title: 'Net Worth Trend',
                            child: NetWorthLineChart(incomes: filteredIncomes, expenses: filteredExpenses),
                          ),
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          child: SectionCard(
                            title: 'Income vs Expense',
                            child: IncomeExpenseBarChart(
                              incomes: filteredIncomes, expenses: filteredExpenses,
                              start: start, end: end,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (categorySpend.isNotEmpty)
                          RepaintBoundary(
                            child: SectionCard(
                              title: 'Category Breakdown',
                              child: CategoryPieChart(
                                spend: categorySpend, catMap: catMap,
                                expenses: filteredExpenses, start: start, end: end,
                              ),
                            ),
                          ),
                        if (categorySpend.isNotEmpty) const SizedBox(height: 16),
                        RepaintBoundary(
                          child: SectionCard(
                            title: 'Income Breakdown',
                            child: IncomeBreakdownPie(incomes: filteredIncomes),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filteredExpenses.isNotEmpty)
                          RepaintBoundary(
                            child: SectionCard(
                              title: 'Spending by Weekday',
                              child: WeekdaySpendingChart(expenses: filteredExpenses),
                            ),
                          ),
                        if (filteredExpenses.isNotEmpty) const SizedBox(height: 16),
                        if (categories.any((c) => c.budgetLimit != null))
                          RepaintBoundary(
                            child: SectionCard(
                              title: 'Budget Utilization',
                              child: BudgetUtilizationChart(spend: categorySpend, categories: categories),
                            ),
                          ),
                        if (categories.any((c) => c.budgetLimit != null)) const SizedBox(height: 16),
                        RepaintBoundary(
                          child: SectionCard(
                            title: 'Expense Source',
                            child: ExpenseSourcePie(expenses: filteredExpenses),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filteredExpenses.isNotEmpty)
                          RepaintBoundary(
                            child: SectionCard(
                              title: 'Top Spending Days',
                              child: TopSpendingDaysCard(expenses: filteredExpenses, catMap: catMap),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  double _currentMonthExpenses(List<domain.Expense> expenses) {
    final now = DateTime.now();
    return expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold<double>(0.0, (s, e) => s + e.amount);
  }

  double _lastMonthExpenses(List<domain.Expense> expenses) {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    return expenses
        .where((e) => e.date.month == last.month && e.date.year == last.year)
        .fold<double>(0.0, (s, e) => s + e.amount);
  }
}

class MoMCard extends ConsumerWidget {
  final double currentMonthExpenses;
  final double lastMonthExpenses;

  const MoMCard({
    super.key,
    required this.currentMonthExpenses,
    required this.lastMonthExpenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currencyCodeProvider);
    final diff = currentMonthExpenses - lastMonthExpenses;
    final pct = lastMonthExpenses > 0
        ? (diff / lastMonthExpenses) * 100
        : (currentMonthExpenses > 0 ? 100.0 : 0.0);
    final sign = pct >= 0 ? '+' : '';
    final isUp = pct > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MONTH OVER MONTH',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currencySymbol(code)}${currentMonthExpenses.toStringAsFixed(2)}',
                        style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text('This month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${currencySymbol(code)}${lastMonthExpenses.toStringAsFixed(2)}',
                      style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('Last month', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Spend Trend', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isUp ? AppColors.secondary : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sign${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isUp ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  final String activeChip;
  final List<String> chips;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<String> onChipTap;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangeBar({
    required this.activeChip,
    required this.chips,
    required this.customStart,
    required this.customEnd,
    required this.onChipTap,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: chips.map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(chip, style: const TextStyle(fontSize: 12)),
                          selected: activeChip == chip,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: activeChip == chip ? Colors.white : AppColors.text,
                            fontSize: 12,
                          ),
                          onSelected: (_) => onChipTap(chip),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                if (customStart != null || customEnd != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onChipTap('6M'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPickStart,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        labelText: 'From',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          customStart != null ? DateFormat('MMM d, yyyy').format(customStart!) : 'Start',
                          style: TextStyle(
                            fontSize: 12,
                            color: customStart != null ? AppColors.text : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onPickEnd,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        labelText: 'To',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          customEnd != null ? DateFormat('MMM d, yyyy').format(customEnd!) : 'End',
                          style: TextStyle(
                            fontSize: 12,
                            color: customEnd != null ? AppColors.text : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

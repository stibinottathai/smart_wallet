import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'goal_form_dialog.dart';
import 'bill_form_dialog.dart';
import 'bills_view.dart';
import 'budget_form_dialog.dart';
import 'package:uuid/uuid.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with SingleTickerProviderStateMixin {
  late final AnimationController _aiAnimationController;

  @override
  void initState() {
    super.initState();
    _aiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _aiAnimationController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final code = ref.watch(currencyCodeProvider);

    Widget buildLoading() => const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Loading Dashboard...', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );

    return incomesAsync.when(
      loading: () => buildLoading(),
      error: (err, stack) => Scaffold(body: Center(child: Text('$err'))),
      data: (incomes) {
        return expensesAsync.when(
          loading: () => buildLoading(),
          error: (err, stack) => Scaffold(body: Center(child: Text('$err'))),
          data: (expenses) {
            return categoriesAsync.when(
              loading: () => buildLoading(),
              error: (err, stack) => Scaffold(body: Center(child: Text('$err'))),
              data: (categories) {
                final totalIncome = incomes.fold<double>(0.0, (sum, item) => sum + item.amount);
                final totalExpense = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
                final netBalance = totalIncome - totalExpense;
                final spentPercent = totalIncome > 0
                    ? (totalExpense / totalIncome).clamp(0.0, 1.0)
                    : (totalExpense > 0 ? 1.0 : 0.0);

                final categoryMap = {for (var c in categories) c.id: c};
                final categorySpendMap = <String, double>{};
                for (final exp in expenses) {
                  categorySpendMap[exp.categoryId] =
                      (categorySpendMap[exp.categoryId] ?? 0.0) + exp.amount;
                }

                return Scaffold(
                  body: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final savingsGoals = ref.watch(allSavingsGoalsProvider).value ?? [];
                        final bills = ref.watch(allBillsProvider).value ?? [];
                        final content = _buildDashboardContent(
                          netBalance,
                          spentPercent,
                          totalIncome,
                          totalExpense,
                          categorySpendMap,
                          categoryMap,
                          expenses,
                          savingsGoals,
                          bills,
                          categories,
                          code,
                        );
                        if (constraints.maxWidth > 720) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: content,
                            ),
                          );
                        } else {
                          return content;
                        }
                      },
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const EntryFormView()),
                      );
                    },
                    child: const Icon(Icons.add, size: 26),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(double balance, double percent, double income, double expense, String symbol) {
    final isPositive = balance >= 0;
    final displayPercent = income > 0 ? (expense / income) : (expense > 0 ? 1.0 : 0.0);
    
    final String percentText;
    if (income > 0) {
      percentText = 'Spent ${(displayPercent * 100).toStringAsFixed(0)}% of income';
    } else if (expense > 0) {
      percentText = 'Spent with no income';
    } else {
      percentText = 'No spending activity';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E463C),
              AppColors.primary,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'NET BALANCE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive 
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.secondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPositive
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.secondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: isPositive ? Colors.white : AppColors.secondaryLight,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPositive ? 'On Track' : 'Overspent',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Colors.white : AppColors.secondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$symbol${balance.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        percentText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$symbol${expense.toStringAsFixed(0)} / $symbol${income.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percent > 0.8 
                            ? AppColors.secondary 
                            : const Color(0xFFD4E8E2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(double income, double expense, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Income',
              amount: income,
              color: AppColors.primary,
              prefix: '+',
              symbol: symbol,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Expenses',
              amount: expense,
              color: AppColors.secondary,
              prefix: '-',
              symbol: symbol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutSection(Map<String, double> spendMap, Map<String, domain.Category> catMap) {
    final total = spendMap.values.fold(0.0, (a, b) => a + b);
    final entries = spendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending Breakdown',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sections: entries.asMap().entries.map((e) {
                          final colors = [
                            AppColors.primary,
                            AppColors.secondary,
                            AppColors.primary.withValues(alpha: 0.7),
                            AppColors.secondary.withValues(alpha: 0.7),
                            AppColors.primary.withValues(alpha: 0.5),
                            AppColors.secondary.withValues(alpha: 0.5),
                            AppColors.primary.withValues(alpha: 0.35),
                            AppColors.secondary.withValues(alpha: 0.35),
                          ];
                          return PieChartSectionData(
                            value: e.value.value,
                            color: colors[e.key % colors.length],
                            radius: 28,
                            showTitle: false,
                          );
                        }).toList(),
                        centerSpaceRadius: 28,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: entries.take(5).map((e) {
                        final name = catMap[e.key]?.name ?? 'Unknown';
                        final pct = total > 0 ? (e.value / total * 100) : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(alpha: 0.5 + (e.value / (total > 0 ? total : 1)) * 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    double netBalance,
    double spentPercent,
    double totalIncome,
    double totalExpense,
    Map<String, double> categorySpendMap,
    Map<String, domain.Category> categoryMap,
    List<domain.Expense> expenses,
    List<domain.SavingsGoal> savingsGoals,
    List<domain.Bill> bills,
    List<domain.Category> categories,
    String code,
  ) {
    final symbol = currencySymbol(code);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(child: _buildHeader(netBalance, spentPercent, totalIncome, totalExpense, symbol)),
          const SizedBox(height: 8),
          RepaintBoundary(child: _buildSummaryRow(totalIncome, totalExpense, symbol)),
          RepaintBoundary(child: _buildAiAssistantCard()),
          RepaintBoundary(child: _buildWeeklyTrendSection(expenses, symbol)),
          RepaintBoundary(child: _buildBudgetLimitsSection(categorySpendMap, categories, symbol)),
          RepaintBoundary(child: _buildSavingsGoalsSection(savingsGoals, symbol)),
          RepaintBoundary(child: _buildUpcomingBillsSection(bills, categoryMap, symbol)),
          if (totalExpense > 0)
            RepaintBoundary(child: _buildDonutSection(categorySpendMap, categoryMap)),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalsSection(List<domain.SavingsGoal> goals, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Savings Goals',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const GoalFormDialog(),
                  );
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (goals.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.track_changes_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Save for what matters',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap the plus icon to set saving targets for milestones like an emergency fund or tech upgrades.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final goalColor = Color(int.parse(goal.color.replaceAll('#', '0xFF')));
                  final percent = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
                  final formattedDate = DateFormat('MMM yyyy').format(goal.targetDate);

                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => GoalFormDialog(initialGoal: goal),
                      );
                    },
                    child: Container(
                      width: 180,
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: goalColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: goalColor.withValues(alpha: 0.2)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: goalColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'By $formattedDate',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$symbol${goal.currentAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                'of $symbol${goal.targetAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 4,
                              backgroundColor: goalColor.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBillsSection(List<domain.Bill> bills, Map<String, domain.Category> categoryMap, String symbol) {
    final upcoming = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Bills & Subs',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const BillFormDialog(),
                  );
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No upcoming payments',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap the plus icon to track subscriptions like Netflix, Rent, utilities, and more.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...upcoming.take(2).map((bill) {
              final cat = bill.categoryId != null ? categoryMap[bill.categoryId] : null;
              final catColorStr = cat?.color ?? '#9E9E9E';
              final catColor = Color(int.parse(catColorStr.replaceAll('#', '0xFF')));
              final iconData = getCategoryIcon(cat?.icon);
              final dueLabel = _getDueDateLabel(bill.dueDate);
              final isOverdue = bill.dueDate.isBefore(DateTime.now()) &&
                  !DateUtils.isSameDay(bill.dueDate, DateTime.now());
              final diff = bill.dueDate.difference(DateTime.now());
              final canPay = isOverdue || switch (bill.frequency) {
                domain.BillFrequency.daily   => diff.inHours <= 12,
                domain.BillFrequency.weekly  => diff.inDays <= 2,
                domain.BillFrequency.monthly => diff.inDays <= 10,
                domain.BillFrequency.yearly  => diff.inDays <= 30,
                domain.BillFrequency.oneOff  => diff.inDays <= 10,
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => BillFormDialog(initialBill: bill),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: catColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dueLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverdue ? AppColors.secondary : AppColors.textSecondary,
                                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$symbol${bill.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bill.frequency.displayName,
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (canPay) ...[
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () => _confirmPayBill(bill, categoryMap),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pay Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (upcoming.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BillsView()),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      'View All (${upcoming.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _getDueDateLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Overdue by 1 day';
    if (diff < -1) return 'Overdue by ${-diff} days';
    return 'Due in $diff days';
  }

  Future<void> _confirmPayBill(domain.Bill bill, Map<String, domain.Category> categoryMap) async {
    final code = ref.read(currencyCodeProvider);
    final sym = currencySymbol(code);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Pay Bill',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              bill.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$sym${bill.amount.toStringAsFixed(2)} — ${bill.frequency.displayName}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'An expense of $sym${bill.amount.toStringAsFixed(2)} will be logged automatically.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Pay Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _toggleBillPaid(bill, categoryMap);
    }
  }

  void _toggleBillPaid(domain.Bill bill, Map<String, domain.Category> categoryMap) async {
    final repo = ref.read(billRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    final now = DateTime.now();
    final categoryId = bill.categoryId ?? 'cat_uncategorized';

    final expense = domain.Expense(
      id: const Uuid().v4(),
      amount: bill.amount,
      categoryId: categoryId,
      date: now,
      note: 'Auto-logged bill payment: ${bill.name}',
      source: domain.ExpenseSource.manual,
    );
    await expenseRepo.addExpense(expense);

    // Mark current bill as paid so it disappears from upcoming section
    await repo.updateBill(bill.copyWith(isPaid: true));

    // For recurring bills, create the next occurrence
    if (bill.frequency != domain.BillFrequency.oneOff) {
      DateTime nextDueDate;
      switch (bill.frequency) {
        case domain.BillFrequency.daily:
          nextDueDate = bill.dueDate.add(const Duration(days: 1));
          break;
        case domain.BillFrequency.weekly:
          nextDueDate = bill.dueDate.add(const Duration(days: 7));
          break;
        case domain.BillFrequency.monthly:
          nextDueDate = DateTime(
            bill.dueDate.year,
            bill.dueDate.month + 1,
            bill.dueDate.day,
          );
          break;
        case domain.BillFrequency.yearly:
          nextDueDate = DateTime(
            bill.dueDate.year + 1,
            bill.dueDate.month,
            bill.dueDate.day,
          );
          break;
        case domain.BillFrequency.oneOff:
          nextDueDate = bill.dueDate;
          break;
      }
      await repo.addBill(
        domain.Bill(
          id: const Uuid().v4(),
          name: bill.name,
          amount: bill.amount,
          dueDate: nextDueDate,
          isPaid: false,
          frequency: bill.frequency,
          categoryId: bill.categoryId,
        ),
      );
    }

    if (mounted) {
      final categoryName = categoryMap[categoryId]?.name ?? 'Uncategorized';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paid! Logged ${currencySymbol(ref.read(currencyCodeProvider))}${bill.amount.toStringAsFixed(2)} expense for ${bill.name} under $categoryName.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showManageBudgetsDialog(BuildContext context, List<domain.Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetFormDialog(categories: categories),
    );
  }

  Widget _buildBudgetLimitsSection(
    Map<String, double> categorySpendMap,
    List<domain.Category> categories,
    String symbol,
  ) {
    final items = <_BudgetItem>[];
    for (final category in categories) {
      if (category.id == 'cat_income') continue;
      final limit = category.budgetLimit;
      if (limit != null && limit > 0) {
        final spend = categorySpendMap[category.id] ?? 0.0;
        items.add(_BudgetItem(
          category: category,
          spend: spend,
          limit: limit,
        ));
      }
    }

    items.sort((a, b) => b.percent.compareTo(a.percent));

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Budget Limits',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                      onPressed: () => _showManageBudgetsDialog(context, categories),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Track your spending caps',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set monthly budget limits for categories like Dining, Groceries, and Rent to avoid overspending.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showManageBudgetsDialog(context, categories),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Set Monthly Budgets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Budget Limits',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Spending progress against category caps',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                    onPressed: () => _showManageBudgetsDialog(context, categories),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...items.map((item) {
                final catColor = Color(int.parse(item.category.color.replaceAll('#', '0xFF')));
                final percentLabel = '${(item.percent * 100).toStringAsFixed(0)}%';
                final isOverBudget = item.spend > item.limit;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                getCategoryIcon(item.category.icon),
                                size: 14,
                                color: catColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.category.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$symbol${item.spend.toStringAsFixed(0)} / $symbol${item.limit.toStringAsFixed(0)} ($percentLabel)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOverBudget ? AppColors.secondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.percent.clamp(0.0, 1.0),
                          backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget ? AppColors.secondary : catColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendSection(List<domain.Expense> expenses, String symbol) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    final dailyTotals = <DateTime, double>{};
    for (final day in last7Days) {
      dailyTotals[day] = 0.0;
    }

    for (final exp in expenses) {
      final expDay = DateTime(exp.date.year, exp.date.month, exp.date.day);
      if (dailyTotals.containsKey(expDay)) {
        dailyTotals[expDay] = (dailyTotals[expDay] ?? 0.0) + exp.amount;
      }
    }

    final maxSpend = dailyTotals.values.fold<double>(0.0, (max, val) => val > max ? val : max);
    final yAxisLimit = maxSpend > 0 ? (maxSpend * 1.25) : 10.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Spending Trend',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Daily expenses over the last 7 days',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: yAxisLimit,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.text,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '$symbol${rod.toY.toStringAsFixed(2)}',
                            GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= 7) return const SizedBox.shrink();
                            final day = last7Days[index];
                            final label = DateFormat('E').format(day)[0];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final day = last7Days[index];
                      final total = dailyTotals[day] ?? 0.0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: total,
                            color: AppColors.secondary,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: yAxisLimit,
                              color: AppColors.divider.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistantCard() {
    final apiKey = ref.watch(openRouterApiKeyProvider);
    final isConfigured = apiKey.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(activeTabIndexProvider.notifier).state = isConfigured ? 2 : 4;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF132A35), Color(0xFF1B4D46)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B4D46).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Financial Assistant',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConfigured ? 'Tap the orb to start chatting' : 'Setup required to unlock AI',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Siri-style Orb
                    RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isConfigured 
                                      ? const Color(0xFF00A3FF).withValues(alpha: 0.4) 
                                      : Colors.white.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          RotationTransition(
                            turns: _aiAnimationController,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isConfigured 
                                    ? const SweepGradient(
                                        colors: [
                                          Color(0xFF00FFC2),
                                          Color(0xFF00A3FF),
                                          Color(0xFFB026FF),
                                          Color(0xFFFF26A8),
                                          Color(0xFF00FFC2),
                                        ],
                                      )
                                    : SweepGradient(
                                        colors: [
                                          Colors.grey.shade600,
                                          Colors.grey.shade400,
                                          Colors.grey.shade600,
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                radius: 0.8,
                              ),
                            ),
                          ),
                          Icon(
                            isConfigured ? Icons.auto_awesome_rounded : Icons.settings_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;
  final String symbol;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.text.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$prefix$symbol${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseTile extends ConsumerWidget {
  final domain.Expense expense;
  final domain.Category? category;
  final VoidCallback onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catColorStr = category?.color ?? '#9E9E9E';
    final catColor = Color(int.parse(catColorStr.replaceAll('#', '0xFF')));
    final iconData = getCategoryIcon(category?.icon);
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category?.name ?? 'Uncategorized',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                            ),
                          ),
                          Text(
                            '-$symbol${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(expense.date),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (expense.note != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ${expense.note}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                          if (expense.source == domain.ExpenseSource.aiScan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData getCategoryIcon(String? iconName) {
  switch (iconName) {
    case 'restaurant': return Icons.restaurant;
    case 'shopping_basket': return Icons.shopping_basket;
    case 'directions_car': return Icons.directions_car;
    case 'home': return Icons.home;
    case 'movie': return Icons.movie;
    case 'power': return Icons.power;
    case 'attach_money': return Icons.attach_money;
    default: return Icons.help_outline;
  }
}

class IncomeTile extends ConsumerWidget {
  final domain.Income income;
  final VoidCallback onTap;

  const IncomeTile({
    super.key,
    required this.income,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              income.source,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '+$symbol${income.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(income.date)}${income.isRecurring ? " • ${income.frequency.displayName}" : ""}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _BudgetItem {
  final domain.Category category;
  final double spend;
  final double limit;

  _BudgetItem({
    required this.category,
    required this.spend,
    required this.limit,
  });

  double get percent => limit > 0 ? (spend / limit) : 0.0;
}

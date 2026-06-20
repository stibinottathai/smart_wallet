import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  bool _showExpenses = true; // Switch between Incomes and Expenses ledger

  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return incomesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading incomes: $err'))),
      data: (incomes) {
        return expensesAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error loading expenses: $err'))),
          data: (expenses) {
            return categoriesAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (err, stack) => Scaffold(body: Center(child: Text('Error loading categories: $err'))),
              data: (categories) {
                // Calculations
                final totalIncome = incomes.fold<double>(0.0, (sum, item) => sum + item.amount);
                final totalExpense = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
                final netBalance = totalIncome - totalExpense;

                // Arc percent calculation
                double spentPercent = 0.0;
                if (totalIncome > 0) {
                  spentPercent = (totalExpense / totalIncome).clamp(0.0, 1.0);
                } else if (totalExpense > 0) {
                  spentPercent = 1.0;
                }

                // Category map for category details
                final categoryMap = {for (var c in categories) c.id: c};

                // Group expenses for the Donut Chart
                final Map<String, double> categorySpendMap = {};
                for (final exp in expenses) {
                  categorySpendMap[exp.categoryId] = (categorySpendMap[exp.categoryId] ?? 0.0) + exp.amount;
                }

                return Scaffold(
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12.0),
                          // Signature Header: Balance inside thin arc
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(240, 120),
                                  painter: ArcPainter(percent: spentPercent),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 35),
                                    Text(
                                      '\$${netBalance.toStringAsFixed(2)}',
                                      style: GoogleFonts.fraunces(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'net balance',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.text.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28.0),

                          // Donut Chart showing category breakdown
                          if (totalExpense > 0) ...[
                            const Center(
                              child: Text(
                                'Spending Breakdown',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            SizedBox(
                              height: 140,
                              child: _buildDonutChart(categorySpendMap, categoryMap),
                            ),
                            const SizedBox(height: 24.0),
                          ],

                          // Switch Ledger Pill Toggle
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => _showExpenses = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                      decoration: BoxDecoration(
                                        color: !_showExpenses ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                      child: Text(
                                        'Income',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                          color: !_showExpenses ? Colors.white : AppColors.text.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _showExpenses = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                      decoration: BoxDecoration(
                                        color: _showExpenses ? AppColors.secondary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                      child: Text(
                                        'Expenses',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                          color: _showExpenses ? Colors.white : AppColors.text.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20.0),

                          // Ledger Rows Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _showExpenses ? 'Expense History' : 'Income History',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, letterSpacing: 0.5),
                            ),
                          ),
                          const Divider(),

                          // Flat ledger transaction rows
                          if (_showExpenses)
                            _buildExpenseList(expenses, categoryMap)
                          else
                            _buildIncomeList(incomes),
                        ],
                      ),
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const EntryFormView()),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDonutChart(Map<String, double> categorySpendMap, Map<String, domain.Category> categoryMap) {
    final List<PieChartSectionData> sections = [];
    int index = 0;

    final baseColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.primary.withValues(alpha: 0.7),
      AppColors.secondary.withValues(alpha: 0.7),
      AppColors.primary.withValues(alpha: 0.5),
      AppColors.secondary.withValues(alpha: 0.5),
      AppColors.primary.withValues(alpha: 0.3),
      AppColors.secondary.withValues(alpha: 0.3),
    ];

    categorySpendMap.forEach((catId, amount) {
      final name = categoryMap[catId]?.name ?? 'Uncategorized';
      sections.add(
        PieChartSectionData(
          value: amount,
          title: name,
          radius: 35,
          showTitle: false,
          color: baseColors[index % baseColors.length],
        ),
      );
      index++;
    });

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildExpenseList(List<domain.Expense> expenses, Map<String, domain.Category> categoryMap) {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'No expenses yet. Tap + to add your first one.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final sortedExpenses = List<domain.Expense>.from(expenses)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedExpenses.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final expense = sortedExpenses[index];
        final cat = categoryMap[expense.categoryId];
        final catColorStr = cat?.color ?? '#9E9E9E';
        final catColor = Color(int.parse(catColorStr.replaceAll('#', '0xFF')));

        return Dismissible(
          key: Key(expense.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.secondary,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) async {
            await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense deleted')),
            );
          },
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EntryFormView(initialExpense: expense),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: catColor.withValues(alpha: 0.15),
              child: Icon(
                _getIconData(cat?.icon),
                color: catColor,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    cat?.name ?? 'Uncategorized',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.0),
                  ),
                ),
                Text(
                  '-\$${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Text(
                  DateFormat('d MMM yyyy').format(expense.date),
                  style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                ),
                if (expense.note != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '•  ${expense.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                    ),
                  ),
                ],
                if (expense.source == domain.ExpenseSource.aiScan) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncomeList(List<domain.Income> incomes) {
    if (incomes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'No incomes yet. Tap + to add your first one.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final sortedIncomes = List<domain.Income>.from(incomes)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedIncomes.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final income = sortedIncomes[index];

        return Dismissible(
          key: Key(income.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.secondary,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) async {
            await ref.read(incomeRepositoryProvider).deleteIncome(income.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Income deleted')),
            );
          },
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EntryFormView(initialIncome: income),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.attach_money,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    income.source,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.0),
                  ),
                ),
                Text(
                  '+\$${income.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${DateFormat('d MMM yyyy').format(income.date)}${income.isRecurring ? " • Recurring (${income.frequency.displayName})" : ""}',
              style: const TextStyle(fontSize: 12.0, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'movie':
        return Icons.movie;
      case 'power':
        return Icons.power;
      case 'attach_money':
        return Icons.attach_money;
      case 'help_outline':
      default:
        return Icons.help_outline;
    }
  }
}

class ArcPainter extends CustomPainter {
  final double percent; // 0.0 to 1.0

  ArcPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Remaining (Pine Green) background arc
    final paintBg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 2. Draw Spent (Terracotta) foreground arc
    final paintFg = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);

    // Draw total semi-circle (from 180 degrees to 360 degrees)
    canvas.drawArc(rect, 3.14159, 3.14159, false, paintBg);

    // Draw spent portion over it
    if (percent > 0) {
      canvas.drawArc(rect, 3.14159, 3.14159 * percent, false, paintFg);
    }
  }

  @override
  bool shouldRepaint(covariant ArcPainter oldDelegate) => oldDelegate.percent != percent;
}

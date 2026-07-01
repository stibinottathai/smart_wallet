import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';
import 'package:smart_wallet/ui/features/dashboard/views/balance_detail_view.dart';
import 'package:smart_wallet/ui/features/entries/views/all_transactions_view.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/animated_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/balance_header_card.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/budget_limits_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/greeting_header.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/proactive_insights_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/savings_goals_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/spending_breakdown_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/summary_row.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/upcoming_bills_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/wealth_summary_section.dart';
import 'package:smart_wallet/ui/features/dashboard/widgets/weekly_trend_section.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auto-refresh provider alive so smart alerts are generated on
    // launch and after each new transaction without any manual scan.
    ref.watch(autoInsightRefreshProvider);

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
                // All-time spend per category — used by the spending breakdown.
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
                        final content = _DashboardContent(
                          netBalance: netBalance,
                          spentPercent: spentPercent,
                          totalIncome: totalIncome,
                          totalExpense: totalExpense,
                          categorySpendMap: categorySpendMap,
                          categoryMap: categoryMap,
                          expenses: expenses,
                          savingsGoals: savingsGoals,
                          bills: bills,
                          categories: categories,
                          code: code,
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
                    heroTag: 'dashboard_transactions_fab',
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
}

/// Scrollable body of the dashboard — composes the feature sections. Each
/// section is wrapped in a [RepaintBoundary] so it repaints in isolation.
class _DashboardContent extends StatelessWidget {
  final double netBalance;
  final double spentPercent;
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categorySpendMap;
  final Map<String, domain.Category> categoryMap;
  final List<domain.Expense> expenses;
  final List<domain.SavingsGoal> savingsGoals;
  final List<domain.Bill> bills;
  final List<domain.Category> categories;
  final String code;

  const _DashboardContent({
    required this.netBalance,
    required this.spentPercent,
    required this.totalIncome,
    required this.totalExpense,
    required this.categorySpendMap,
    required this.categoryMap,
    required this.expenses,
    required this.savingsGoals,
    required this.bills,
    required this.categories,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(code);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnimatedSection(
            index: 0,
            tabIndex: 0,
            child: RepaintBoundary(child: GreetingHeader()),
          ),
          AnimatedSection(
            index: 1,
            tabIndex: 0,
            child: RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BalanceDetailView()),
                  );
                },
                child: BalanceHeaderCard(
                  balance: netBalance,
                  percent: spentPercent,
                  income: totalIncome,
                  expense: totalExpense,
                  symbol: symbol,
                  showDetailsHint: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSection(
            index: 2,
            tabIndex: 0,
            child: RepaintBoundary(
              child: SummaryRow(
                income: totalIncome,
                expense: totalExpense,
                symbol: symbol,
                onIncomeTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllTransactionsView(
                        initialShowExpenses: false,
                        animateTabIndex: null,
                      ),
                    ),
                  );
                },
                onExpenseTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllTransactionsView(
                        initialShowExpenses: true,
                        animateTabIndex: null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          const AnimatedSection(
            index: 3,
            tabIndex: 0,
            child: RepaintBoundary(child: WealthSummarySection()),
          ),
          const SizedBox(height: 4),
          const AnimatedSection(
            index: 4,
            tabIndex: 0,
            child: RepaintBoundary(child: ProactiveInsightsSection()),
          ),
          AnimatedSection(
            index: 5,
            tabIndex: 0,
            child: RepaintBoundary(child: WeeklyTrendSection(expenses: expenses, symbol: symbol)),
          ),
          AnimatedSection(
            index: 6,
            tabIndex: 0,
            child: RepaintBoundary(
              child: BudgetLimitsSection(
                expenses: expenses,
                categories: categories,
                symbol: symbol,
              ),
            ),
          ),
          AnimatedSection(
            index: 7,
            tabIndex: 0,
            child: RepaintBoundary(child: SavingsGoalsSection(goals: savingsGoals, symbol: symbol)),
          ),
          AnimatedSection(
            index: 8,
            tabIndex: 0,
            child: RepaintBoundary(
              child: UpcomingBillsSection(
                bills: bills,
                categoryMap: categoryMap,
                symbol: symbol,
              ),
            ),
          ),
          if (totalExpense > 0)
            AnimatedSection(
              index: 9,
              tabIndex: 0,
              child: RepaintBoundary(
                child: SpendingBreakdownSection(
                  spendMap: categorySpendMap,
                  categoryMap: categoryMap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/features/entries/views/entry_form_view.dart';
import 'package:smart_wallet/ui/features/dashboard/views/dashboard_view.dart';

class AllTransactionsView extends ConsumerStatefulWidget {
  final bool initialShowExpenses;

  const AllTransactionsView({
    super.key,
    this.initialShowExpenses = true,
  });

  @override
  ConsumerState<AllTransactionsView> createState() => _AllTransactionsViewState();
}

class _AllTransactionsViewState extends ConsumerState<AllTransactionsView> {
  late bool _showExpenses;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _showExpenses = widget.initialShowExpenses;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(allIncomesProvider);
    final expensesAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTypeToggle(),
            _buildSearchField(),
            Expanded(
              child: incomesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('$err')),
                data: (incomes) => expensesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('$err')),
                  data: (expenses) => categoriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('$err')),
                    data: (categories) {
                      final categoryMap = {for (var c in categories) c.id: c};
                      return _showExpenses
                          ? _buildExpensesList(expenses, categoryMap)
                          : _buildIncomesList(incomes);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showExpenses = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_showExpenses ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'Income',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: !_showExpenses ? Colors.white : AppColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showExpenses = true;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _showExpenses ? AppColors.secondary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'Expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _showExpenses ? Colors.white : AppColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: _showExpenses ? 'Search notes or categories...' : 'Search income sources...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildExpensesList(List<domain.Expense> expenses, Map<String, domain.Category> catMap) {
    var filtered = expenses;
    if (_searchQuery.isNotEmpty) {
      filtered = expenses.where((exp) {
        final catName = catMap[exp.categoryId]?.name.toLowerCase() ?? '';
        final note = exp.note?.toLowerCase() ?? '';
        return catName.contains(_searchQuery) || note.contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No matches found' : 'No expenses yet',
        _searchQuery.isNotEmpty ? 'Try searching something else' : 'Tap + on the ledger screen to add an expense',
      );
    }

    final sorted = List<domain.Expense>.from(filtered)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: sorted.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final exp = sorted[index];
        final cat = catMap[exp.categoryId];
        return Dismissible(
          key: Key('all_expense_${exp.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDeleteConfirmationDialog(
              context: context,
              itemType: 'expense',
            );
          },
          onDismissed: (direction) async {
            await ref.read(expenseRepositoryProvider).deleteExpense(exp.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted')),
              );
            }
          },
          child: ExpenseTile(
            expense: exp,
            category: cat,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EntryFormView(initialExpense: exp)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIncomesList(List<domain.Income> incomes) {
    var filtered = incomes;
    if (_searchQuery.isNotEmpty) {
      filtered = incomes.where((inc) {
        return inc.source.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No matches found' : 'No income yet',
        _searchQuery.isNotEmpty ? 'Try searching something else' : 'Tap + on the ledger screen to add an income',
      );
    }

    final sorted = List<domain.Income>.from(filtered)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: sorted.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final inc = sorted[index];
        return Dismissible(
          key: Key('all_income_${inc.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDeleteConfirmationDialog(
              context: context,
              itemType: 'income',
            );
          },
          onDismissed: (direction) async {
            await ref.read(incomeRepositoryProvider).deleteIncome(inc.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Income deleted')),
              );
            }
          },
          child: IncomeTile(
            income: inc,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EntryFormView(initialIncome: inc)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
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
              _showExpenses ? Icons.receipt_long_rounded : Icons.account_balance_wallet_rounded,
              size: 28,
              color: AppColors.text.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

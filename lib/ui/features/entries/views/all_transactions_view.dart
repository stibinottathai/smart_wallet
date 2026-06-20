import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/animations.dart';
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
  bool _filtersExpanded = false;
  String? _filterCategoryId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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

  void _clearFilters() {
    setState(() {
      _filterCategoryId = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  bool get _hasActiveFilters =>
      _filterCategoryId != null ||
      _filterStartDate != null ||
      _filterEndDate != null;



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
            if (_filtersExpanded) _buildFilterPanel(),
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
      padding: EdgeInsets.fromLTRB(20, 4, 20, (_filtersExpanded ? 0 : 12)),
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      _filtersExpanded ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                      size: 20,
                      color: _hasActiveFilters ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _filtersExpanded = !_filtersExpanded);
                    },
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_showExpenses) _buildCategoryChips(),
          const SizedBox(height: 6),
          _buildDateRangeRow(),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _filterCategoryId == null,
            onTap: () => setState(() => _filterCategoryId = null),
          ),
          const SizedBox(width: 6),
          ...categories.map((cat) => _FilterChip(
            label: cat.name,
            selected: _filterCategoryId == cat.id,
            color: Color(int.parse(cat.color.replaceAll('#', '0xFF'))),
            onTap: () => setState(() => _filterCategoryId = cat.id),
          )),
        ],
      ),
    );
  }

  Widget _buildDateRangeRow() {
    return Row(
      children: [
        Expanded(
          child: _DateFilterButton(
            label: 'From',
            date: _filterStartDate,
            onTap: () => _pickDate(isStart: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.text.withValues(alpha: 0.3)),
        ),
        Expanded(
          child: _DateFilterButton(
            label: 'To',
            date: _filterEndDate,
            onTap: () => _pickDate(isStart: false),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _filterStartDate : _filterEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _filterStartDate = picked;
        } else {
          _filterEndDate = picked;
        }
      });
    }
  }

  List<domain.Expense> _applyFilters(List<domain.Expense> expenses, Map<String, domain.Category> catMap) {
    var filtered = expenses;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((exp) {
        final catName = catMap[exp.categoryId]?.name.toLowerCase() ?? '';
        final note = exp.note?.toLowerCase() ?? '';
        return catName.contains(_searchQuery) || note.contains(_searchQuery);
      }).toList();
    }

    if (_filterCategoryId != null) {
      filtered = filtered.where((exp) => exp.categoryId == _filterCategoryId).toList();
    }

    if (_filterStartDate != null) {
      filtered = filtered.where((exp) => !exp.date.isBefore(_filterStartDate!)).toList();
    }

    if (_filterEndDate != null) {
      final endOfDay = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
      filtered = filtered.where((exp) => !exp.date.isAfter(endOfDay)).toList();
    }

    return filtered;
  }

  List<domain.Income> _applyIncomeFilters(List<domain.Income> incomes) {
    var filtered = incomes;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inc) {
        return inc.source.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (_filterStartDate != null) {
      filtered = filtered.where((inc) => !inc.date.isBefore(_filterStartDate!)).toList();
    }

    if (_filterEndDate != null) {
      final endOfDay = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
      filtered = filtered.where((inc) => !inc.date.isAfter(endOfDay)).toList();
    }

    return filtered;
  }

  Widget _buildExpensesList(List<domain.Expense> expenses, Map<String, domain.Category> catMap) {
    final filtered = _applyFilters(expenses, catMap);

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _hasActiveFilters || _searchQuery.isNotEmpty ? 'No matches found' : 'No expenses yet',
        _hasActiveFilters || _searchQuery.isNotEmpty
            ? 'Try adjusting your search or filters'
            : 'Tap + on the ledger screen to add an expense',
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
                AppAnimations.fadeSlideUp(EntryFormView(initialExpense: exp)),
              );
            },
          ),
        ).fadeSlideIn(delayMs: index * 30);
      },
    );
  }

  Widget _buildIncomesList(List<domain.Income> incomes) {
    final filtered = _applyIncomeFilters(incomes);

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _hasActiveFilters || _searchQuery.isNotEmpty ? 'No matches found' : 'No income yet',
        _hasActiveFilters || _searchQuery.isNotEmpty
            ? 'Try adjusting your search or filters'
            : 'Tap + on the ledger screen to add an income',
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
                AppAnimations.fadeSlideUp(EntryFormView(initialIncome: inc)),
              );
            },
          ),
        ).fadeSlideIn(delayMs: index * 30);
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _showExpenses ? Icons.receipt_long_rounded : Icons.account_balance_wallet_rounded,
              size: 36,
              color: AppColors.text.withValues(alpha: 0.25),
            ),
          )
              .animate()
              .scaleXY(begin: 0, end: 1, duration: 500.ms, curve: Curves.easeOutBack)
              .then()
              .shimmer(duration: 1500.ms, color: const Color(0x08000000)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: 0.03, end: 0),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: 0.03, end: 0),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor.withValues(alpha: 0.4) : AppColors.divider.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? chipColor : AppColors.text.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateFilterButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: date != null ? AppColors.primary : AppColors.text.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              date != null ? DateFormat('MMM d, yyyy').format(date!) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: date != null ? AppColors.primary : AppColors.text.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

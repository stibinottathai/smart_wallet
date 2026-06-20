import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
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
  int _loadedCount = 20;
  static const int _pageSize = 20;

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
      _loadedCount = _pageSize;
    });
  }

  bool get _hasActiveFilters =>
      _filterCategoryId != null ||
      _filterStartDate != null ||
      _filterEndDate != null;

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, yyyy').format(date);
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'transactions_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const EntryFormView()),
          );
        },
        child: const Icon(Icons.add, size: 26),
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
                    _loadedCount = _pageSize;
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
                    _loadedCount = _pageSize;
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim().toLowerCase();
              _loadedCount = _pageSize;
            });
          },
          decoration: InputDecoration(
            hintText: _showExpenses ? 'Search notes or categories...' : 'Search income sources...',
            hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.35), fontSize: 13.5),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.search_rounded, size: 20, color: AppColors.text.withValues(alpha: 0.35)),
            ),
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
                        _loadedCount = _pageSize;
                      });
                    },
                  ),
                Container(
                  width: 1,
                  height: 20,
                  color: AppColors.divider.withValues(alpha: 0.3),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        _filtersExpanded ? Icons.filter_alt_off_rounded : Icons.tune_rounded,
                        size: 20,
                        color: _hasActiveFilters ? AppColors.primary : AppColors.text.withValues(alpha: 0.5),
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
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_rounded, size: 14, color: AppColors.text.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_showExpenses) _buildCategoryChips(),
            const SizedBox(height: 8),
            _buildDateRangeRow(),
          ],
        ),
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
            onTap: () => setState(() {
              _filterCategoryId = null;
              _loadedCount = _pageSize;
            }),
          ),
          const SizedBox(width: 6),
          ...categories.map((cat) => _FilterChip(
            label: cat.name,
            selected: _filterCategoryId == cat.id,
            color: Color(int.parse(cat.color.replaceAll('#', '0xFF'))),
            onTap: () => setState(() {
              _filterCategoryId = cat.id;
              _loadedCount = _pageSize;
            }),
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
        _loadedCount = _pageSize;
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

    final items = <_FlatItem>[];
    String? prevKey;
    int loaded = 0;
    for (final exp in sorted) {
      if (loaded >= _loadedCount) break;
      final key = DateFormat('yyyy-MM-dd').format(exp.date);
      if (key != prevKey) {
        items.add(_FlatItem.header(_formatDateLabel(exp.date)));
        prevKey = key;
      }
      items.add(_FlatItem.expense(exp, catMap[exp.categoryId]));
      loaded++;
    }

    final hasMore = sorted.length > loaded;

    return ListView.builder(
      itemCount: items.length + (hasMore ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _buildLoadMoreButton();
        }
        final item = items[index];
        if (item.isHeader) {
          return _buildDateHeader(item.dateLabel!);
        }
        final exp = item.expense!;
        final cat = item.category;
        return Dismissible(
          key: Key('all_expense_${exp.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDeleteConfirmationDialog(context: context, itemType: 'expense');
          },
          onDismissed: (direction) async {
            await ref.read(expenseRepositoryProvider).deleteExpense(exp.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted')));
            }
          },
          child: _ExpenseListTile(expense: exp, category: cat, onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EntryFormView(initialExpense: exp)),
            );
          }),
        );
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

    final items = <_FlatItem>[];
    String? prevKey;
    int loaded = 0;
    for (final inc in sorted) {
      if (loaded >= _loadedCount) break;
      final key = DateFormat('yyyy-MM-dd').format(inc.date);
      if (key != prevKey) {
        items.add(_FlatItem.header(_formatDateLabel(inc.date)));
        prevKey = key;
      }
      items.add(_FlatItem.income(inc));
      loaded++;
    }

    final hasMore = sorted.length > loaded;

    return ListView.builder(
      itemCount: items.length + (hasMore ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _buildLoadMoreButton();
        }
        final item = items[index];
        if (item.isHeader) {
          return _buildDateHeader(item.dateLabel!);
        }
        final inc = item.income!;
        return Dismissible(
          key: Key('all_income_${inc.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDeleteConfirmationDialog(context: context, itemType: 'income');
          },
          onDismissed: (direction) async {
            await ref.read(incomeRepositoryProvider).deleteIncome(inc.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Income deleted')));
            }
          },
          child: _IncomeListTile(income: inc, onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EntryFormView(initialIncome: inc)),
            );
          }),
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

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text.withValues(alpha: 0.45),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AppColors.divider.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _loadedCount += _pageSize;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            foregroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.expand_more_rounded, size: 18),
              const SizedBox(width: 4),
              Text('Load More', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatItem {
  final bool isHeader;
  final String? dateLabel;
  final domain.Expense? expense;
  final domain.Income? income;
  final domain.Category? category;

  _FlatItem.header(this.dateLabel)
      : isHeader = true,
        expense = null,
        income = null,
        category = null;

  _FlatItem.expense(this.expense, this.category)
      : isHeader = false,
        dateLabel = null,
        income = null;

  _FlatItem.income(this.income)
      : isHeader = false,
        dateLabel = null,
        expense = null,
        category = null;
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

class _ExpenseListTile extends ConsumerWidget {
  final domain.Expense expense;
  final domain.Category? category;
  final VoidCallback onTap;

  const _ExpenseListTile({
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? 'Uncategorized',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(expense.date),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (expense.note != null && expense.note!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${expense.note}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-$symbol${expense.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.secondary.withValues(alpha: 0.9),
                    ),
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

class _IncomeListTile extends ConsumerWidget {
  final domain.Income income;
  final VoidCallback onTap;

  const _IncomeListTile({
    required this.income,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                      Text(
                        income.source,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(income.date)}${income.isRecurring ? " • ${income.frequency.displayName}" : ""}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$symbol${income.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
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

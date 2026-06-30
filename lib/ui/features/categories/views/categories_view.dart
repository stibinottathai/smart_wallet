import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/providers.dart';

const int kMaxCategoriesPerType = 15;

const List<String> _kColorPalette = [
  '#B5634A', '#D39B82', '#A47449', '#D4845A',
  '#688F80', '#2F6F5E', '#4F5B56', '#5D9B9B',
  '#617C8F', '#4A90C4', '#7B5EA7', '#A3A89E',
  '#E8A838', '#C95E5E', '#6BAE6E', '#9E9E9E',
];

class CategoriesView extends ConsumerStatefulWidget {
  const CategoriesView({super.key});

  @override
  ConsumerState<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<CategoriesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showExpenseAddDialog(List<domain.Category> expenseCategories) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        existingNames: expenseCategories.map((c) => c.name.toLowerCase()).toList(),
        onSave: (name, icon, color) async {
          await ref.read(expenseRepositoryProvider).addCategory(
            domain.Category(
              id: 'cat_user_${const Uuid().v4().replaceAll('-', '')}',
              name: name,
              icon: icon,
              color: color,
              isDefault: false,
            ),
          );
        },
      ),
    );
  }

  void _showIncomeAddDialog(List<domain.Category> sources) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        existingNames: sources.map((s) => s.name.toLowerCase()).toList(),
        onSave: (name, icon, color) async {
          await ref.read(incomeSourcesProvider.notifier).add(
            domain.Category(
              id: 'inc_user_${const Uuid().v4().replaceAll('-', '')}',
              name: name,
              icon: icon,
              color: color,
              isDefault: false,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final incomeSources = ref.watch(incomeSourcesProvider);

    final expenseCategories = (categoriesAsync.value ?? [])
        .where((c) => c.id != 'cat_income')
        .toList();

    final currentTab = _tabController.index;
    final expenseAtLimit = expenseCategories.length >= kMaxCategoriesPerType;
    final incomeAtLimit = incomeSources.length >= kMaxCategoriesPerType;
    final atLimit = currentTab == 0 ? expenseAtLimit : incomeAtLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTypeToggle(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpenseTab(categoriesAsync, expenseCategories),
                _buildIncomeTab(incomeSources),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: atLimit
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 26),
              onPressed: () {
                if (currentTab == 0) {
                  _showExpenseAddDialog(expenseCategories);
                } else {
                  _showIncomeAddDialog(incomeSources);
                }
              },
            ),
    );
  }

  Widget _buildTypeToggle() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        final currentTab = _tabController.animation?.value.round() ?? _tabController.index;
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
                onTap: () => _tabController.animateTo(0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: currentTab == 0 ? AppColors.secondary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'Expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: currentTab == 0 ? Colors.white : AppColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: currentTab == 1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'Income',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: currentTab == 1 ? Colors.white : AppColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

  Widget _buildExpenseTab(
    AsyncValue<List<domain.Category>> categoriesAsync,
    List<domain.Category> expenseCategories,
  ) {
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (_) {
        final atLimit = expenseCategories.length >= kMaxCategoriesPerType;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${expenseCategories.length} / $kMaxCategoriesPerType categories',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (atLimit) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• limit reached',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                itemCount: expenseCategories.length,
                itemBuilder: (ctx, i) => _ExpenseCategoryTile(
                  category: expenseCategories[i],
                  allExpenseCategories: expenseCategories,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncomeTab(List<domain.Category> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${sources.length} / $kMaxCategoriesPerType sources',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (sources.length >= kMaxCategoriesPerType) ...[
                const SizedBox(width: 6),
                Text(
                  '• limit reached',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '"Other (Custom)" is always available in the form',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: sources.isEmpty
              ? const Center(child: Text('No income sources. Add one below.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: sources.length,
                  itemBuilder: (ctx, i) => _IncomeSourceTile(
                    source: sources[i],
                    index: i,
                    allSources: sources,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Expense category tile ────────────────────────────────────────────────────

class _ExpenseCategoryTile extends ConsumerWidget {
  final domain.Category category;
  final List<domain.Category> allExpenseCategories;

  const _ExpenseCategoryTile({
    required this.category,
    required this.allExpenseCategories,
  });

  Color get _color =>
      Color(int.parse(category.color.replaceAll('#', '0xFF')));

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        initialName: category.name,
        initialIcon: category.icon,
        initialColor: category.color,
        existingNames: allExpenseCategories
            .where((c) => c.id != category.id)
            .map((c) => c.name.toLowerCase())
            .toList(),
        onSave: (name, icon, color) async {
          await ref.read(expenseRepositoryProvider).updateCategory(
            category.copyWith(name: name, icon: icon, color: color),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${category.name}"? Existing transactions will keep their category label.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: category.isDefault ? null : () => _showEditDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(getCategoryIcon(category.icon), color: _color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category.isDefault) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 9, color: AppColors.primary),
                            const SizedBox(width: 3),
                            const Text(
                              'Default',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!category.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () async {
                      if (await _confirmDelete(context)) {
                        ref.read(expenseRepositoryProvider).deleteCategory(category.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error.withValues(alpha: 0.8),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (category.isDefault) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('cat_${category.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) {
          ref.read(expenseRepositoryProvider).deleteCategory(category.id);
        },
        child: card,
      ),
    );
  }
}

// ── Income source tile ───────────────────────────────────────────────────────

class _IncomeSourceTile extends ConsumerWidget {
  final domain.Category source;
  final int index;
  final List<domain.Category> allSources;

  const _IncomeSourceTile({
    required this.source,
    required this.index,
    required this.allSources,
  });

  Color get _color =>
      Color(int.parse(source.color.replaceAll('#', '0xFF')));

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        initialName: source.name,
        initialIcon: source.icon,
        initialColor: source.color,
        existingNames: allSources
            .where((s) => s.id != source.id)
            .map((s) => s.name.toLowerCase())
            .toList(),
        onSave: (name, icon, color) async {
          await ref.read(incomeSourcesProvider.notifier).updateItem(
            index,
            source.copyWith(name: name, icon: icon, color: color),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Source'),
        content: Text('Remove "${source.name}" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: source.isDefault ? null : () => _showEditDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(getCategoryIcon(source.icon), color: _color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      source.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (source.isDefault) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 9, color: AppColors.primary),
                            const SizedBox(width: 3),
                            const Text(
                              'Default',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!source.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () async {
                      if (await _confirmDelete(context)) {
                        ref.read(incomeSourcesProvider.notifier).delete(index);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error.withValues(alpha: 0.8),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (source.isDefault) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('inc_${source.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) {
          ref.read(incomeSourcesProvider.notifier).delete(index);
        },
        child: card,
      ),
    );
  }
}

// ── Add / edit expense category dialog ──────────────────────────────────────

class _CategoryFormDialog extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  final String? initialColor;
  final List<String> existingNames;
  final Future<void> Function(String name, String icon, String color) onSave;

  const _CategoryFormDialog({
    this.initialName,
    this.initialIcon,
    this.initialColor,
    required this.existingNames,
    required this.onSave,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = 'help_outline';
  String _selectedColor = '#B5634A';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _selectedIcon = widget.initialIcon ?? 'help_outline';
    _selectedColor = widget.initialColor ?? _kColorPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameController.text.trim(),
        _selectedIcon,
        _selectedColor,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconEntries = kAllCategoryIcons.entries.toList();

    return AlertDialog(
      title: Text(widget.initialName != null ? 'Edit Category' : 'New Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                  autofocus: widget.initialName == null,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Name is required';
                    if (widget.existingNames.contains(t.toLowerCase())) {
                      return 'Category already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Icon',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: iconEntries.length,
                    itemBuilder: (ctx, i) {
                      final entry = iconEntries[i];
                      final selected = entry.key == _selectedIcon;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            size: 18,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kColorPalette.map((hex) {
                    final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                    final selected = hex == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? AppColors.text : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

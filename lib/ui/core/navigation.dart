import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/dashboard/views/dashboard_view.dart';
import 'package:smart_wallet/ui/features/entries/views/all_transactions_view.dart';
import 'package:smart_wallet/ui/features/analysis/views/analysis_view.dart';
import 'package:smart_wallet/ui/features/insights/views/insights_view.dart';
import 'package:smart_wallet/ui/features/settings/views/settings_view.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/data/services/notification_coordinator.dart';
import 'package:smart_wallet/data/services/app_update_service.dart';
import 'package:smart_wallet/data/services/sms_parser.dart';
import 'package:smart_wallet/data/services/category_predictor.dart';
import 'package:smart_wallet/ui/features/settings/widgets/sms_import_dialog.dart';
import 'package:smart_wallet/ui/features/settings/providers/sms_import_notifier.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  ConsumerState<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _orbController;
  bool _showingSmsImportSheet = false;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
    // Schedule reminders / budget alerts on launch, once initial data is ready,
    // post any due recurring transactions, and prompt for a Play Store update
    // if a newer version is available.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _processRecurring();
      _syncNotifications();
      if (mounted) AppUpdateService.checkAndPrompt(context);
      _checkAndShowSmsImport();
    });
  }

  /// Auto-creates any recurring expenses/incomes that have come due since the
  /// app was last opened, then nudges the user if anything was added.
  Future<void> _processRecurring() async {
    try {
      final result = await ref.read(processRecurringProvider.future);
      if (!mounted || result.isEmpty) return;
      final parts = <String>[];
      if (result.expenseCount > 0) {
        parts.add('${result.expenseCount} expense${result.expenseCount == 1 ? '' : 's'}');
      }
      if (result.incomeCount > 0) {
        parts.add('${result.incomeCount} income${result.incomeCount == 1 ? '' : 's'}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${parts.join(' & ')} from your recurring schedule.')),
      );
    } catch (_) {
      // Never let recurring processing block app start.
    }
  }

  void _syncNotifications() {
    final expenses = ref.read(allExpensesProvider).value;
    final categories = ref.read(allCategoriesProvider).value;
    if (expenses == null || categories == null) return;
    NotificationCoordinator.sync(
      expenses: expenses,
      categories: categories,
      incomes: ref.read(allIncomesProvider).value ?? const [],
      currencySymbol: currencySymbol(ref.read(currencyCodeProvider)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(pendingSmsImportsProvider.notifier).checkPendingImports();
    }
  }

  void _checkAndShowSmsImport() {
    final pending = ref.read(pendingSmsImportsProvider);
    if (pending.isNotEmpty && !_showingSmsImportSheet) {
      _showSmsImportBottomSheet(pending.first);
    }
  }

  void _showSmsImportBottomSheet(ParsedSmsTransaction tx) async {
    _showingSmsImportSheet = true;
    final categories = ref.read(allCategoriesProvider).value ?? [];
    
    final predictedCatId = CategoryPredictor.predict(
      tx.merchant,
      categories,
      tx.type == SmsTransactionType.debit,
    );

    final accounts = ref.read(allAccountsProvider).value ?? [];
    final defaultAccId = ref.read(defaultAccountIdProvider);
    final matchedAcc = accounts.where((a) {
      final normName = a.name.toLowerCase();
      final normBank = tx.bankName.toLowerCase();
      return normName.contains(normBank) || (tx.accountOrCard.toLowerCase().contains(a.id.replaceAll('acc_', '')));
    }).firstOrNull;
    final accountId = matchedAcc?.id ?? defaultAccId;

    if (!mounted) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmsImportDialog(
        transaction: tx,
        predictedCategoryId: predictedCatId,
        initialAccountId: accountId,
      ),
    );

    _showingSmsImportSheet = false;
    ref.read(pendingSmsImportsProvider.notifier).removeFirst();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndShowSmsImport();
      }
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  final List<Widget> _screens = const [
    DashboardView(),
    AllTransactionsView(initialShowExpenses: true, animateTabIndex: 1),
    InsightsView(),
    AnalysisView(),
    SettingsView(),
  ];

  void _onNavTap(int index) {
    final current = ref.read(activeTabIndexProvider);
    if (index == current) return;
    ref.read(activeTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(activeTabIndexProvider);
    // Re-evaluate scheduled notifications whenever spending data changes.
    ref.listen(allExpensesProvider, (_, __) => _syncNotifications());
    ref.listen(allCategoriesProvider, (_, __) => _syncNotifications());
    ref.listen(allIncomesProvider, (_, __) => _syncNotifications());
    ref.listen<List<ParsedSmsTransaction>>(pendingSmsImportsProvider, (previous, next) {
      if (next.isNotEmpty) {
        _checkAndShowSmsImport();
      }
    });
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.78),
              border: Border(
                top: BorderSide(color: AppColors.divider.withValues(alpha: 0.4)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Home',
                      isSelected: currentIndex == 0,
                      onTap: () => _onNavTap(0),
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Transactions',
                      isSelected: currentIndex == 1,
                      onTap: () => _onNavTap(1),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Chat',
                      isSelected: currentIndex == 2,
                      onTap: () => _onNavTap(2),
                      customIcon: _buildMiniOrb(),
                    ),
                    _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Analysis',
                      isSelected: currentIndex == 3,
                      onTap: () => _onNavTap(3),
                    ),
                    _NavItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isSelected: currentIndex == 4,
                      onTap: () => _onNavTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniOrb() {
    final isConfigured = ref.watch(aiApiKeyProvider).isNotEmpty;
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _orbController,
          child: Container(
            width: 24,
            height: 24,
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
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.7),
              ],
              radius: 0.8,
            ),
          ),
        ),
        Icon(
          isConfigured ? Icons.auto_awesome_rounded : Icons.settings_rounded,
          color: Colors.white,
          size: 12,
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? customIcon;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ?? Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.text.withValues(alpha: 0.35),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/dashboard/views/dashboard_view.dart';
import 'package:smart_wallet/ui/features/entries/views/all_transactions_view.dart';
import 'package:smart_wallet/ui/features/analysis/views/analysis_view.dart';
import 'package:smart_wallet/ui/features/insights/views/insights_view.dart';
import 'package:smart_wallet/ui/features/settings/views/settings_view.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnimController;

  final List<Widget> _screens = const [
    DashboardView(),
    AllTransactionsView(initialShowExpenses: true),
    AnalysisView(),
    InsightsView(),
    SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: 400.ms,
    )..forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _navAnimController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: 250.ms,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
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
                      label: 'Ledger',
                      isSelected: _currentIndex == 0,
                      onTap: () => _onNavTap(0),
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Transactions',
                      isSelected: _currentIndex == 1,
                      onTap: () => _onNavTap(1),
                    ),
                    _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Analysis',
                      isSelected: _currentIndex == 2,
                      onTap: () => _onNavTap(2),
                    ),
                    _NavItem(
                      icon: Icons.lightbulb_rounded,
                      label: 'Insights',
                      isSelected: _currentIndex == 3,
                      onTap: () => _onNavTap(3),
                    ),
                    _NavItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isSelected: _currentIndex == 4,
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
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: 300.ms,
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _scaleCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _scaleCtrl
      ..reset()
      ..forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_scaleAnim.value * 0.08),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: 250.ms,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected
                    ? AppColors.primary
                    : AppColors.text.withValues(alpha: 0.35),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label,
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
      ),
    );
  }
}

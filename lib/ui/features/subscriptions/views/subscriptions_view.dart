import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/data/services/subscription_detection_service.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/category_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Surfaces subscriptions auto-detected from recurring merchants in the user's
/// expense history, with the total monthly cost and price-hike / inactive flags.
class SubscriptionsView extends ConsumerWidget {
  const SubscriptionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(detectedSubscriptionsProvider);
    final categories = {for (final c in (ref.watch(allCategoriesProvider).value ?? [])) c.id: c};
    final symbol = currencySymbol(ref.watch(currencyCodeProvider));

    final active = subs.where((s) => s.isActive).toList();
    final inactive = subs.where((s) => !s.isActive).toList();
    final monthlyTotal = SubscriptionDetectionService.monthlyTotal(subs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscriptions',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.text),
        ),
      ),
      body: subs.isEmpty
          ? _empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _TotalCard(monthlyTotal: monthlyTotal, count: active.length, symbol: symbol),
                const SizedBox(height: 18),
                if (active.isNotEmpty) ...[
                  _label('Active'),
                  const SizedBox(height: 8),
                  ...active.map((s) => _SubTile(sub: s, category: categories[s.categoryId], symbol: symbol)),
                ],
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _label('Inactive / likely cancelled'),
                  const SizedBox(height: 8),
                  ...inactive.map((s) => _SubTile(sub: s, category: categories[s.categoryId], symbol: symbol)),
                ],
                const SizedBox(height: 16),
                _hint(),
              ],
            ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.text.withValues(alpha: 0.5),
          letterSpacing: 0.3,
        ),
      );

  Widget _hint() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: const Text(
          'Subscriptions are detected from repeated charges to the same merchant. '
          'Add the merchant name in an expense note (e.g. "Netflix") so it can be tracked.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.subscriptions_rounded, size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('No subscriptions detected yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text(
                'Once the same merchant is charged a few times on a regular schedule, it will show up here. '
                'Tip: put the merchant name in the expense note.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _TotalCard extends StatelessWidget {
  final double monthlyTotal;
  final int count;
  final String symbol;

  const _TotalCard({required this.monthlyTotal, required this.count, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6F5E), Color(0xFF1E463C)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBSCRIPTIONS PER MONTH',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${monthlyTotal.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            '$count active • about $symbol${(monthlyTotal * 12).toStringAsFixed(0)} a year',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final Subscription sub;
  final domain.Category? category;
  final String symbol;

  const _SubTile({required this.sub, required this.category, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(int.parse(category!.color.replaceAll('#', '0xFF')))
        : AppColors.primary;
    final icon = getCategoryIcon(category?.icon);
    final nextLabel = DateFormat('MMM d').format(sub.nextExpectedDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _titleCase(sub.merchant),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sub.hasPriceHike) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: '↑ ${sub.priceHikePercent.toStringAsFixed(0)}%',
                            color: AppColors.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub.isActive
                          ? '${sub.cadenceLabel} • next $nextLabel'
                          : '${sub.cadenceLabel} • last ${DateFormat('MMM d, yyyy').format(sub.lastChargeDate)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (sub.hasPriceHike) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Was $symbol${sub.previousAmount!.toStringAsFixed(0)}, now $symbol${sub.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.secondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$symbol${sub.monthlyCost.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  const Text('/mo', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

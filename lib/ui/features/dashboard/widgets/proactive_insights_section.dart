import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/proactive_insight.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'section_header.dart';

/// Strip of proactive "Smart Alert" cards driven by [activeInsightsProvider].
class ProactiveInsightsSection extends ConsumerWidget {
  const ProactiveInsightsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(activeInsightsProvider);
    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Smart Alerts',
                action: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${insights.length} active',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...insights.map((insight) {
                return ProactiveInsightCard(
                  key: ValueKey(insight.id),
                  insight: insight,
                  onDismiss: () {
                    final repo = ref.read(proactiveInsightRepositoryProvider);
                    repo.dismissInsight(insight.id);
                  },
                  onAction: () {
                    ref.read(pendingChatMessageProvider.notifier).state =
                        _contextualQuery(insight);
                    ref.read(activeTabIndexProvider.notifier).state = 2;
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Builds a focused, contextual question for the AI chat based on the alert
/// type. The alert's own message is embedded so the assistant has full context.
String _contextualQuery(ProactiveInsight insight) {
  final msg = insight.message;
  final cat = (insight.category?.isNotEmpty ?? false) ? insight.category! : null;
  switch (insight.triggerType) {
    case 'budget_threshold':
      return '$msg Can you break down my ${cat?.toLowerCase() ?? 'spending'} expenses '
          'this month and give me specific ways to stay within budget?';
    case 'large_transaction':
      return '$msg Can you find this expense, compare it to my usual spending, '
          'and tell me if it looks like an anomaly?';
    case 'recurring_detected':
      return '$msg Can you list all my recurring charges'
          '${cat != null ? ' in $cat' : ''} and tell me which ones I could trim?';
    case 'goal_stalled':
      return '$msg What is slowing my savings progress and how can I realistically '
          'catch up to my goal?';
    case 'bill_upcoming':
      return '$msg Show me all my upcoming bills and help me plan my cash flow '
          'for the next few days.';
    case 'spend_forecast':
      return '$msg Based on my daily pace, how much will I spend by month-end '
          'and where should I slow down?';
    case 'savings_streak':
      return '$msg Can you show me my recent zero-spend days and give me '
          'personalised tips to keep the streak going?';
    case 'subscription_summary':
      return '$msg Break down all my detected subscriptions by cost and tell me '
          'which ones are worth keeping.';
    case 'subscription_price_hike':
      return '$msg Which subscription went up, by how much, and is it still '
          'worth the price?';
    default:
      return insight.suggestedAction?.isNotEmpty == true
          ? '${insight.suggestedAction} — context: $msg'
          : '$msg Can you give me deeper insights and actionable advice on this?';
  }
}

class ProactiveInsightCard extends StatefulWidget {
  final ProactiveInsight insight;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const ProactiveInsightCard({
    super.key,
    required this.insight,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  State<ProactiveInsightCard> createState() => _ProactiveInsightCardState();
}

class _ProactiveInsightCardState extends State<ProactiveInsightCard>
    with TickerProviderStateMixin {
  // Slide-in on first appearance
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  // Looping glow shimmer around the border
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  bool _isExpanded = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();

    // Glow sweeps around the border every 12 s (very slow, majestic)
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 12000))
      ..repeat();
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_glowCtrl);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _toneColor {
    switch (widget.insight.tone) {
      case InsightTone.positive:
        return AppColors.primary;
      case InsightTone.caution:
        return AppColors.secondary;
      case InsightTone.neutral:
        return AppColors.textSecondary;
    }
  }

  Color get _toneBg {
    switch (widget.insight.tone) {
      case InsightTone.positive:
        return AppColors.primaryLight;
      case InsightTone.caution:
        return AppColors.secondaryLight;
      case InsightTone.neutral:
        return AppColors.surface;
    }
  }

  IconData get _toneIcon {
    switch (widget.insight.tone) {
      case InsightTone.positive:
        return Icons.emoji_events_rounded;
      case InsightTone.caution:
        return Icons.info_outline_rounded;
      case InsightTone.neutral:
        return Icons.lightbulb_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) {
              return CustomPaint(
                painter: _GlowBorderPainter(
                  progress: _glowAnim.value,
                  borderRadius: radius,
                ),
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: _toneColor.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tone icon
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _toneBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_toneIcon, color: _toneColor, size: 16),
                    ),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: Text(
                              widget.insight.message,
                              maxLines: _isExpanded ? null : 2,
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Text(
                              _isExpanded ? 'See less' : 'See more',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _toneColor,
                              ),
                            ),
                          ),
                          if (widget.insight.actionLabel != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: widget.onAction,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _toneColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _toneColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.insight.actionLabel!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _toneColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 12, color: _toneColor),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Dismiss button
                    GestureDetector(
                      onTap: () {
                        if (_dismissed) return;
                        _dismissed = true;
                        _enterCtrl.reverse();
                        widget.onDismiss();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
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

// ── Glow border painter ───────────────────────────────────────────────────────

/// Sweeping rainbow glare that travels around the card border.
/// Colors are the same AI-orb palette: cyan → blue → purple → pink.
/// [progress] runs 0 → 1 in a loop.
class _GlowBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  // AI-orb sweep gradient colours (matches the dashboard AI card)
  static const List<Color> _aiColors = [
    Color(0xFF00FFC2), // cyan
    Color(0xFF00A3FF), // blue
    Color(0xFFB026FF), // purple
    Color(0xFFFF26A8), // pink
    Color(0xFF00FFC2), // wrap back to cyan
  ];

  const _GlowBorderPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // Only draw the continuous, gently spinning rainbow border
    final sweepShader = SweepGradient(
      colors: _aiColors,
      transform: GradientRotation(progress * 2 * math.pi),
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Main solid border, kept thin and elegant
    final fullBorderPaint = Paint()
      ..shader = sweepShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white;

    canvas.drawRRect(rRect, fullBorderPaint);
  }

  @override
  bool shouldRepaint(_GlowBorderPainter old) => old.progress != progress;
}

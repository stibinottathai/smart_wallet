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
                    // Navigate to AI Assistant tab for all actions
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _toneColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
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
                        Text(
                          widget.insight.message,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.text,
                          ),
                        ),
                        if (widget.insight.actionLabel != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: widget.onAction,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: _toneColor),
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
                      _controller.reverse().then((_) => widget.onDismiss());
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
    );
  }
}

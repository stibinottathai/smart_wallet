import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

class FinancialHealthCard extends ConsumerWidget {
  const FinancialHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(financialHealthScoreProvider);

    return scoreAsync.when(
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
      error: (err, _) => const SizedBox.shrink(),
      data: (score) => _HealthCardContent(score: score),
    );
  }
}

class _HealthCardContent extends StatefulWidget {
  final domain.FinancialHealthScore score;
  const _HealthCardContent({required this.score});

  @override
  State<_HealthCardContent> createState() => _HealthCardContentState();
}

class _HealthCardContentState extends State<_HealthCardContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    final color = _ratingColor(score.totalScore);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Financial Health Score',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Radial gauge
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _GaugePainter(score: score.totalScore, color: color),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                score.totalScore.toStringAsFixed(0),
                                style: GoogleFonts.fraunces(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  height: 1,
                                ),
                              ),
                              Text(
                                score.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (score.previousScore != null)
                            _TrendIndicator(
                              current: score.totalScore,
                              previous: score.previousScore!,
                            ),
                          if (score.monthOverMonthExplanation != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              score.monthOverMonthExplanation!,
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_expanded && score.factors.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  ...score.factors.map((factor) => _FactorRow(factor: factor)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _ratingColor(double s) {
    if (s >= 80) return AppColors.success;
    if (s >= 60) return const Color(0xFF81C784);
    if (s >= 40) return AppColors.textSecondary;
    return AppColors.secondary;
  }
}

class _TrendIndicator extends StatelessWidget {
  final double current;
  final double previous;
  const _TrendIndicator({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final delta = current - previous;
    final isUp = delta >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: isUp ? AppColors.success : AppColors.secondary,
        ),
        const SizedBox(width: 4),
        Text(
          '${isUp ? '+' : ''}${delta.toStringAsFixed(0)} this month',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isUp ? AppColors.success : AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  final domain.HealthScoreFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final pct = factor.score / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                factor.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                '${factor.score.toStringAsFixed(0)}/100',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _barColor(factor.score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.divider.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(_barColor(factor.score)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            factor.description,
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  Color _barColor(double s) {
    if (s >= 80) return AppColors.success;
    if (s >= 60) return const Color(0xFF81C784);
    if (s >= 40) return AppColors.textSecondary;
    return AppColors.secondary;
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

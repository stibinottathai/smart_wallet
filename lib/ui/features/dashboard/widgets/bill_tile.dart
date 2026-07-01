import 'package:flutter/material.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';

/// A single bill row that gently pulses and shifts to a warning (due soon) or
/// danger (overdue) accent as its due date closes in — reusing the same
/// `isOverdue`/`canPay` window that already controls the "Pay Now" button, so
/// the highlight and the actionability always agree.
class BillTile extends StatefulWidget {
  final domain.Bill bill;
  final Color catColor;
  final IconData iconData;
  final String dueLabel;
  final String symbol;
  final bool isOverdue;
  final bool canPay;
  final VoidCallback onTap;
  final VoidCallback onPay;

  const BillTile({
    super.key,
    required this.bill,
    required this.catColor,
    required this.iconData,
    required this.dueLabel,
    required this.symbol,
    required this.isOverdue,
    required this.canPay,
    required this.onTap,
    required this.onPay,
  });

  @override
  State<BillTile> createState() => _BillTileState();
}

class _BillTileState extends State<BillTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  // `canPay` already implies `isOverdue` (see the callers' canPay switch), so
  // this alone captures "close enough to due to matter".
  bool get _isUrgent => widget.canPay;
  Color get _urgencyColor =>
      widget.isOverdue ? AppColors.error : AppColors.secondary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_isUrgent) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BillTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isUrgent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_isUrgent) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _urgencyColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _isUrgent ? _pulseController.value : 0.0;
          return Card(
            margin: EdgeInsets.zero,
            color: _isUrgent
                ? Color.lerp(
                    AppColors.card,
                    urgencyColor.withValues(alpha: 0.08),
                    1,
                  )
                : AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: _isUrgent
                  ? BorderSide(
                      color: urgencyColor.withValues(
                        alpha: 0.22 + 0.28 * pulse,
                      ),
                      width: 1.4,
                    )
                  : BorderSide.none,
            ),
            child: child,
          );
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = _isUrgent ? _pulseController.value : 0.0;
                    final avatarColor = _isUrgent
                        ? urgencyColor
                        : widget.catColor;
                    return Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: avatarColor.withValues(
                          alpha: _isUrgent ? 0.14 + 0.1 * pulse : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isUrgent
                            ? [
                                BoxShadow(
                                  color: urgencyColor.withValues(
                                    alpha: 0.35 * pulse,
                                  ),
                                  blurRadius: 10 * pulse,
                                  spreadRadius: 0.5 * pulse,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        widget.iconData,
                        color: avatarColor,
                        size: 18,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bill.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (_isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isOverdue
                                    ? Icons.error_rounded
                                    : Icons.access_time_filled_rounded,
                                size: 11,
                                color: urgencyColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                widget.dueLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: urgencyColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          widget.dueLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.symbol}${widget.bill.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.bill.frequency.displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (widget.canPay) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onPay,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor: urgencyColor.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: urgencyColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

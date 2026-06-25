import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/core/theme.dart';

/// A row of dots representing the entered PIN digits.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = error ? AppColors.error : AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? activeColor : Colors.transparent,
            border: Border.all(
              color: isFilled ? activeColor : AppColors.divider,
              width: 1.6,
            ),
          ),
        );
      }),
    );
  }
}

/// A numeric keypad (0-9, optional biometric key, delete). Reports taps via
/// [onDigit], [onDelete] and [onBiometric].
class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _digitKey(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bottom-left: biometric shortcut or an empty spacer.
            onBiometric != null
                ? _iconKey(Icons.fingerprint_rounded, onBiometric!,
                    color: AppColors.primary)
                : const SizedBox(width: 78, height: 78),
            _digitKey('0'),
            _iconKey(Icons.backspace_outlined, onDelete),
          ],
        ),
      ],
    );
  }

  Widget _digitKey(String digit) {
    return _KeyButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap, {Color? color}) {
    return _KeyButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Icon(icon, size: 24, color: color ?? AppColors.textSecondary),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _KeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 66,
            height: 66,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

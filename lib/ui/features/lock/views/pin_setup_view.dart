import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/data/services/app_lock_service.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/lock/widgets/pin_pad.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Two-step flow to set (or change) the app-lock PIN: enter a new PIN, then
/// confirm it. Pops `true` once the PIN has been saved, `false`/null if
/// cancelled. On completion the lock is enabled in [AppLockService].
class PinSetupView extends ConsumerStatefulWidget {
  const PinSetupView({super.key});

  @override
  ConsumerState<PinSetupView> createState() => _PinSetupViewState();
}

enum _Step { create, confirm }

class _PinSetupViewState extends ConsumerState<PinSetupView> {
  _Step _step = _Step.create;
  final List<String> _entered = [];
  String? _firstPin;
  bool _error = false;
  String? _errorText;

  void _onDigit(String d) {
    if (_entered.length >= AppLockService.pinLength) return;
    setState(() {
      _error = false;
      _errorText = null;
      _entered.add(d);
    });
    if (_entered.length == AppLockService.pinLength) {
      _onComplete();
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered.removeLast());
  }

  Future<void> _onComplete() async {
    final pin = _entered.join();
    if (_step == _Step.create) {
      setState(() {
        _firstPin = pin;
        _entered.clear();
        _step = _Step.confirm;
      });
      return;
    }

    // Confirm step
    if (pin != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _errorText = "PINs didn't match. Start again.";
        _entered.clear();
        _firstPin = null;
        _step = _Step.create;
      });
      return;
    }

    await ref.read(appLockServiceProvider).setPin(pin);
    ref.read(appLockEnabledProvider.notifier).state = true;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _step == _Step.create;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Lock'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCreate
                      ? Icons.pin_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 30,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isCreate ? 'Create a PIN' : 'Confirm your PIN',
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorText ??
                    (isCreate
                        ? 'Choose a ${AppLockService.pinLength}-digit PIN to secure the app'
                        : 'Re-enter your PIN to confirm'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: _error ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              PinDots(
                length: AppLockService.pinLength,
                filled: _entered.length,
                error: _error,
              ),
              const Spacer(flex: 3),
              PinPad(onDigit: _onDigit, onDelete: _onDelete),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

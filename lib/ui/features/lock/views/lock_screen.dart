import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/data/services/app_lock_service.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/lock/widgets/pin_pad.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Full-screen lock shown when the app is protected. Verifies a PIN and, when
/// enabled, offers a biometric shortcut that is also auto-triggered on show.
///
/// Used both as the launch/resume gate (via AppLockGate) and as an identity
/// re-check before sensitive settings changes (with [showCancel] = true).
class LockScreen extends ConsumerStatefulWidget {
  /// Called once the user successfully authenticates.
  final VoidCallback onUnlocked;

  /// When true, shows a cancel affordance (used for the settings re-auth flow).
  final bool showCancel;

  final String title;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    this.showCancel = false,
    this.title = 'Enter your PIN',
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _entered = [];
  bool _error = false;
  bool _biometricAvailable = false;
  bool _biometricTried = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;

  AppLockService get _service => ref.read(appLockServiceProvider);

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear);
    _maybeStartBiometric();
  }

  Future<void> _maybeStartBiometric() async {
    if (!ref.read(biometricEnabledProvider)) return;
    final available = await _service.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available && !_biometricTried) {
      _biometricTried = true;
      _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    final ok = await _service.authenticateBiometric();
    if (!mounted) return;
    if (ok) widget.onUnlocked();
  }

  void _onDigit(String d) {
    if (_entered.length >= AppLockService.pinLength) return;
    setState(() {
      if (_error) _error = false;
      _entered.add(d);
    });
    if (_entered.length == AppLockService.pinLength) {
      _verify();
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered.removeLast());
  }

  Future<void> _verify() async {
    final pin = _entered.join();
    final ok = await _service.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _entered.clear();
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (widget.showCancel)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).maybePop(false),
                  ),
                )
              else
                const SizedBox(height: 24),
              const Spacer(flex: 2),
              // Lock badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Smart Wallet',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error ? 'Incorrect PIN, try again' : widget.title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: _error ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  // Damped horizontal shake: a few oscillations that decay to 0.
                  final dx = _shake.value == 0
                      ? 0.0
                      : 12 *
                          (1 - _shake.value) *
                          math.sin(_shake.value * math.pi * 4);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: PinDots(
                  length: AppLockService.pinLength,
                  filled: _entered.length,
                  error: _error,
                ),
              ),
              const Spacer(flex: 3),
              PinPad(
                onDigit: _onDigit,
                onDelete: _onDelete,
                onBiometric: _biometricAvailable ? _authenticateBiometric : null,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/ui/core/navigation.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/features/lock/views/lock_screen.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Root gate that sits above [MainNavigationWrapper]. When the app lock is
/// enabled it shows a [LockScreen] on first launch and re-locks whenever the
/// app returns from the background, so the ledger is never visible without
/// authentication.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _initialized = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hydrate();
  }

  Future<void> _hydrate() async {
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isLockEnabled() && await service.hasPin();
    final biometric = await service.isBiometricEnabled();
    if (!mounted) return;
    ref.read(appLockEnabledProvider.notifier).state = enabled;
    ref.read(biometricEnabledProvider.notifier).state = biometric;
    setState(() {
      _initialized = true;
      _locked = enabled;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-arm the lock when the app is backgrounded so the next resume requires
    // authentication. The actual prompt is handled by the LockScreen on show.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (ref.read(appLockEnabledProvider) && !_locked) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(backgroundColor: AppColors.background);
    }
    return Stack(
      children: [
        const MainNavigationWrapper(),
        if (_locked)
          LockScreen(onUnlocked: () => setState(() => _locked = false)),
      ],
    );
  }
}

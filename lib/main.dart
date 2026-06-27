import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/core/currency_utils.dart';
import 'ui/core/theme.dart';
import 'ui/features/onboarding/onboarding_prefs.dart';
import 'ui/features/splash/splash_screen.dart';
import 'ui/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the app to portrait — no landscape/horizontal layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await loadCurrencyPref();
  await loadAiSettingsPref();
  await loadOnboardingPref();
  // NOTE: notification setup (which triggers the permission dialog) is
  // intentionally NOT awaited here. Doing it before runApp showed the system
  // permission prompt over a black screen. It now runs after the splash is
  // painted — see SplashScreen.initState.
  runApp(
    const ProviderScope(
      child: SmartWalletApp(),
    ),
  );
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Wallet',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

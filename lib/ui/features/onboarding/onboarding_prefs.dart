import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has already seen the one-time onboarding flow.
/// Mirrors the cached-flag pattern used by `currency_utils.dart` so the splash
/// screen can branch synchronously after [loadOnboardingPref] runs in `main`.
const _onboardingSeenKey = 'onboarding_completed_v1';

bool _onboardingSeen = false;

/// Whether onboarding has already been completed on this device.
bool get onboardingSeen => _onboardingSeen;

/// Loads the persisted flag. Call once during app startup.
Future<void> loadOnboardingPref() async {
  final prefs = await SharedPreferences.getInstance();
  _onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
}

/// Marks onboarding as completed so it never shows again.
Future<void> markOnboardingSeen() async {
  _onboardingSeen = true;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingSeenKey, true);
}

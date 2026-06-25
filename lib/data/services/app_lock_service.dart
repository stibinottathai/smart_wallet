import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles the app-lock feature: a salted-SHA-256 PIN stored in the platform
/// keystore/keychain, optional biometric unlock, and the on/off preference
/// flags. All persistence is local — no PIN ever leaves the device.
class AppLockService {
  /// Number of digits a PIN must contain.
  static const pinLength = 4;

  static const lockEnabledKey = 'app_lock_enabled';
  static const biometricEnabledKey = 'app_lock_biometric_enabled';
  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';

  final FlutterSecureStorage _secure;
  final LocalAuthentication _localAuth;

  AppLockService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  // ── Preference flags (non-secret) ─────────────────────────────────────────

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(lockEnabledKey) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(biometricEnabledKey, value);
  }

  // ── PIN management ─────────────────────────────────────────────────────────

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _newSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Whether a PIN has been set on this device.
  Future<bool> hasPin() async => (await _secure.read(key: _pinHashKey)) != null;

  /// Stores a new salted PIN hash and turns the lock on.
  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _secure.write(key: _pinSaltKey, value: salt);
    await _secure.write(key: _pinHashKey, value: _hash(pin, salt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(lockEnabledKey, true);
  }

  /// Constant-ish comparison of [pin] against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final salt = await _secure.read(key: _pinSaltKey);
    final hash = await _secure.read(key: _pinHashKey);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  /// Turns the lock off and wipes the stored PIN + biometric preference.
  Future<void> disableLock() async {
    await _secure.delete(key: _pinHashKey);
    await _secure.delete(key: _pinSaltKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(lockEnabledKey, false);
    await prefs.setBool(biometricEnabledKey, false);
  }

  // ── Biometrics ─────────────────────────────────────────────────────────────

  /// True when the device has hardware + at least one enrolled biometric.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for biometric authentication. Returns true only on success.
  Future<bool> authenticateBiometric({
    String reason = 'Unlock Smart Wallet',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

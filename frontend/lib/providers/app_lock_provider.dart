import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockState { initializing, needsSetup, locked, unlocked }

class AppLockProvider with ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppLockState _state = AppLockState.initializing;
  bool _biometricAvailable = false;
  String? _error;

  AppLockState get state => _state;
  bool get isUnlocked => _state == AppLockState.unlocked;
  bool get needsSetup => _state == AppLockState.needsSetup;
  bool get isInitializing => _state == AppLockState.initializing;
  bool get biometricAvailable => _biometricAvailable;
  String? get error => _error;

  static const _pinKey = 'app_lock_pin_hash';
  static const _salt = 'bonded_pair_salt_v1';

  Future<void> initialize() async {
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      _biometricAvailable = false;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasPIN = prefs.containsKey(_pinKey);
    _state = hasPIN ? AppLockState.locked : AppLockState.needsSetup;
    notifyListeners();
  }

  Future<void> setupPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hash(pin));
    _state = AppLockState.unlocked;
    _error = null;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey) ?? '';
    if (_hash(pin) == stored) {
      _state = AppLockState.unlocked;
      _error = null;
      notifyListeners();
      return true;
    }
    _error = 'Wrong code. Try again.';
    notifyListeners();
    return false;
  }

  Future<bool> tryBiometric() async {
    if (!_biometricAvailable) return false;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock to access your private chat',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) {
        _state = AppLockState.unlocked;
        _error = null;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void lock() {
    _state = AppLockState.locked;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  String _hash(String pin) {
    final bytes = utf8.encode('$_salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

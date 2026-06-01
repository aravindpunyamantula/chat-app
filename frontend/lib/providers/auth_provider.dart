import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../core/network/api_client.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authRepository) {
    _tryAutoLogin();

    ApiClient.onAuthenticationRequired = () {
      _currentUser = null;
      notifyListeners();
    };
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _authRepository.getProfile();
    } catch (e) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? profileImage,
  }) async {
    _setLoading(true);
    _clearErrors();
    try {
      _currentUser = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        profileImage: profileImage,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _clearErrors();
    try {
      _currentUser = await _authRepository.login(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearErrors() {
    _errorMessage = null;
  }
}

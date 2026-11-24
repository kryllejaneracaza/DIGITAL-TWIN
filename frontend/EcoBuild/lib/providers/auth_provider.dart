import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  Map<String, dynamic>? _user;
  bool _isLoading = true;

  Map<String, dynamic>? get user => _user;

  bool get isAuthenticated => _user != null;

  bool get isLoading => _isLoading;

  AuthProvider({required this._authService}) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      _user = await _authService.getCurrentUser();
    } catch (e) {
      debugPrint('Session Restore Error: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _user = await _authService.login(email, password);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login Error: $e');
      return false;
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    try {
      _user = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Signup Error: $e');
      return e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('Logout Error: $e');
    } finally {
      _user = null;
      notifyListeners();
    }
  }
}

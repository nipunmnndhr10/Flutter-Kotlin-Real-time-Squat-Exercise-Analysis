import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final isLoggedIn = await _authService.isLoggedIn();
    
    if (isLoggedIn) {
      final userData = await _authService.getUserData();
      _user = User(
        userId: userData['userId'] ?? 0,
        name: userData['name'] ?? '',
        email: userData['email'] ?? '',
        token: userData['token'],
      );
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.login(email, password);
      
      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // In lib/providers/auth_provider.dart

Future<Map<String, dynamic>> signup(String name, String email, String password) async {
  _isLoading = true;
  notifyListeners();

  final result = await _apiService.signup(name, email, password);
  
  _isLoading = false;
  notifyListeners();
  
  // ✅ Result already contains the user data
  return result;
}

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
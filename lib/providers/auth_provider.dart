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
    print('🔵 AuthProvider.checkAuthStatus() called');
    _isLoading = true;
    notifyListeners();

    final isLoggedIn = await _authService.isLoggedIn();
    print('🔵 isLoggedIn: $isLoggedIn');
    
    if (isLoggedIn) {
      final userData = await _authService.getUserData();
      _user = User(
        userId: userData['userId'] ?? 0,
        name: userData['name'] ?? '',
        email: userData['email'] ?? '',
        token: userData['token'],
      );
      _isAuthenticated = true;
      print('✅ User restored: ${_user?.name}');
    } else {
      _isAuthenticated = false;
      print('🔵 No user logged in');
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  Future<bool> login(String email, String password) async {
    print('🔵 AuthProvider.login() called');
    _isLoading = true;
    notifyListeners();

    try {
      print('🔵 Calling _apiService.login()...');
      final result = await _apiService.login(email, password);
      print('🔵 Result: ${result['success']}');
      
      if (result['success']) {
        _user = result['user'];
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        print('✅ Login successful: ${_user?.name}');
        return true;
      } else {
        print('❌ Login failed: ${result['error']}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Exception in login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    print('🔵 AuthProvider.signup() called');
    _isLoading = true;
    notifyListeners();

    final result = await _apiService.signup(name, email, password);
    print('🔵 signup result: ${result['success']}');
    
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    print('🔵 AuthProvider.logout() called');
    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
    print('✅ Logout complete');
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
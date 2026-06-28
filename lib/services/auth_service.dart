import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  Future<void> saveUserData({
  required String token,
  required int userId,
  required String name,      // ✅ Name is saved
  required String email,
}) async {
  await _secureStorage.write(key: _tokenKey, value: token);
  await _secureStorage.write(key: _userIdKey, value: userId.toString());
  await _secureStorage.write(key: _userNameKey, value: name);  // ✅ Name stored
  await _secureStorage.write(key: _userEmailKey, value: email);
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_logged_in', true);
}

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<Map<String, dynamic>> getUserData() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final userId = await _secureStorage.read(key: _userIdKey);
    final name = await _secureStorage.read(key: _userNameKey);
    final email = await _secureStorage.read(key: _userEmailKey);
    
    return {
      'token': token,
      'userId': userId != null ? int.parse(userId) : null,
      'name': name,
      'email': email,
    };
  }

  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearUserData() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userEmailKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
  }
}
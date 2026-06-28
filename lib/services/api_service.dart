import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/auth_service.dart';

class ApiService {

  static const String baseUrl = 'https://hydrated-dweeb-dribble.ngrok-free.dev/api';

  final http.Client _client = http.Client();
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',     // ← Added here (Global)
    };
    
    if (withAuth) {
      final token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true, 
          'data': data,
          'userId': data['userId'],
          'name': data['name'],
          'email': data['email'],
        };
      } else {
        final error = data['detail']?['error'] ?? data['error'] ?? 'Signup failed';
        return {'success': false, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        final user = User(
          userId: data['user_id'],
          name: data['name'],
          email: data['email'],
          token: data['token'],
        );
        
        await _authService.saveUserData(
          token: user.token!,
          userId: user.userId,
          name: user.name,
          email: user.email,
        );
        
        return {'success': true, 'user': user};
      } else {
        final error = data['detail']?['error'] ?? data['error'] ?? 'Login failed';
        return {'success': false, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<void> logout() async {
    await _authService.clearUserData();
  }

  void dispose() {
    _client.close();
  }
}
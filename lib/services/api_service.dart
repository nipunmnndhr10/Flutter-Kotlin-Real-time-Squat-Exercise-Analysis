import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'auth_service.dart';

class ApiService {
  // CHANGE THIS TO YOUR URL
  static const String baseUrl = 'http://192.168.18.197:8080/api';

  final http.Client _client = http.Client();
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    
    if (withAuth) {
      final token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }

  // ==================== SIGNUP ====================
  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    print('🔵 SIGNUP STARTED');
    print('🔵 URL: $baseUrl/auth/signup');
    
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('🔵 RESPONSE STATUS: ${response.statusCode}');
      print('🔵 RAW RESPONSE: ${response.body}');

      if (response.body.startsWith('<!DOCTYPE') || response.body.startsWith('<html')) {
        print('🔴 Server returned HTML instead of JSON');
        return {
          'success': false, 
          'error': 'Server error. Please check backend logs.'
        };
      }

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Server returned empty response'};
      }

      final data = jsonDecode(response.body);
      print('🔵 PARSED DATA: $data');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
          'userId': data['userId'],
          'name': data['name'],
          'email': data['email'],
        };
      } else {
        final error = data['detail']?['error'] ?? data['error'] ?? data['detail'] ?? 'Signup failed';
        return {'success': false, 'error': error};
      }

    } on TimeoutException catch (e) {
      print('🔴 TIMEOUT: $e');
      return {'success': false, 'error': 'Request timed out. Please try again.'};
    } on SocketException catch (e) {
      print('🔴 SOCKET ERROR: $e');
      return {'success': false, 'error': 'Cannot connect to server. Make sure backend is running.'};
    } on FormatException catch (e) {
      print('🔴 FORMAT ERROR: $e');
      print('🔴 Response body was: ${e.source}');
      return {'success': false, 'error': 'Server returned invalid response format.'};
    } catch (e) {
      print('🔴 ERROR: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== LOGIN ====================
  Future<Map<String, dynamic>> login(String email, String password) async {
    print('🔵 LOGIN STARTED');
    print('🔵 URL: $baseUrl/auth/login');
    
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('🔵 RESPONSE STATUS: ${response.statusCode}');
      print('🔵 RAW RESPONSE: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Server returned empty response'};
      }

      final data = jsonDecode(response.body);
      print('🔵 PARSED DATA: $data');

      if (response.statusCode == 200) {
        if (data['user_id'] == null || data['token'] == null) {
          return {'success': false, 'error': 'Missing user_id or token in response'};
        }

        final user = User(
          userId: data['user_id'],
          name: data['name'] ?? 'User',
          email: data['email'] ?? email,
          token: data['token'],
        );
        
        await _authService.saveUserData(
          token: user.token!,
          userId: user.userId,
          name: user.name,
          email: user.email,
        );
        
        print('✅ Login successful: ${user.name}');
        return {'success': true, 'user': user};
      } else {
        final error = data['detail']?['error'] ?? data['error'] ?? data['detail'] ?? 'Login failed';
        print('❌ Login failed: $error');
        return {'success': false, 'error': error};
      }

    } on TimeoutException catch (e) {
      print('🔴 TIMEOUT: $e');
      return {'success': false, 'error': 'Request timed out. Please try again.'};
    } on SocketException catch (e) {
      print('🔴 SOCKET ERROR: $e');
      return {'success': false, 'error': 'Cannot connect to server. Make sure backend is running.'};
    } on FormatException catch (e) {
      print('🔴 FORMAT ERROR: $e');
      print('🔴 Response body was: ${e.source}');
      return {'success': false, 'error': 'Server returned invalid response format.'};
    } catch (e) {
      print('🔴 ERROR: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    await _authService.clearUserData();
  }

  // ==================== SAVE WORKOUT ====================
  Future<Map<String, dynamic>> saveWorkout({
  required int userId,
  required String squatType,
  required int totalReps,
  double? formScore,
  Map<String, dynamic>? faults,  // ← ADD THIS PARAMETER
}) async {
  print('🔵 SAVING WORKOUT');
  print('🔵 URL: $baseUrl/workout/save');
  print('🔵 faults being sent: $faults');  // ← DEBUG
  
  try {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/workout/save'),
          headers: await _getHeaders(withAuth: true),
          body: jsonEncode({
            'user_id': userId,
            'squat_type': squatType,
            'total_reps': totalReps,
            'form_score': formScore,
            'faults': faults,  // ← SEND FAULTS
          }),
        )
        .timeout(const Duration(seconds: 15));

    print('🔵 RESPONSE STATUS: ${response.statusCode}');
    print('🔵 RAW RESPONSE: ${response.body}');

    if (response.body.isEmpty) {
      return {'success': false, 'error': 'Server returned empty response'};
    }

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true, 'data': data};
    } else {
      final error = data['detail']?['error'] ?? data['error'] ?? 'Failed to save workout';
      return {'success': false, 'error': error};
    }

  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Request timed out'};
  } on SocketException catch (e) {
    return {'success': false, 'error': 'Cannot connect to server'};
  } catch (e) {
    return {'success': false, 'error': 'Network error: ${e.toString()}'};
  }
}

  // ==================== GET WORKOUT HISTORY ====================
  Future<Map<String, dynamic>> getWorkoutHistory(int userId) async {
    print('🔵 GET WORKOUT HISTORY');
    print('🔵 URL: $baseUrl/workout/history/$userId');
    
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/workout/history/$userId'),
            headers: await _getHeaders(withAuth: true),
          )
          .timeout(const Duration(seconds: 15));

      print('🔵 RESPONSE STATUS: ${response.statusCode}');
      print('🔵 RAW RESPONSE: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Server returned empty response'};
      }

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        List<dynamic> history = [];
        if (data is List) {
          history = data;
        }
        return {'success': true, 'history': history};
      } else {
        final error = data['detail']?['error'] ?? data['error'] ?? 'Failed to fetch history';
        return {'success': false, 'error': error};
      }

    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Request timed out.'};
    } on SocketException catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    } on FormatException catch (e) {
      return {'success': false, 'error': 'Invalid response format.'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  void dispose() {
    _client.close();
  }
}
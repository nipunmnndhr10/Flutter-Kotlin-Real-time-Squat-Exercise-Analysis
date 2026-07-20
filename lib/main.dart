import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.enableNativePreview = true});

  final bool enableNativePreview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SquatMate',
      theme: ThemeData.light(useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  Future<Widget> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    final user = await checkCurrentUser(token);

    // if user exists
    if (user != null) {
      final userName = user['full_name'] ?? 'User';
      return DashboardScreen(userName: userName);
    }

    // if user does not exist or token is expired/invalid
    await prefs.remove('access_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    return const LoginScreen();
  }

  Future<Map<String, dynamic>?> checkCurrentUser(String token) async {
    try {
      final response = await Dio().get(
        '$kApiBaseUrl/auth/me',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }

      return null;
    } catch (e) {
      // Return null on any error (network failure, 401 Unauthorized, etc.)
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkSession(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}

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

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<Widget> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _checkSession();
  }

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
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final response = await dio.get(
        '$kApiBaseUrl/auth/me',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }

      return null;
    } catch (e) {
      // Return null on any error (network failure, 401 Unauthorized, timeout, etc.)
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
            ),
          );
        }

        return snapshot.data!;
      },
    );
  }
}

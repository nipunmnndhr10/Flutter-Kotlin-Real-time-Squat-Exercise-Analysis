import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loginscreen.dart';
<<<<<<< HEAD
import 'dashboard_screen.dart';  // ← Local import
import 'app_config.dart';
=======
import 'dashboard_screen.dart';
//import 'pose_screen.dart';
>>>>>>> main

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

<<<<<<< HEAD
=======
  // Future<Map<String, String?>> _loadSession() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   return {
  //     'token': prefs.getString('access_token'),
  //     'userName': prefs.getString('user_name'),
  //   };
  // }

>>>>>>> main
  Future<Widget> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    final user = await checkCurrentUser(token);

<<<<<<< HEAD
=======
    // if user exists
>>>>>>> main
    if (user != null) {
      final userName = user['full_name'] ?? 'User';
      return DashboardScreen(userName: userName);
    }

<<<<<<< HEAD
=======
    // if user does not exist or token is expired/invalid
>>>>>>> main
    await prefs.remove('access_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    return const LoginScreen();
  }

  Future<Map<String, dynamic>?> checkCurrentUser(String token) async {
<<<<<<< HEAD
    try {
      final response = await Dio().get(
        '${AppConfig.apiBaseUrl}/auth/me',  // ← Uses AppConfig
=======
    print("TOKEN SENT: \n $token");

    try {
      final response = await Dio().get(
        'http://192.168.1.3:8000/auth/me',
>>>>>>> main
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
<<<<<<< HEAD
=======

>>>>>>> main
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return null;
      }
<<<<<<< HEAD
=======

>>>>>>> main
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
<<<<<<< HEAD
=======

>>>>>>> main
        return snapshot.data!;
      },
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> main

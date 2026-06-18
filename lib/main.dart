import 'package:flutter/material.dart';
import 'loginscreen.dart';
//import 'pose_screen.dart';

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
      title: 'Live Pose Tracking',
      theme: ThemeData.light(useMaterial3: true),
      home: LoginScreen(),
    );
  }
}

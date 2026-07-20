// lib/app_config.dart
class AppConfig {
  // For development - change this when your IP changes
  static const String apiBaseUrl = 'http://192.168.1.8:8000';
  
  // For production - use this when deployed
  // static const String apiBaseUrl = 'https://your-production-url.com';
  
  // For emulator (Android)
  // static const String apiBaseUrl = 'http://10.0.2.2:8000';
  
  // For iOS simulator
  // static const String apiBaseUrl = 'http://localhost:8000';
}
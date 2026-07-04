import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';

class KotlinService {
  static const MethodChannel _channel = MethodChannel('com.squatapp.squat_channel');
  
  final ApiService _apiService = ApiService();

  // ==================== START DETECTION ====================
  Future<bool> startSquatDetection() async {
    print('🔵 startSquatDetection called');
    try {
      final result = await _channel.invokeMethod('startSquatDetection');
      print('🔵 Result: $result');
      return result != null && result['status'] == 'started';
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // ==================== STOP DETECTION ====================
Future<Map<String, dynamic>?> stopSquatDetection() async {
  print('🔵 stopSquatDetection called');
  try {
    final result = await _channel.invokeMethod('stopSquatDetection');
    print('🔵 Raw result type: ${result.runtimeType}');
    print('🔵 Raw result: $result');

    if (result == null) {
      print('⚠️ Result is null');
      return null;
    }

    if (result is! Map) {
      print('⚠️ Result is not a Map');
      return null;
    }

    // More robust conversion
    final Map<String, dynamic> safeMap = {};
    
    (result as Map).forEach((key, value) {
      if (key != null) {
        safeMap[key.toString()] = value;
      }
    });

    print('🔵 Successfully converted to Map<String, dynamic>');
    print('🔵 Final data: $safeMap');
    return safeMap;

  } on PlatformException catch (e) {
    print('❌ PlatformException: ${e.message}');
    return null;
  } catch (e, stack) {
    print('❌ Unexpected error: $e');
    print(stack);
    return null;
  }
}

  // ==================== GET WORKOUT DATA ====================
  Future<Map<String, dynamic>?> getWorkoutData() async {
    print('🔵 getWorkoutData called');
    try {
      final result = await _channel.invokeMethod('getWorkoutData');
      print('🔵 Raw result type: ${result.runtimeType}');
      print('🔵 Raw result: $result');
      
      if (result == null) {
        print('⚠️ Result is null');
        return null;
      }
      
      if (result is! Map) {
        print('⚠️ Result is not a Map');
        return null;
      }
      
      final Map<String, dynamic> converted = Map.castFrom<dynamic, dynamic, String, dynamic>(result);
      print('🔵 Converted type: ${converted.runtimeType}');
      print('🔵 Converted data: $converted');
      return converted;
      
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }

  // ==================== RESET ENGINE ====================
  Future<bool> resetSquatEngine() async {
    print('🔵 resetSquatEngine called');
    try {
      final result = await _channel.invokeMethod('resetSquatEngine');
      return result != null && result['status'] == 'reset';
    } on PlatformException catch (e) {
      print('❌ Failed to reset: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // ==================== SET SQUAT TYPE ====================
  Future<bool> setSquatType(String type) async {
    print('🔵 Setting squat type: $type');
    try {
      await _channel.invokeMethod('setSquatType', type);
      print('✅ Squat type set to: $type');
      return true;
    } on PlatformException catch (e) {
      print('❌ Failed to set squat type: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // ==================== SAVE WORKOUT TO BACKEND ====================
  Future<Map<String, dynamic>> saveWorkoutToBackend(
    BuildContext context,
    Map<String, dynamic> workoutData,
  ) async {
    print('🔵 saveWorkoutToBackend called');
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user == null) {
        print('❌ User not logged in');
        return {'success': false, 'error': 'User not logged in'};
      }
      
      final result = await _apiService.saveWorkout(
        userId: user.userId,
        squatType: workoutData['squatType'] ?? 'STANDARD',
        totalReps: workoutData['totalReps'] ?? 0,
        formScore: workoutData['formScore']?.toDouble(),
      );
      
      print('🔵 Save result: $result');
      return result;
      
    } catch (e) {
      print('❌ Error saving workout: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _apiService.dispose();
  }
}
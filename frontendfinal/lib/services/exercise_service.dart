import 'api_client.dart';

class ExerciseService {
  static Future<Map<String, dynamic>> getTodayExercises() async {
    return await ApiClient.get('/exercise/today');
  }

  static Future<Map<String, dynamic>> getExercisePlan() async {
    return await ApiClient.get('/exercise/plan');
  }

  static Future<Map<String, dynamic>> logExercise({
    required String workoutName,
    required int durationMinutes,
    required double caloriesBurned,
    String intensity = 'Moderate',
  }) async {
    return await ApiClient.post('/exercise/log', {
      'workoutName': workoutName,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'intensity': intensity,
    });
  }
}
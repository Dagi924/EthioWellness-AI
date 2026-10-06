import 'api_client.dart';

class NutritionistService {
  static Future<List<dynamic>> getNutritionists() async {
    final res = await ApiClient.get('/supervision/nutritionists');
    return res['nutritionists'] ?? [];
  }

  static Future<Map<String, dynamic>> bookAppointment({
    required String nutritionistId,
    required String scheduledAt,
    String? notes,
  }) async {
    return await ApiClient.post('/supervision/appointments', {
      'nutritionistId': nutritionistId,
      'scheduledAt': scheduledAt,
      'notes': notes ?? '',
    });
  }

  static Future<List<dynamic>> getAppointments() async {
    final res = await ApiClient.get('/supervision/appointments');
    return res['appointments'] ?? [];
  }

  static Future<List<dynamic>> getMessages(String nutritionistId) async {
    final res = await ApiClient.get('/supervision/messages/$nutritionistId');
    return res['messages'] ?? [];
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String nutritionistId,
    required String message,
  }) async {
    return await ApiClient.post('/supervision/messages', {
      'nutritionistId': nutritionistId,
      'message': message,
    });
  }
}
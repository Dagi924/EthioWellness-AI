
import 'api_client.dart';

class MoodService {
  static Future<Map<String, dynamic>> saveMood({
    required String mood,
    required int moodScore,
    String? note,
  }) async {
    return await ApiClient.post('/mood/log', {
      'mood': mood,
      'moodScore': moodScore,
      if (note != null && note.trim().isNotEmpty)
        'note': note.trim(),
    });
  }

  static Future<List<Map<String, dynamic>>> getTodayMood() async {
    final response = await ApiClient.get('/mood/today');

    final logs = response['logs'];

    if (logs is! List) {
      return [];
    }

    return logs
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMoodLogs() async {
    final response = await ApiClient.get('/mood/logs');

    final logs = response['logs'];

    if (logs is! List) {
      return [];
    }

    return logs
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  static Future<void> deleteMood(String id) async {
    await ApiClient.delete('/mood/log/$id');
  }
}

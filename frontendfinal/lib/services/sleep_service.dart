import 'api_client.dart';

class SleepService {
  static Future<Map<String, dynamic>> saveSleep({
    required String sleepDate,
    required DateTime bedtime,
    required DateTime wakeTime,
    required int durationMinutes,
    int quality = 3,
    String? notes,
  }) async {
    return await ApiClient.post('/sleep/log', {
      'sleepDate': sleepDate,
      'bedtime': bedtime.toIso8601String(),
      'wakeTime': wakeTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'quality': quality,
      if (notes != null && notes.trim().isNotEmpty)
        'notes': notes.trim(),
    });
  }

  static Future<Map<String, dynamic>?> getTodaySleep() async {
    final response = await ApiClient.get('/sleep/today');

    if (response['log'] == null) {
      return null;
    }

    return Map<String, dynamic>.from(response['log']);
  }

  static Future<List<Map<String, dynamic>>> getSleepLogs() async {
    final response = await ApiClient.get('/sleep/logs');

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

  static Future<void> deleteSleep(String id) async {
    await ApiClient.delete('/sleep/log/$id');
  }

  static int calculateDurationMinutes(
    DateTime bedtime,
    DateTime wakeTime,
  ) {
    var difference = wakeTime.difference(bedtime);

    if (difference.isNegative) {
      difference += const Duration(days: 1);
    }

    return difference.inMinutes;
  }

  static String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }
}
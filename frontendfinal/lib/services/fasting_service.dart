import 'api_client.dart';
import '../models/fasting_schedule_model.dart';

class FastingService {
  /// GET /api/v1/fasting/today
  static Future<FastingScheduleModel> getTodayFasting() async {
    final res = await ApiClient.get('/fasting/today');
    return FastingScheduleModel.fromJson(res);
  }

  /// GET /api/v1/fasting/calendar?month=10&year=2026
  static Future<Map<String, dynamic>> getMonthlyCalendar(int year, int month) async {
    final res = await ApiClient.get('/fasting/calendar?month=$month&year=$year');
    return {
      'fastingDays': List<int>.from(res['fastingDays'] ?? []),
      'events': res['events'] ?? [],
      'fastingPractice': res['fastingPractice'] ?? 'none',
    };
  }

  /// POST /api/v1/fasting/reminders
  static Future<Map<String, dynamic>> setFastingReminder({
    required String reminderTime, // "06:30" format (HH:MM)
    required bool enabled,
  }) async {
    return await ApiClient.post('/fasting/reminders', {
      'reminderTime': reminderTime,
      'enabled': enabled,
    });
  }
}
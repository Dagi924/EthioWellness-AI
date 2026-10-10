
import 'dart:convert';

import 'api_client.dart';
import '../models/fasting_schedule_model.dart';

class FastingService {
  // ============================================================
  // TODAY'S FASTING STATUS
  // GET /api/v1/fasting/today
  // ============================================================

  static Future<FastingScheduleModel> getTodayFasting() async {
    final response = await ApiClient.get('/fasting/today');
    return FastingScheduleModel.fromJson(response);
  }

  // ============================================================
  // MONTHLY FASTING CALENDAR
  // GET /api/v1/fasting/calendar
  //
  // religion: orthodox, islam, or both
  // ============================================================

  static Future<Map<String, dynamic>> getMonthlyCalendar(
    int year,
    int month, {
    String religion = 'both',
    double latitude = 9.005401,
    double longitude = 38.769362,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be 1-12.');
    }

    if (!['orthodox', 'islam', 'both'].contains(religion)) {
      throw ArgumentError.value(
        religion,
        'religion',
        'Must be orthodox, islam, or both.',
      );
    }

    final query = <String, String>{
      'month': '$month',
      'year': '$year',
      'religion': religion,
      'latitude': '$latitude',
      'longitude': '$longitude',
    };

    final queryString = query.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final response = await ApiClient.get(
      '/fasting/calendar?$queryString',
    );

    final days = _asMapList(response['days']);
    final events = _asMapList(response['events']);

    return {
      'success': response['success'] == true,
      'month': _asInt(response['month'], month),
      'year': _asInt(response['year'], year),
      'monthName': response['monthName'] ?? '',
      'timezone': response['timezone'] ?? 'Africa/Addis_Ababa',
      'religion': response['religion'] ?? religion,
      'fastingPractice': response['fastingPractice'] ?? 'orthodox',
      'currentDate': response['currentDate'],
      'currentSelectedDay': _asInt(
        response['currentSelectedDay'],
        DateTime.now().day,
      ),
      'daysInMonth': _asInt(response['daysInMonth'], 0),
      'fastingDays': _asIntList(response['fastingDays']),
      'events': events,
      'days': days,
      'apiStatus': _asMap(response['apiStatus']),
    };
  }

  // ============================================================
  // DAILY FASTING EVENT DETAILS
  // ============================================================

  static Future<Map<String, dynamic>> getDayDetails({
    required int year,
    required int month,
    required int day,
    String religion = 'both',
    double latitude = 9.005401,
    double longitude = 38.769362,
  }) async {
    final calendar = await getMonthlyCalendar(
      year,
      month,
      religion: religion,
      latitude: latitude,
      longitude: longitude,
    );

    final date =
        '$year-${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';

    final days = _asMapList(calendar['days']);

    for (final item in days) {
      if (item['date'] == date) {
        return item;
      }
    }

    return {
      'date': date,
      'isFasting': false,
      'schedules': <String, dynamic>{},
    };
  }

  // ============================================================
  // FILTER FASTING EVENTS FOR A SELECTED DAY
  // ============================================================

  static List<Map<String, dynamic>> getFastingEventsForDay(
    Map<String, dynamic> calendar,
    String date,
  ) {
    final events = _asMapList(calendar['events']);

    return events
        .where((event) => event['date'] == date)
        .toList();
  }

  // ============================================================
  // REMINDER SETTINGS
  // POST /api/v1/fasting/reminders
  // ============================================================

  static Future<Map<String, dynamic>> setFastingReminder({
    required String reminderTime,
    required bool enabled,
  }) async {
    if (!_isValidTime(reminderTime)) {
      throw ArgumentError.value(
        reminderTime,
        'reminderTime',
        'Use 24-hour HH:mm format, such as 06:30.',
      );
    }

    final response = await ApiClient.post(
      '/fasting/reminders',
      {
        'reminderTime': reminderTime,
        'enabled': enabled,
      },
    );

    return _asMap(response);
  }

  // ============================================================
  // GET REMINDER SETTINGS
  // GET /api/v1/fasting/reminders
  // ============================================================

  static Future<Map<String, dynamic>> getFastingReminder() async {
    final response = await ApiClient.get('/fasting/reminders');
    return _asMap(response);
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static bool _isValidTime(String value) {
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<int> _asIntList(dynamic value) {
    if (value is! List) return <int>[];

    return value
        .map((item) => _asInt(item, -1))
        .where((item) => item > 0)
        .toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map(
            (key, item) => MapEntry(key.toString(), item),
          );
        }
      } catch (_) {
        // Return an empty map for invalid JSON.
      }
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }
}

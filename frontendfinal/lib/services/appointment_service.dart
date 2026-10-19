 import 'api_client.dart';

class AppointmentService {
  // ============================================================
  // NUTRITIONIST: GET VIDEO SESSION
  // ============================================================
  static Future<Map<String, dynamic>> getVideoSession(
    String appointmentId,
  ) async {
    final response = await ApiClient.post(
      '/appointments/$appointmentId/video-session',
      {},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Invalid video session response.');
  }

  // ============================================================
  // USER/PATIENT: GET VIDEO SESSION
  // ============================================================
  static Future<Map<String, dynamic>> getPatientVideoSession(
    String appointmentId,
  ) async {
    final response = await ApiClient.post(
      '/appointments/$appointmentId/video-session/patient',
      {},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Invalid patient video session response.');
  }

  // ============================================================
  // GET MY APPOINTMENTS
  // ============================================================
  static Future<Map<String, dynamic>> getMyAppointments() async {
    final response = await ApiClient.get(
      '/supervision/my-appointments',
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Invalid appointments response from server.');
  }

  // ============================================================
  // GET NUTRITIONIST AVAILABILITY
  // ============================================================
  //
  // The backend route used here is:
  // GET /api/v1/supervision/nutritionists/:id/availability?date=YYYY-MM-DD
  //
  // IMPORTANT:
  // This path must match the actual route in supervision.js.
  // ============================================================
  static Future<Map<String, dynamic>> getNutritionistAvailability({
    required String nutritionistId,
    required DateTime date,
  }) async {
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final endpoint =
        '/supervision/nutritionists/'
        '${Uri.encodeComponent(nutritionistId)}'
        '/availability?date=$dateString';

    final response = await ApiClient.get(endpoint);

    if (response is! Map) {
      throw Exception('Invalid availability response from server.');
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // BOOK SUPERVISION APPOINTMENT
  // ============================================================
  static Future<Map<String, dynamic>> bookSupervisionAppointment({
    required String nutritionistId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final response = await ApiClient.post(
      '/supervision/appointments',
      {
        'nutritionistId': nutritionistId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty)
          'notes': notes.trim(),
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Invalid appointment response from server.');
  }
}
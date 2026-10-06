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

    throw Exception(
      'Invalid video session response.',
    );
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

    throw Exception(
      'Invalid patient video session response.',
    );
  }
}
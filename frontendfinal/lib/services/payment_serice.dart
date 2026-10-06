import 'api_client.dart';

class PaymentService {
  static Future<Map<String, dynamic>> initializeChapaPayment({
    required double amountEtb,
    String? phoneNumber,
  }) async {
    return await ApiClient.post('/payments/chapa/initialize', {
      'amountEtb': amountEtb,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
    });
  }

  static Future<Map<String, dynamic>> verifyTransaction(String txRef) async {
    return await ApiClient.get('/payments/chapa/verify/$txRef');
  }
}
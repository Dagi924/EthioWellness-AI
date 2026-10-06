import 'api_client.dart';

class PaymentService {
  // ============================================================
  // INITIALIZE CHAPA PAYMENT
  // ============================================================

  static Future<Map<String, dynamic>> initializeChapaPayment({
    required double amountEtb,
    String? phoneNumber,
  }) async {
    final payload = {
      'amountEtb': amountEtb,
      if (phoneNumber != null &&
          phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
    };

    final res = await ApiClient.post(
      '/payments/chapa/initialize',
      payload,
    );

    final checkoutUrl =
        res['checkoutUrl']?.toString() ?? '';

    final txRef =
        res['txRef']?.toString() ?? '';

    if (checkoutUrl.isEmpty) {
      throw Exception(
        'Chapa did not return a checkout URL.',
      );
    }

    return {
      'success': true,
      'txRef': txRef,
      'checkoutUrl': checkoutUrl,
      'status':
          res['status'] ?? 'success',
      'isSimulation':
          res['isSimulation'] ?? false,
      'raw': res,
    };
  }


  // ============================================================
  // VERIFY CHAPA PAYMENT
  // ============================================================

  static Future<Map<String, dynamic>>
      verifyTransaction(
    String txRef,
  ) async {
    final res = await ApiClient.get(
      '/payments/chapa/verify/$txRef',
    );

    return {
      'verified':
          res['verified'] == true,

      'isPremiumActive':
          res['isPremiumActive'] == true,

      'status':
          res['status'] ?? 'unknown',

      'message':
          res['message'] ?? '',

      'txRef':
          res['txRef'] ?? txRef,

      'raw': res,
    };
  }


  // ============================================================
  // PAYMENT HISTORY
  // ============================================================

  static Future<List<dynamic>>
      getPaymentHistory() async {
    final res =
        await ApiClient.get(
      '/payments/history',
    );

    return res['payments'] ?? [];
  }
}
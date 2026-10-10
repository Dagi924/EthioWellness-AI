import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import 'main_shell_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? txRef;

  const PaymentSuccessScreen({
    super.key,
    this.txRef,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isVerifying = true;
  bool _isSuccess = false;

  String _message =
      'Verifying your transaction with Chapa & Ethiopian banks...';

  Map<String, dynamic>? _transactionDetails;

  String? get _transactionRef {
    // First use constructor value.
    if (widget.txRef != null && widget.txRef!.isNotEmpty) {
      return widget.txRef;
    }

    // Flutter Web fallback:
    // /payment-success?tx_ref=EthioWellness-tx-123
    final uri = Uri.base;
    return uri.queryParameters['tx_ref'];
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyPayment();
    });
  }

  Future<void> _verifyPayment() async {
    final ref = _transactionRef;

    if (ref == null || ref.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isVerifying = false;
        _isSuccess = false;
        _message =
            'No transaction reference was found in the Chapa return URL.';
      });

      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isVerifying = true;
          _message = 'Verifying transaction $ref...';
        });
      }

      final res = await PaymentService.verifyTransaction(ref);

      final verified = res['verified'] == true;
      final isPremiumActive = res['isPremiumActive'] == true;

      if (verified && isPremiumActive) {
        await AuthService.setPremiumStatus(true);

        try {
          await AuthService.getProfile();
        } catch (_) {
          // Profile refresh failure should not invalidate
          // an already verified payment.
        }

        if (!mounted) return;

        setState(() {
          _isVerifying = false;
          _isSuccess = true;
          _transactionDetails = res;
          _message =
              'Your Chapa payment has been verified successfully. '
              'EthioWellness Premium is now active.';
        });
      } else {
        if (!mounted) return;

        setState(() {
          _isVerifying = false;
          _isSuccess = false;
          _transactionDetails = res;
          _message = res['message'] ??
              'Payment has not been confirmed yet. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isVerifying = false;
        _isSuccess = false;
        _message =
            'Verification error: ${e.toString().replaceAll("Exception: ", "")}';
      });
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainShellScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _transactionRef;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: const Text(
          'Payment Confirmation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF542E13), // Warm Cognac Brown
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 480,
            ),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEADBCE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF542E13).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isVerifying)
                  _buildVerifying()
                else if (_isSuccess)
                  _buildSuccess(ref)
                else
                  _buildFailure(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    return Column(
      children: [
        const SizedBox(
          height: 56,
          width: 56,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            color: Color(0xFF542E13),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Confirming Payment...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF542E13),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(String? ref) {
    return Column(
      children: [
        Container(
          height: 68,
          width: 68,
          decoration: const BoxDecoration(
            color: Color(0xFFF5EBE1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF8D4F28),
            size: 44,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'Payment Successful!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917),
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontSize: 14,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F3EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFEADBCE),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tx Reference:',
                    style: TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      ref ?? 'N/A',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 18, color: Color(0xFFEADBCE)),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Access Level:',
                    style: TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'PREMIUM MEMBER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
              foregroundColor: Colors.white,
              minimumSize: const Size(
                double.infinity,
                50,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _goHome,
            child: const Text(
              'START USING PREMIUM FEATURES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailure() {
    return Column(
      children: [
        Container(
          height: 68,
          width: 68,
          decoration: const BoxDecoration(
            color: Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 42,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'Verification Incomplete',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF78716C),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _goHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF542E13),
                  side: const BorderSide(color: Color(0xFFEADBCE)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _verifyPayment,
                child: const Text(
                  'Retry Verification',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
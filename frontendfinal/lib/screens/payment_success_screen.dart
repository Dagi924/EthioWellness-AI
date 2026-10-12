import 'package:flutter/material.dart';

import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';
import 'main_shell_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? txRef;

  const PaymentSuccessScreen({
    super.key,
    this.txRef,
  });

  @override
  State<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState
    extends State<PaymentSuccessScreen> {
  bool _isVerifying = true;
  bool _isSuccess = false;

  String _messageKey = 'payment_verifying_banks';
  String? _messageOverride;
  Map<String, String> _messageParams = {};

  String _tr(
    String key, {
    Map<String, String> params = const {},
  }) {
    return AppLocalization.instance.tr(
      key,
      params: params,
    );
  }

  String get _message {
    if (_messageOverride != null) {
      return _messageOverride!;
    }

    return _tr(
      _messageKey,
      params: _messageParams,
    );
  }

  String? get _transactionRef {
    if (widget.txRef != null &&
        widget.txRef!.isNotEmpty) {
      return widget.txRef;
    }

    return Uri.base.queryParameters['tx_ref'];
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
        _messageKey = 'payment_no_reference';
        _messageOverride = null;
        _messageParams = {};
      });

      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isVerifying = true;
          _messageKey = 'payment_verifying_reference';
          _messageOverride = null;
          _messageParams = {'reference': ref};
        });
      }

      final res =
          await PaymentService.verifyTransaction(ref);

      final verified = res['verified'] == true;
      final isPremiumActive =
          res['isPremiumActive'] == true;

      if (verified && isPremiumActive) {
        await AuthService.setPremiumStatus(true);

        try {
          await AuthService.getProfile();
        } catch (_) {
          // A profile refresh failure does not invalidate
          // an already verified payment.
        }

        if (!mounted) return;

        setState(() {
          _isVerifying = false;
          _isSuccess = true;
          _messageKey = 'payment_success_message';
          _messageOverride = null;
          _messageParams = {};
        });
      } else {
        if (!mounted) return;

        final serverMessage = res['message']?.toString();

        setState(() {
          _isVerifying = false;
          _isSuccess = false;

          if (serverMessage != null &&
              serverMessage.isNotEmpty) {
            // Keep the message returned by the payment API.
            _messageOverride = serverMessage;
            _messageKey = '';
            _messageParams = {};
          } else {
            _messageKey = 'payment_not_confirmed';
            _messageOverride = null;
            _messageParams = {};
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isVerifying = false;
        _isSuccess = false;
        _messageKey = 'payment_verification_error';
        _messageOverride = null;
        _messageParams = {
          'error': e
              .toString()
              .replaceAll('Exception: ', ''),
        };
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

    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F2EA),
          appBar: AppBar(
            title: Text(
              _tr('payment_confirmation'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: const Color(0xFF542E13),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            elevation: 0,
            actions: const [
              LanguageToggleButton(),
            ],
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
                  border: Border.all(
                    color: const Color(0xFFEADBCE),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF542E13)
                          .withOpacity(0.06),
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
      },
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
        Text(
          _tr('payment_confirming'),
          textAlign: TextAlign.center,
          style: const TextStyle(
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
        Text(
          _tr('payment_success_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('payment_tx_reference'),
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      ref ?? _tr('not_available'),
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
              const Divider(
                height: 18,
                color: Color(0xFFEADBCE),
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('payment_access_level'),
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      _tr('payment_premium_member'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
              backgroundColor: const Color(0xFF542E13),
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
            child: Text(
              _tr('payment_start_premium'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                letterSpacing: 0.3,
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
        Text(
          _tr('payment_verification_incomplete'),
          textAlign: TextAlign.center,
          style: const TextStyle(
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
                  side: const BorderSide(
                    color: Color(0xFFEADBCE),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _tr('payment_back_home'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isVerifying
                    ? null
                    : _verifyPayment,
                child: Text(
                  _tr('payment_retry_verification'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

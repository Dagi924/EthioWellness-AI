import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/payment_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';
import 'payment_success_screen.dart';

class ChapaPaymentScreen extends StatefulWidget {
  const ChapaPaymentScreen({super.key});

  @override
  State<ChapaPaymentScreen> createState() =>
      _ChapaPaymentScreenState();
}

class _ChapaPaymentScreenState extends State<ChapaPaymentScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  String _selectedPlan = 'monthly';
  String? _pendingTxRef;

  String _t(String key) =>
      AppLocalization.instance.tr(key);

  final Map<String, double> _prices = {
    'monthly': 299.0,
    'quarterly': 799.0,
    'yearly': 2499.0,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingTxRef != null &&
        mounted) {
      final txRef = _pendingTxRef!;
      _pendingTxRef = null;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(txRef: txRef),
        ),
      );
    }
  }

  Future<void> _startCheckout() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final amount = _prices[_selectedPlan] ?? 299.0;

      final res = await PaymentService.initializeChapaPayment(
        amountEtb: amount,
      );

      final checkoutUrl = res['checkoutUrl']?.toString();
      final txRef = res['txRef']?.toString();

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception(_t('chapa_url_missing'));
      }

      final uri = Uri.tryParse(checkoutUrl);

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw Exception(_t('invalid_checkout_url'));
      }

      if (txRef != null && txRef.isNotEmpty) {
        _pendingTxRef = txRef;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _pendingTxRef = null;
        throw Exception(_t('payment_gateway_unavailable'));
      }
    } catch (e) {
      _pendingTxRef = null;

      if (!mounted) return;

      final error = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(
            '${_t('payment_initialization_error')}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F2EA),
          appBar: AppBar(
            title: Text(
              _t('premium_upgrade_title'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
            actions: const [
              LanguageToggleButton(),
              SizedBox(width: 8),
            ],
            backgroundColor: const Color(0xFF542E13),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium introduction
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFEADBCE),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5EBE1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFF8D4F28),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('premium_benefits_title'),
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C1917),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t('premium_benefits_description'),
                                style: const TextStyle(
                                  color: Color(0xFF78716C),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment methods
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F3EC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEADBCE),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF542E13),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('supported_payment_methods'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF542E13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Monthly plan
                  _planOption(
                    title: _t('monthly_plan'),
                    price: '299 ETB / ${_t('month')}',
                    planKey: 'monthly',
                    subtitle: _t('monthly_plan_subtitle'),
                    badgeText: _t('popular'),
                  ),

                  const SizedBox(height: 12),

                  // Quarterly plan
                  _planOption(
                    title: _t('quarterly_plan'),
                    price: '799 ETB / 3 ${_t('months')}',
                    planKey: 'quarterly',
                    subtitle: _t('quarterly_plan_subtitle'),
                    badgeText: _t('save_15'),
                  ),

                  const SizedBox(height: 12),

                  // Annual plan
                  _planOption(
                    title: _t('annual_plan'),
                    price: '2,499 ETB / ${_t('year')}',
                    planKey: 'yearly',
                    subtitle: _t('annual_plan_subtitle'),
                    badgeText: _t('best_value'),
                  ),

                  const SizedBox(height: 24),

                  // Payment button
                  ElevatedButton(
                    onPressed:
                        _isLoading ? null : _startCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF542E13),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _t('pay_with_chapa'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _planOption({
    required String title,
    required String price,
    required String planKey,
    String? subtitle,
    String? badgeText,
  }) {
    final isSelected = _selectedPlan == planKey;

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedPlan = planKey);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFBF7F2)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF542E13)
                : const Color(0xFFEADBCE),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF542E13).withOpacity(0.06)
                  : Colors.black.withOpacity(0.015),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF542E13)
                      : const Color(0xFFA8A29E),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF542E13)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSelected
                              ? const Color(0xFF542E13)
                              : const Color(0xFF1C1917),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF5EBE1)
                                : const Color(0xFFF8F3EC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFEADBCE),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF542E13)
                                  : const Color(0xFF78716C),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              price,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? const Color(0xFF542E13)
                    : const Color(0xFF1C1917),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

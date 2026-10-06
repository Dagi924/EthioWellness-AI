import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import 'payment_success_screen.dart';

class ChapaPaymentScreen extends StatefulWidget {
  const ChapaPaymentScreen({super.key});

  @override
  State<ChapaPaymentScreen> createState() => _ChapaPaymentScreenState();
}

class _ChapaPaymentScreenState extends State<ChapaPaymentScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  String _selectedPlan = 'monthly';
  String? _pendingTxRef;

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
    // When user returns to app after completing Telebirr/CBE payment in browser
    if (state == AppLifecycleState.resumed && _pendingTxRef != null) {
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
    setState(() => _isLoading = true);
    try {
      final amount = _prices[_selectedPlan] ?? 299.0;

      // 1. Call POST /api/v1/payments/chapa/initialize
      final res = await PaymentService.initializeChapaPayment(amountEtb: amount);

      // 2. Extract exact checkoutUrl returned by backend
      final checkoutUrl = res['checkoutUrl']?.toString();
      final txRef = res['txRef']?.toString();

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        _pendingTxRef = txRef;
        final uri = Uri.parse(checkoutUrl);

        // 3. Launch exact Chapa checkout URL
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Unable to open payment gateway.');
        }
      } else {
        throw Exception('Chapa checkout URL was not provided by the server.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              'Payment initialization error: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: const Text(
          'Upgrade to EthioNutri Premium',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEADBCE)),
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
                        children: const [
                          Text(
                            'Unlock Full Fasting & AI Plans',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1917),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Unlimited AI 7-day fasting meal generations, ETB market grocery pricing, and clinical dietitian consultations.',
                            style: TextStyle(
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

              // Supported Gateways Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F3EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEADBCE)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_rounded, size: 16, color: Color(0xFF542E13)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secured by Chapa: Telebirr, CBE Birr, Awash & Cards',
                        style: TextStyle(
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

              // Plan Options
              _planOption(
                title: 'Monthly Plan',
                price: '299 ETB / month',
                planKey: 'monthly',
                subtitle: 'Flexible month-to-month access',
                badgeText: 'Popular',
              ),
              const SizedBox(height: 12),
              _planOption(
                title: 'Quarterly Plan (Save 15%)',
                price: '799 ETB / 3 months',
                planKey: 'quarterly',
                subtitle: 'Ideal for 55-day Great Lent Season',
                badgeText: 'Save 15%',
              ),
              const SizedBox(height: 12),
              _planOption(
                title: 'Annual Plan (Save 30%)',
                price: '2,499 ETB / year',
                planKey: 'yearly',
                subtitle: 'Complete year-round fasting & health coverage',
                badgeText: 'Best Value',
              ),

              const SizedBox(height: 24),

              // Pay Button
              ElevatedButton(
                onPressed: _isLoading ? null : _startCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown CTA
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Pay with Chapa (Telebirr / CBE Birr)',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
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
      onTap: () => setState(() => _selectedPlan = planKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBF7F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF542E13) : const Color(0xFFEADBCE),
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
                  color: isSelected ? const Color(0xFF542E13) : const Color(0xFFA8A29E),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF542E13) : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
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
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
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
            Text(
              price,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
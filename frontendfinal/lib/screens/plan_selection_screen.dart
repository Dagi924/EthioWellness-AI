import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import 'main_shell_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  final String userName;
  final String? userPhone;

  const PlanSelectionScreen({
    super.key,
    this.userName = 'there',
    this.userPhone,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen>
    with WidgetsBindingObserver {
  String _selectedPlan = 'free';
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _pendingTxRef;
  String? _errorMessage;

  final Map<String, Map<String, dynamic>> _plans = {
    'free': {
      'title': 'Free Starter',
      'price': '0 ETB',
      'period': 'Forever',
      'badge': 'Standard',
      'color': Color(0xFF78716C),
      'amountEtb': 0.0,
      'features': [
        'Full Ethiopian FAO Food Database (Teff, Shiro, etc.)',
        'Daily Orthodox Tsom & Ramadan fasting alerts',
        'Daily calorie and macro tracker',
        'Water intake logger',
      ],
    },
    'monthly': {
      'title': 'Premium Monthly',
      'price': '299 ETB',
      'period': '/ month',
      'badge': 'Most Popular',
      'color': Color(0xFF542E13),
      'amountEtb': 299.0,
      'features': [
        'Everything in Free',
        'AI-Generated 7-Day Ethiopian Fasting Meal Plans',
        'Automated Market Grocery List with ETB pricing',
        'AI Food Photo Recognition Scanner',
        'Clinical Dietitian Appointment Booking',
      ],
    },
    'yearly': {
      'title': 'Premium Annual (Save 30%)',
      'price': '2,499 ETB',
      'period': '/ year',
      'badge': 'Best Value',
      'color': Color(0xFF8D4F28),
      'amountEtb': 2499.0,
      'features': [
        'Everything in Monthly',
        'Priority Dietitian Chat & Supervision',
        'Personalized Anemia & Iron Boost Reports',
        'Offline PDF Meal Plan Export',
      ],
    },
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
    // When the user switches back from Telebirr / Chapa browser:
    if (state == AppLifecycleState.resumed &&
        _pendingTxRef != null &&
        !_isVerifying) {
      _verifyPaymentAndEnterApp(_pendingTxRef!);
    }
  }

  void _navigateToMainApp({bool isPremiumActive = false}) {
    if (mounted) {
      if (isPremiumActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF542E13),
            duration: Duration(seconds: 4),
            content: Row(
              children: [
                Icon(Icons.workspace_premium, color: Color(0xFFEADBCE)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'EthioNutri Premium Unlocked! Database updated to Premium.'),
                ),
              ],
            ),
          ),
        );
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handlePlanAction() async {
    if (_selectedPlan == 'free') {
      _navigateToMainApp(isPremiumActive: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final planData = _plans[_selectedPlan]!;
      final amount = (planData['amountEtb'] as num).toDouble();

      // Call POST /api/v1/payments/chapa/initialize
      final res = await PaymentService.initializeChapaPayment(
        amountEtb: amount,
        phoneNumber: widget.userPhone,
      );

      final checkoutUrl = res['checkoutUrl'];
      final txRef = res['txRef'];

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        setState(() {
          _pendingTxRef = txRef;
        });

        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            _showPaymentWaitingModal(txRef);
          }
        } else {
          throw Exception('Unable to launch payment link.');
        }
      } else {
        throw Exception('Chapa payment gateway URL not received.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPaymentAndEnterApp(String txRef) async {
    setState(() => _isVerifying = true);
    try {
      // Calls GET /api/v1/payments/chapa/verify/:tx_ref
      final res = await PaymentService.verifyTransaction(txRef);
      if (res['isPremiumActive'] == true || res['status'] == 'success') {
        _navigateToMainApp(isPremiumActive: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ??
                  'Payment is still pending or incomplete.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification check: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showPaymentWaitingModal(String txRef) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payment_rounded,
                color: Color(0xFF8D4F28),
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Awaiting Chapa Confirmation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF542E13),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your transaction via Telebirr or CBE Birr in your browser, then tap "Verify Payment" to activate your Premium subscription.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF78716C), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateToMainApp(isPremiumActive: false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF542E13),
                      side: const BorderSide(color: Color(0xFFEADBCE)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Enter Free Tier',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _verifyPaymentAndEnterApp(txRef);
                          },
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Verify Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF542E13),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Canvas
      appBar: AppBar(
        title: const Text(
          'Select Your Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _navigateToMainApp(isPremiumActive: false),
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Color(0xFFEADBCE),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, ${widget.userName}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a plan to power your Ethiopian nutrition, fasting schedules, and health goals.',
                style: TextStyle(color: Color(0xFF78716C), fontSize: 14),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),

              // Plan Cards List
              ..._plans.entries
                  .map((entry) => _buildPlanCard(entry.key, entry.value)),

              const SizedBox(height: 20),

              // Main CTA Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePlanAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPlan == 'free'
                      ? const Color(0xFF78716C)
                      : const Color(0xFF542E13), // Brown primary CTA
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _selectedPlan == 'free'
                            ? 'Continue with Free Version'
                            : 'Pay with Chapa (Telebirr / CBE Birr)',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 12),
              if (_selectedPlan != 'free')
                Center(
                  child: TextButton(
                    onPressed: () =>
                        _navigateToMainApp(isPremiumActive: false),
                    child: const Text(
                      'Or start with Free version',
                      style: TextStyle(
                        color: Color(0xFF78716C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(String key, Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == key;
    final features = plan['features'] as List<String>;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBF7F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF542E13)
                : const Color(0xFFEADBCE),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF542E13).withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan['title'],
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF542E13)
                        : const Color(0xFF1C1917),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF5EBE1)
                        : const Color(0xFFF8F3EC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFEADBCE)
                          : const Color(0xFFEADBCE).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    plan['badge'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF542E13)
                          : const Color(0xFF78716C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan['price'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  plan['period'],
                  style: const TextStyle(
                      color: Color(0xFF78716C), fontSize: 13),
                ),
              ],
            ),
            const Divider(height: 22, color: Color(0xFFEFE8DF)),
            ...features.map(
              (feat) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF8D4F28), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feat,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF44403C), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
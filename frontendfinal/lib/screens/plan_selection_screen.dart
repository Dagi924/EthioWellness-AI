import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/payment_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';
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
  State<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen>
    with WidgetsBindingObserver {
  String _selectedPlan = 'free';
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _pendingTxRef;
  String? _errorMessage;

  String _tr(
    String key, {
    Map<String, String> params = const {},
  }) {
    return AppLocalization.instance.tr(
      key,
      params: params,
    );
  }

  final Map<String, Map<String, dynamic>> _plans = {
    'free': {
      'titleKey': 'plan_free_title',
      'price': '0 ETB',
      'periodKey': 'plan_forever',
      'badgeKey': 'plan_standard',
      'color': const Color(0xFF78716C),
      'amountEtb': 0.0,
      'featureKeys': [
        'plan_feature_food_database',
        'plan_feature_fasting_alerts',
        'plan_feature_calorie_tracker',
        'plan_feature_water_logger',
      ],
    },
    'monthly': {
      'titleKey': 'plan_monthly_title',
      'price': '299 ETB',
      'periodKey': 'plan_month',
      'badgeKey': 'plan_most_popular',
      'color': const Color(0xFF542E13),
      'amountEtb': 299.0,
      'featureKeys': [
        'plan_feature_everything_free',
        'plan_feature_ai_meal_plans',
        'plan_feature_grocery_list',
        'plan_feature_food_scanner',
        'plan_feature_dietitian_booking',
      ],
    },
    'yearly': {
      'titleKey': 'plan_yearly_title',
      'price': '2,499 ETB',
      'periodKey': 'plan_year',
      'badgeKey': 'plan_best_value',
      'color': const Color(0xFF8D4F28),
      'amountEtb': 2499.0,
      'featureKeys': [
        'plan_feature_everything_monthly',
        'plan_feature_priority_dietitian',
        'plan_feature_anemia_reports',
        'plan_feature_pdf_export',
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
    if (state == AppLifecycleState.resumed &&
        _pendingTxRef != null &&
        !_isVerifying) {
      _verifyPaymentAndEnterApp(_pendingTxRef!);
    }
  }

  void _navigateToMainApp({bool isPremiumActive = false}) {
    if (!mounted) return;

    if (isPremiumActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF542E13),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFFEADBCE),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tr('premium_unlocked'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainShellScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _handlePlanAction() async {
    if (_selectedPlan == 'free') {
      _navigateToMainApp();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final planData = _plans[_selectedPlan]!;
      final amount = (planData['amountEtb'] as num).toDouble();

      final res = await PaymentService.initializeChapaPayment(
        amountEtb: amount,
        phoneNumber: widget.userPhone,
      );

      final checkoutUrl = res['checkoutUrl']?.toString();
      final txRef = res['txRef']?.toString();

      if (checkoutUrl != null &&
          checkoutUrl.isNotEmpty &&
          txRef != null &&
          txRef.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pendingTxRef = txRef;
          });
        }

        final uri = Uri.parse(checkoutUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );

          if (mounted) {
            _showPaymentWaitingModal(txRef);
          }
        } else {
          throw Exception(_tr('payment_link_launch_failed'));
        }
      } else {
        throw Exception(_tr('payment_url_missing'));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyPaymentAndEnterApp(String txRef) async {
    if (_isVerifying) return;

    if (mounted) {
      setState(() => _isVerifying = true);
    }

    try {
      final res = await PaymentService.verifyTransaction(txRef);

      if (res['isPremiumActive'] == true ||
          res['status'] == 'success') {
        _pendingTxRef = null;
        _navigateToMainApp(isPremiumActive: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ??
                    _tr('payment_pending'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tr('payment_verification_error')}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showPaymentWaitingModal(String txRef) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: AppLocalization.instance,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
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
                  Text(
                    _tr('payment_waiting_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF542E13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr('payment_waiting_description'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _navigateToMainApp();
                          },
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
                            _tr('enter_free_tier'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
                                  await _verifyPaymentAndEnterApp(
                                    txRef,
                                  );
                                },
                          icon: _isVerifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: Text(
                            _tr('verify_payment'),
                            textAlign: TextAlign.center,
                          ),
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F2EA),
          appBar: AppBar(
            title: Text(
              _tr('select_your_plan'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
            backgroundColor: const Color(0xFF542E13),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            elevation: 0,
            actions: [
              const LanguageToggleButton(),
              TextButton(
                onPressed: () => _navigateToMainApp(),
                child: Text(
                  _tr('skip_for_now'),
                  style: const TextStyle(
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
                    _tr(
                      'welcome_user',
                      params: {'name': widget.userName},
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tr('plan_selection_description'),
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFECACA),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ..._plans.entries.map(
                    (entry) => _buildPlanCard(
                      entry.key,
                      entry.value,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handlePlanAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPlan == 'free'
                          ? const Color(0xFF78716C)
                          : const Color(0xFF542E13),
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
                        : Text(
                            _selectedPlan == 'free'
                                ? _tr('continue_free_version')
                                : _tr('pay_with_chapa'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPlan != 'free')
                    Center(
                      child: TextButton(
                        onPressed: () => _navigateToMainApp(),
                        child: Text(
                          _tr('or_start_free'),
                          style: const TextStyle(
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
      },
    );
  }

  Widget _buildPlanCard(
    String key,
    Map<String, dynamic> plan,
  ) {
    final isSelected = _selectedPlan == key;
    final featureKeys = plan['featureKeys'] as List<String>;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFBF7F2)
              : Colors.white,
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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _tr(plan['titleKey'] as String),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF542E13)
                          : const Color(0xFF1C1917),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF5EBE1)
                        : const Color(0xFFF8F3EC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEADBCE).withOpacity(
                        isSelected ? 1 : 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    _tr(plan['badgeKey'] as String),
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
                  plan['price'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _tr(plan['periodKey'] as String),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(
              height: 22,
              color: Color(0xFFEFE8DF),
            ),
            ...featureKeys.map(
              (featureKey) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF8D4F28),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tr(featureKey),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF44403C),
                          height: 1.3,
                        ),
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

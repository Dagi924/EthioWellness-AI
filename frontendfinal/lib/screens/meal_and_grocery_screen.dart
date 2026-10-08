
import 'package:flutter/material.dart';

import '../services/meal_plan_service.dart';
import '../services/auth_service.dart';
import '../models/meal_plan_model.dart';
import 'chapa_payment_screen.dart';

class MealAndGroceryScreen extends StatefulWidget {
  const MealAndGroceryScreen({
    super.key,
  });

  @override
  State<MealAndGroceryScreen> createState() =>
      _MealAndGroceryScreenState();
}

class _MealAndGroceryScreenState
    extends State<MealAndGroceryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isPremium = false;

  bool _isLoadingMealPlan = false;

  MealPlanModel? _mealPlan;

  bool _isLoadingGrocery = false;

  String _groceryText = '';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _checkPremiumAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ============================================================
  /// PREMIUM + INITIAL LOAD
  /// ============================================================

  Future<void> _checkPremiumAndLoad() async {
    try {
      final isPrem =
          await AuthService.isPremiumUser();

      if (!mounted) return;

      setState(() {
        _isPremium = isPrem;
      });

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      _showSnackbar(
        'Failed to load account information: $e',
        isError: true,
      );
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _fetchMealPlan(),
      _fetchGroceryList(),
    ]);
  }

  /// ============================================================
  /// FETCH MEAL PLAN
  /// ============================================================

  Future<void> _fetchMealPlan() async {
    if (mounted) {
      setState(() {
        _isLoadingMealPlan = true;
      });
    }

    try {
      final plan =
          await MealPlanService.getCurrentPlan();

      if (!mounted) return;

      setState(() {
        _mealPlan = plan;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Failed to load meal plan: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMealPlan = false;
        });
      }
    }
  }

  /// ============================================================
  /// GENERATE MEAL PLAN
  /// ============================================================

  Future<void> _generateMealPlan() async {
    if (!_isPremium) {
      _showUpgradeModal(
        'AI 7-Day Fasting Meal Plans are exclusive to EthioNutri Premium members.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingMealPlan = true;
      });
    }

    try {
      final plan =
          await MealPlanService.generateMealPlan();

      if (!mounted) return;

      setState(() {
        _mealPlan = plan;
      });

      /*
       * The backend is now SOFT.
       *
       * Therefore a successful AI response can either be:
       *
       * 1. Structured planDays
       * 2. Raw AI text
       *
       * Both are considered successful.
       */

      if (plan.planDays.isNotEmpty) {
        _showSnackbar(
          '✨ New Ethiopian 7-Day Fasting Plan generated!',
        );
      } else if (plan.rawAiText.isNotEmpty) {
        _showSnackbar(
          '✨ AI generated a meal plan response.',
        );
      } else {
        _showSnackbar(
          'AI responded, but returned no displayable content.',
          isError: true,
        );
      }
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(
        e.message,
      );
    } catch (e) {
      _showSnackbar(
        'Generation failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMealPlan = false;
        });
      }
    }
  }

  /// ============================================================
  /// FETCH GROCERY TEXT
  /// ============================================================

  Future<void> _fetchGroceryList() async {
    if (mounted) {
      setState(() {
        _isLoadingGrocery = true;
      });
    }

    try {
      final data =
          await MealPlanService.getGroceryList();

      if (!mounted) return;

      final groceryText =
          data['groceryText']?.toString() ?? '';

      setState(() {
        _groceryText = groceryText.trim();
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Failed to load grocery list: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGrocery = false;
        });
      }
    }
  }

  /// ============================================================
  /// GENERATE GROCERY TEXT
  /// ============================================================

  Future<void> _generateGrocery() async {
    if (!_isPremium) {
      _showUpgradeModal(
        'AI-generated grocery lists require EthioNutri Premium.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingGrocery = true;
      });
    }

    try {
      final data =
          await MealPlanService.generateGroceryList();

      if (!mounted) return;

      final groceryText =
          data['groceryText']?.toString() ?? '';

      if (groceryText.trim().isEmpty) {
        _showSnackbar(
          'AI responded, but returned no grocery list.',
          isError: true,
        );
        return;
      }

      setState(() {
        _groceryText = groceryText.trim();
      });

      _showSnackbar(
        '🛒 Grocery list generated successfully!',
      );
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(
        e.message,
      );
    } catch (e) {
      _showSnackbar(
        '$e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGrocery = false;
        });
      }
    }
  }

  /// ============================================================
  /// UPGRADE MODAL
  /// ============================================================

  void _showUpgradeModal(
    String reason,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (ctx) => Padding(
        padding:
            const EdgeInsets.all(26),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFFEF3C7),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .workspace_premium_rounded,
                color:
                    Color(0xFFB45309),
                size: 38,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'Upgrade to EthioNutri Premium',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF542E13),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              reason,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Color(0xFF78716C),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(
              height: 22,
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF542E13,
                ),
                foregroundColor:
                    Colors.white,
                minimumSize:
                    const Size(
                  double.infinity,
                  50,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(
                  ctx,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ChapaPaymentScreen(),
                  ),
                ).then(
                  (_) =>
                      _checkPremiumAndLoad(),
                );
              },
              child: const Text(
                'Unlock Premium (299 ETB / mo)',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// SNACKBAR
  /// ============================================================

  void _showSnackbar(
    String text, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
            isError
                ? const Color(
                    0xFFDC2626,
                  )
                : const Color(
                    0xFF542E13,
                  ),
      ),
    );
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F2EA),
      appBar: AppBar(
        title: const Text(
          'Meal Plan & Market Grocery',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor:
            const Color(0xFF542E13),
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          if (!_isPremium)
            Padding(
              padding:
                  const EdgeInsets.only(
                right: 8,
              ),
              child:
                  TextButton.icon(
                onPressed: () =>
                    _showUpgradeModal(
                  'Unlock unlimited AI plans and AI grocery lists.',
                ),
                icon: const Icon(
                  Icons.star_rounded,
                  color:
                      Color(0xFFFBBF24),
                  size: 18,
                ),
                label:
                    const Text(
                  'Free Tier',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
        bottom:
            PreferredSize(
          preferredSize:
              const Size.fromHeight(
            48,
          ),
          child: Container(
            color:
                const Color(0xFF43240E),
            child: TabBar(
              controller:
                  _tabController,
              indicatorColor:
                  const Color(
                0xFFEADBCE,
              ),
              indicatorWeight: 3,
              labelColor:
                  Colors.white,
              unselectedLabelColor:
                  Colors.white
                      .withOpacity(
                0.7,
              ),
              labelStyle:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 13.5,
              ),
              tabs: const [
                Tab(
                  icon: Icon(
                    Icons
                        .restaurant_menu_rounded,
                    size: 19,
                  ),
                  text:
                      '7-Day Plan',
                ),
                Tab(
                  icon: Icon(
                    Icons
                        .shopping_cart_outlined,
                    size: 19,
                  ),
                  text:
                      'Market Grocery',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller:
            _tabController,
        children: [
          _buildMealPlanTab(),
          _buildGroceryTab(),
        ],
      ),
    );
  }

  /// ============================================================
  /// MEAL PLAN TAB
  /// ============================================================

  Widget _buildMealPlanTab() {
    if (_isLoadingMealPlan) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              Color(0xFF542E13),
        ),
      );
    }

    /*
     * ==========================================================
     * NO RESPONSE AT ALL
     * ==========================================================
     */

    if (_mealPlan == null) {
      return _buildNoMealPlanView();
    }

    /*
     * ==========================================================
     * RAW AI RESPONSE
     * ==========================================================
     */

    if (_mealPlan!.planDays.isEmpty &&
        _mealPlan!.rawAiText
            .trim()
            .isNotEmpty) {
      return _buildRawAiPlanView(
        _mealPlan!.rawAiText,
      );
    }

    /*
     * ==========================================================
     * EMPTY RESPONSE
     * ==========================================================
     */

    if (_mealPlan!.planDays.isEmpty) {
      return _buildNoMealPlanView();
    }

    /*
     * ==========================================================
     * NORMAL STRUCTURED PLAN
     * ==========================================================
     */

    return RefreshIndicator(
      color:
          const Color(0xFF542E13),
      onRefresh:
          _fetchMealPlan,
      child: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Current Weekly Plan',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                  color:
                      Color(0xFF542E13),
                ),
              ),
              TextButton.icon(
                onPressed:
                    _generateMealPlan,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color:
                      Color(0xFF8D4F28),
                  size: 18,
                ),
                label:
                    const Text(
                  'Regenerate',
                  style:
                      TextStyle(
                    color:
                        Color(0xFF8D4F28),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          ..._mealPlan!.planDays.map(
            (day) => Container(
              margin:
                  const EdgeInsets.only(
                bottom: 14,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFEADBCE,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(
                      0.02,
                    ),
                    blurRadius: 10,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            day.day,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize:
                                  15,
                              color:
                                  Color(
                                0xFF1C1917,
                              ),
                            ),
                          ),
                        ),
                        if (day.isFasting)
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  8,
                              vertical:
                                  3,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFFEF3C7,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                6,
                              ),
                              border:
                                  Border.all(
                                color:
                                    const Color(
                                  0xFFFDE68A,
                                ),
                              ),
                            ),
                            child:
                                const Text(
                              'ጾም / Fasting',
                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF92400E,
                                ),
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(
                      height: 18,
                      color:
                          Color(0xFFEFE8DF),
                    ),
                    if (day.meals.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets
                                .symmetric(
                          vertical: 8,
                        ),
                        child: Text(
                          'No individual meals were structured for this day.',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFF78716C,
                            ),
                            fontSize:
                                13,
                          ),
                        ),
                      ),
                    ...day.meals.map(
                      (m) => Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              '${m.mealType.toUpperCase()}: ',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize:
                                    12,
                                color:
                                    Color(
                                  0xFF965126,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${m.foodName} (${m.calories.toInt()} kcal • P: ${m.proteinGrams}g)',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      13,
                                  color:
                                      Color(
                                    0xFF1C1917,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// NO MEAL PLAN VIEW
  /// ============================================================

  Widget _buildNoMealPlanView() {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          28,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFF5EBE1),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .auto_awesome_rounded,
                size: 36,
                color:
                    Color(0xFF8D4F28),
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'No Active Meal Plan',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF542E13),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _isPremium
                  ? 'Generate your personalized Ethiopian weekly plan with automatic Orthodox and Ramadan fasting alignment.'
                  : 'Personalized 7-day fasting plans and Teff recipes require an active EthioNutri Premium subscription.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Color(0xFF78716C),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(
              height: 22,
            ),
            ElevatedButton.icon(
              onPressed:
                  _generateMealPlan,
              icon: Icon(
                _isPremium
                    ? Icons.bolt_rounded
                    : Icons
                        .lock_outline_rounded,
                size: 18,
              ),
              label: Text(
                _isPremium
                    ? 'Generate Plan with AI'
                    : 'Upgrade to Unlock Meal Plan',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF542E13,
                ),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// RAW AI MEAL PLAN RESPONSE VIEW
  /// ============================================================

  Widget _buildRawAiPlanView(
    String aiText,
  ) {
    return RefreshIndicator(
      color:
          const Color(0xFF542E13),
      onRefresh:
          _fetchMealPlan,
      child: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'AI Meal Plan',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 18,
                    color:
                        Color(
                      0xFF542E13,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    _generateMealPlan,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color:
                      Color(0xFF8D4F28),
                  size: 18,
                ),
                label:
                    const Text(
                  'Regenerate',
                  style:
                      TextStyle(
                    color:
                        Color(0xFF8D4F28),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 6,
          ),
          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFEF3C7,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFFDE68A,
                ),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color:
                      Color(0xFF92400E),
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'The AI returned a meal plan response in text format. The response is displayed below.',
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFF78350F,
                      ),
                      fontSize:
                          12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFEADBCE,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(
                    0.025,
                  ),
                  blurRadius: 10,
                  offset:
                      const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: SelectableText(
              aiText,
              style:
                  const TextStyle(
                color:
                    Color(0xFF1C1917),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          ElevatedButton.icon(
            onPressed:
                _generateMealPlan,
            icon: const Icon(
              Icons.bolt_rounded,
              size: 19,
            ),
            label: const Text(
              'Generate Another Plan',
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(
                0xFF542E13,
              ),
              foregroundColor:
                  Colors.white,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// GROCERY TAB
  /// ============================================================

  Widget _buildGroceryTab() {
    if (_isLoadingGrocery) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              Color(0xFF542E13),
        ),
      );
    }

    final hasGroceryText =
        _groceryText.trim().isNotEmpty;

    return RefreshIndicator(
      color:
          const Color(0xFF542E13),
      onRefresh:
          _fetchGroceryList,
      child: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          /// ======================================================
          /// HEADER
          /// ======================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'AI Grocery List',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(
                          0xFF542E13,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Generated from your active meal plan',
                      style:
                          TextStyle(
                        fontSize: 12,
                        color:
                            Color(
                          0xFF78716C,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              ElevatedButton.icon(
                onPressed:
                    _generateGrocery,
                icon: Icon(
                  _isPremium
                      ? Icons
                          .sync_rounded
                      : Icons
                          .lock_outline_rounded,
                  size: 16,
                ),
                label: Text(
                  _isPremium
                      ? 'Generate'
                      : 'Unlock',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF542E13,
                  ),
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          /// ======================================================
          /// INFORMATION BANNER
          /// ======================================================

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFEF3C7,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFFDE68A,
                ),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Icon(
                  Icons
                      .auto_awesome_rounded,
                  color:
                      Color(0xFF92400E),
                  size: 21,
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'The AI creates a practical grocery list based on your current meal plan. The response is displayed directly as text.',
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFF78350F,
                      ),
                      fontSize:
                          12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          /// ======================================================
          /// EMPTY STATE
          /// ======================================================

          if (!hasGroceryText)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFEADBCE,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(
                        0xFFF5EBE1,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons
                          .shopping_basket_outlined,
                      size: 31,
                      color:
                          Color(
                        0xFF8D4F28,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  const Text(
                    'No Grocery List Yet',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xFF542E13,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  const Text(
                    'Generate a grocery list from your active meal plan.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFF78716C,
                      ),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _generateGrocery,
                    icon: Icon(
                      _isPremium
                          ? Icons
                              .bolt_rounded
                          : Icons
                              .lock_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isPremium
                          ? 'Generate Grocery List'
                          : 'Upgrade to Generate',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF542E13,
                      ),
                      foregroundColor:
                          Colors.white,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

          /// ======================================================
          /// AI GROCERY RESPONSE
          /// ======================================================

          if (hasGroceryText)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                18,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFEADBCE,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(
                      0.025,
                    ),
                    blurRadius: 10,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: SelectableText(
                _groceryText,
                style:
                    const TextStyle(
                  color:
                      Color(0xFF1C1917),
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),

          if (hasGroceryText)
            const SizedBox(
              height: 18,
            ),

          /// ======================================================
          /// REGENERATE BUTTON
          /// ======================================================

          if (hasGroceryText)
            ElevatedButton.icon(
              onPressed:
                  _generateGrocery,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 19,
              ),
              label: const Text(
                'Generate New Grocery List',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF542E13,
                ),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                elevation: 0,
              ),
            ),

          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }
}

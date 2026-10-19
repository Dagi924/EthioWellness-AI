import 'package:flutter/material.dart';

import '../services/meal_plan_service.dart';
import '../services/auth_service.dart';
import '../services/app_localization.dart';
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

  String _t(String key) {
    return AppLocalization.instance.tr(key);
  }

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

  // ============================================================
  // PREMIUM + INITIAL LOAD
  // ============================================================

  Future<void> _checkPremiumAndLoad() async {
    try {
      final isPrem = await AuthService.isPremiumUser();

      if (!mounted) return;

      setState(() {
        _isPremium = isPrem;
      });

      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      _showSnackbar(
        '${_t('meal_account_load_failed')}: $e',
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

  // ============================================================
  // FETCH MEAL PLAN
  // ============================================================

  Future<void> _fetchMealPlan() async {
    if (mounted) {
      setState(() {
        _isLoadingMealPlan = true;
      });
    }

    try {
      final plan = await MealPlanService.getCurrentPlan();

      if (!mounted) return;

      setState(() {
        _mealPlan = plan;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          '${_t('meal_plan_load_failed')}: $e',
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

  // ============================================================
  // GENERATE MEAL PLAN
  // ============================================================

  Future<void> _generateMealPlan() async {
    if (!_isPremium) {
      _showUpgradeModal(
        _t('meal_premium_plan_required'),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingMealPlan = true;
      });
    }

    try {
      final plan = await MealPlanService.generateMealPlan();

      if (!mounted) return;

      setState(() {
        _mealPlan = plan;
      });

      if (plan.planDays.isNotEmpty) {
        _showSnackbar(
          '✨ ${_t('meal_plan_generated_success')}',
        );
      } else if (plan.rawAiText.isNotEmpty) {
        _showSnackbar(
          '✨ ${_t('meal_plan_text_generated')}',
        );
      } else {
        _showSnackbar(
          _t('meal_plan_empty_response'),
          isError: true,
        );
      }
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(e.message);
    } catch (e) {
      _showSnackbar(
        '${_t('meal_plan_generation_failed')}: $e',
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

  // ============================================================
  // FETCH GROCERY LIST
  // ============================================================

  Future<void> _fetchGroceryList() async {
    if (mounted) {
      setState(() {
        _isLoadingGrocery = true;
      });
    }

    try {
      final data = await MealPlanService.getGroceryList();

      if (!mounted) return;

      final groceryText =
          data['groceryText']?.toString() ?? '';

      setState(() {
        _groceryText = groceryText.trim();
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          '${_t('grocery_load_failed')}: $e',
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

  // ============================================================
  // GENERATE GROCERY LIST
  // ============================================================

  Future<void> _generateGrocery() async {
    if (!_isPremium) {
      _showUpgradeModal(
        _t('grocery_premium_required'),
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
          _t('grocery_empty_response'),
          isError: true,
        );
        return;
      }

      setState(() {
        _groceryText = groceryText.trim();
      });

      _showSnackbar(
        '🛒 ${_t('grocery_generated_success')}',
      );
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(e.message);
    } catch (e) {
      _showSnackbar(
        '${_t('grocery_generation_failed')}: $e',
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

  // ============================================================
  // UPGRADE MODAL
  // ============================================================

  void _showUpgradeModal(String reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFB45309),
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _t('meal_upgrade_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF542E13),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF78716C),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
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
              onPressed: () {
                Navigator.pop(ctx);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ChapaPaymentScreen(),
                  ),
                ).then((_) {
                  if (mounted) {
                    _checkPremiumAndLoad();
                  }
                });
              },
              child: Text(
                _t('meal_unlock_premium'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackbar(
    String text, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF542E13),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),
      appBar: AppBar(
        title: Text(
          _t('meal_grocery_screen_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF542E13),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showUpgradeModal(
                  _t('meal_premium_unlock_description'),
                ),
                icon: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFBBF24),
                  size: 18,
                ),
                label: Text(
                  _t('meal_free_tier'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF43240E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFEADBCE),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor:
                  Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
              tabs: [
                Tab(
                  icon: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 19,
                  ),
                  text: _t('meal_tab_seven_day_plan'),
                ),
                Tab(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    size: 19,
                  ),
                  text: _t('meal_tab_market_grocery'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMealPlanTab(),
          _buildGroceryTab(),
        ],
      ),
    );
  }

  // ============================================================
  // MEAL PLAN TAB
  // ============================================================

  Widget _buildMealPlanTab() {
    if (_isLoadingMealPlan) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF542E13),
        ),
      );
    }

    if (_mealPlan == null) {
      return _buildNoMealPlanView();
    }

    if (_mealPlan!.planDays.isEmpty &&
        _mealPlan!.rawAiText.trim().isNotEmpty) {
      return _buildRawAiPlanView(
        _mealPlan!.rawAiText,
      );
    }

    if (_mealPlan!.planDays.isEmpty) {
      return _buildNoMealPlanView();
    }

    return RefreshIndicator(
      color: const Color(0xFF542E13),
      onRefresh: _fetchMealPlan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _t('meal_current_weekly_plan'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF542E13),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _generateMealPlan,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF8D4F28),
                  size: 18,
                ),
                label: Text(
                  _t('meal_regenerate'),
                  style: const TextStyle(
                    color: Color(0xFF8D4F28),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._mealPlan!.planDays.map(
            (day) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _translatedDay(day.day),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                        ),
                        if (day.isFasting)
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
                              _t('meal_fasting_badge'),
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(
                      height: 18,
                      color: Color(0xFFEFE8DF),
                    ),
                    if (day.meals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        child: Text(
                          _t('meal_no_structured_meals'),
                          style: const TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ...day.meals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_translatedMealType(m.mealType).toUpperCase()}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF965126),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${m.foodName} (${m.calories.toInt()} ${_t('meal_kcal')} • ${_t('meal_protein_short')}: ${m.proteinGrams}g)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1C1917),
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

  String _translatedDay(String day) {
    final normalized = day.trim().toLowerCase();

    const dayKeys = {
      'monday': 'meal_day_monday',
      'tuesday': 'meal_day_tuesday',
      'wednesday': 'meal_day_wednesday',
      'thursday': 'meal_day_thursday',
      'friday': 'meal_day_friday',
      'saturday': 'meal_day_saturday',
      'sunday': 'meal_day_sunday',
    };

    final key = dayKeys[normalized];

    return key == null ? day : _t(key);
  }

  String _translatedMealType(String mealType) {
    final normalized = mealType.trim().toLowerCase();

    const mealKeys = {
      'breakfast': 'meal_type_breakfast',
      'lunch': 'meal_type_lunch',
      'dinner': 'meal_type_dinner',
      'snack': 'meal_type_snack',
      'snacks': 'meal_type_snack',
    };

    final key = mealKeys[normalized];

    return key == null ? mealType : _t(key);
  }

  // ============================================================
  // NO MEAL PLAN VIEW
  // ============================================================

  Widget _buildNoMealPlanView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: Color(0xFF8D4F28),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _t('meal_no_active_plan'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF542E13),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isPremium
                  ? _t('meal_generate_personalized_description')
                  : _t('meal_premium_plan_required'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF78716C),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _generateMealPlan,
              icon: Icon(
                _isPremium
                    ? Icons.bolt_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
              ),
              label: Text(
                _isPremium
                    ? _t('meal_generate_plan_ai')
                    : _t('meal_upgrade_unlock_plan'),
                textAlign: TextAlign.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RAW AI MEAL PLAN RESPONSE
  // ============================================================

  Widget _buildRawAiPlanView(String aiText) {
    return RefreshIndicator(
      color: const Color(0xFF542E13),
      onRefresh: _fetchMealPlan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('meal_ai_meal_plan'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF542E13),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _generateMealPlan,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF8D4F28),
                  size: 18,
                ),
                label: Text(
                  _t('meal_regenerate'),
                  style: const TextStyle(
                    color: Color(0xFF8D4F28),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF92400E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t('meal_raw_ai_description'),
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEADBCE),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SelectableText(
              aiText,
              style: const TextStyle(
                color: Color(0xFF1C1917),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _generateMealPlan,
            icon: const Icon(
              Icons.bolt_rounded,
              size: 19,
            ),
            label: Text(
              _t('meal_generate_another_plan'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF542E13),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GROCERY TAB
  // ============================================================

  Widget _buildGroceryTab() {
    if (_isLoadingGrocery) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF542E13),
        ),
      );
    }

    final hasGroceryText = _groceryText.trim().isNotEmpty;

    return RefreshIndicator(
      color: const Color(0xFF542E13),
      onRefresh: _fetchGroceryList,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('grocery_ai_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF542E13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('grocery_active_plan_subtitle'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _generateGrocery,
                icon: Icon(
                  _isPremium
                      ? Icons.sync_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                ),
                label: Text(
                  _isPremium
                      ? _t('grocery_generate')
                      : _t('grocery_unlock'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // INFORMATION BANNER

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF92400E),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t('grocery_ai_description'),
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // EMPTY STATE

          if (!hasGroceryText)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5EBE1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_basket_outlined,
                      size: 31,
                      color: Color(0xFF8D4F28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('grocery_no_list_yet'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF542E13),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _t('grocery_empty_description'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _generateGrocery,
                    icon: Icon(
                      _isPremium
                          ? Icons.bolt_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isPremium
                          ? _t('grocery_generate_list')
                          : _t('grocery_upgrade_to_generate'),
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF542E13),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

          // AI GROCERY RESPONSE

          if (hasGroceryText)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                _groceryText,
                style: const TextStyle(
                  color: Color(0xFF1C1917),
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),

          if (hasGroceryText)
            const SizedBox(height: 18),

          // REGENERATE BUTTON

          if (hasGroceryText)
            ElevatedButton.icon(
              onPressed: _generateGrocery,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 19,
              ),
              label: Text(
                _t('grocery_generate_new_list'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
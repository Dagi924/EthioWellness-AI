import 'package:flutter/material.dart';
import '../services/meal_plan_service.dart';
import '../services/auth_service.dart';
import '../models/meal_plan_model.dart';
import 'chapa_payment_screen.dart';

class GroceryItem {
  final String id;
  final String name;
  final String category;
  String quantity;
  final double estimatedPriceEtb;
  bool isChecked;

  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.estimatedPriceEtb,
    required this.isChecked,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      quantity: json['quantity'] ?? '1 unit',
      estimatedPriceEtb: (json['estimatedPriceEtb'] as num?)?.toDouble() ?? 0.0,
      isChecked: json['isChecked'] ?? false,
    );
  }
}

class MealAndGroceryScreen extends StatefulWidget {
  const MealAndGroceryScreen({super.key});

  @override
  State<MealAndGroceryScreen> createState() => _MealAndGroceryScreenState();
}

class _MealAndGroceryScreenState extends State<MealAndGroceryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isPremium = false;
  bool _isLoadingMealPlan = false;
  MealPlanModel? _mealPlan;

  bool _isLoadingGrocery = false;
  List<GroceryItem> _groceryItems = [];
  double _estimatedTotalEtb = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPremiumAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumAndLoad() async {
    final isPrem = await AuthService.isPremiumUser();
    if (mounted) setState(() => _isPremium = isPrem);
    await _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _fetchMealPlan(),
      _fetchGroceryList(),
    ]);
  }

  Future<void> _fetchMealPlan() async {
    setState(() => _isLoadingMealPlan = true);
    try {
      final plan = await MealPlanService.getCurrentPlan();
      if (mounted) setState(() => _mealPlan = plan);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMealPlan = false);
    }
  }

  Future<void> _generateMealPlan() async {
    if (!_isPremium) {
      _showUpgradeModal('AI 7-Day Fasting Meal Plans are exclusive to EthioNutri Premium members.');
      return;
    }

    setState(() => _isLoadingMealPlan = true);
    try {
      final plan = await MealPlanService.generateMealPlan();
      if (mounted) {
        setState(() => _mealPlan = plan);
        _showSnackbar('✨ New Ethiopian 7-Day Fasting Plan generated!');
      }
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(e.message);
    } catch (e) {
      _showSnackbar('Generation failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingMealPlan = false);
    }
  }

  Future<void> _fetchGroceryList() async {
    setState(() => _isLoadingGrocery = true);
    try {
      final data = await MealPlanService.getGroceryList();
      if (mounted) {
        setState(() {
          _groceryItems = (data['items'] as List)
              .map((item) => GroceryItem.fromJson(item))
              .toList();
          _estimatedTotalEtb = data['estimatedTotalEtb'] ?? 0.0;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGrocery = false);
    }
  }

  Future<void> _generateGrocery() async {
    if (!_isPremium) {
      _showUpgradeModal('Automated Ethiopian Market Grocery Pricing (ETB) requires EthioNutri Premium.');
      return;
    }

    setState(() => _isLoadingGrocery = true);
    try {
      final data = await MealPlanService.generateGroceryList();
      if (mounted) {
        setState(() {
          _groceryItems = (data['items'] as List)
              .map((item) => GroceryItem.fromJson(item))
              .toList();
          _estimatedTotalEtb = data['estimatedTotalEtb'] ?? 0.0;
        });
        _showSnackbar('🛒 Grocery list generated with Ethiopian ETB market prices!');
      }
    } on PremiumRequiredException catch (e) {
      _showUpgradeModal(e.message);
    } catch (e) {
      _showSnackbar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingGrocery = false);
    }
  }

  Future<void> _toggleItem(GroceryItem item) async {
    final original = item.isChecked;
    setState(() => item.isChecked = !original);
    try {
      await MealPlanService.updateGroceryItem(id: item.id, isChecked: item.isChecked);
    } catch (e) {
      setState(() => item.isChecked = original);
      _showSnackbar('Failed to update item: $e', isError: true);
    }
  }

  Future<void> _deleteItem(GroceryItem item) async {
    try {
      await MealPlanService.deleteGroceryItem(item.id);
      setState(() {
        _groceryItems.removeWhere((i) => i.id == item.id);
        _estimatedTotalEtb -= item.estimatedPriceEtb;
      });
      _showSnackbar('Item removed');
    } catch (e) {
      _showSnackbar('Failed to delete item: $e', isError: true);
    }
  }

  void _showUpgradeModal(String reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309), size: 38),
            ),
            const SizedBox(height: 14),
            const Text(
              'Upgrade to EthioNutri Premium',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF78716C), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13), // Brown Theme Unlock
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChapaPaymentScreen()),
                ).then((_) => _checkPremiumAndLoad());
              },
              child: const Text(
                'Unlock Premium (299 ETB / mo)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF542E13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: const Text(
          'Meal Plan & Market Grocery',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF542E13), // Warm Cognac Brown AppBar
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showUpgradeModal('Unlock unlimited AI plans and ETB grocery pricing.'),
                icon: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                label: const Text(
                  'Free Tier',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              tabs: const [
                Tab(icon: Icon(Icons.restaurant_menu_rounded, size: 19), text: '7-Day Plan'),
                Tab(icon: Icon(Icons.shopping_cart_outlined, size: 19), text: 'Market Grocery (ETB)'),
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

  Widget _buildMealPlanTab() {
    if (_isLoadingMealPlan) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF542E13)));
    }

    if (_mealPlan == null || _mealPlan!.planDays.isEmpty) {
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
                child: const Icon(Icons.auto_awesome_rounded, size: 36, color: Color(0xFF8D4F28)),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Active Meal Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
              ),
              const SizedBox(height: 8),
              Text(
                _isPremium
                    ? 'Generate your personalized Ethiopian weekly plan with automatic Orthodox and Ramadan fasting alignment.'
                    : 'Personalized 7-day fasting plans and Teff recipes require an active EthioNutri Premium subscription.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF78716C), fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _generateMealPlan,
                icon: Icon(_isPremium ? Icons.bolt_rounded : Icons.lock_outline_rounded, size: 18),
                label: Text(_isPremium ? 'Generate Plan with AI' : 'Upgrade to Unlock Meal Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
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
              const Text(
                'Current Weekly Plan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF542E13)),
              ),
              TextButton.icon(
                onPressed: _generateMealPlan,
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8D4F28), size: 18),
                label: const Text('Regenerate', style: TextStyle(color: Color(0xFF8D4F28), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._mealPlan!.planDays.map((day) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEADBCE)),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            day.day,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1C1917)),
                          ),
                          if (day.isFasting)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Text(
                                'ጾም / Fasting',
                                style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 18, color: Color(0xFFEFE8DF)),
                      ...day.meals.map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m.mealType.toUpperCase()}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF965126)),
                                ),
                                Expanded(
                                  child: Text(
                                    '${m.foodName} (${m.calories.toInt()} kcal • P: ${m.proteinGrams}g)',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1C1917)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGroceryTab() {
    if (_isLoadingGrocery) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF542E13)));
    }

    return Column(
      children: [
        // Top Total Price Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEADBCE))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_groceryItems.length} Items Listed',
                    style: const TextStyle(color: Color(0xFF78716C), fontSize: 12),
                  ),
                  Text(
                    'Est. Total: ${_estimatedTotalEtb.toStringAsFixed(1)} ETB',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF542E13), // Brown Price Heading
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _generateGrocery,
                icon: Icon(_isPremium ? Icons.sync_rounded : Icons.lock_outline_rounded, size: 16),
                label: Text(_isPremium ? 'Sync from Plan' : 'Unlock Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _groceryItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5EBE1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_basket_outlined, size: 30, color: Color(0xFF8D4F28)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Grocery list is empty',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
                      ),
                      TextButton(
                        onPressed: _generateGrocery,
                        child: const Text(
                          'Generate from Active Meal Plan',
                          style: TextStyle(color: Color(0xFF8D4F28), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: _groceryItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = _groceryItems[idx];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteItem(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEADBCE)),
                        ),
                        child: CheckboxListTile(
                          value: item.isChecked,
                          activeColor: const Color(0xFF542E13), // Brown checkbox
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          onChanged: (_) => _toggleItem(item),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              decoration: item.isChecked ? TextDecoration.lineThrough : null,
                              color: item.isChecked ? const Color(0xFFA8A29E) : const Color(0xFF1C1917),
                            ),
                          ),
                          subtitle: Text(
                            '${item.category} • Qty: ${item.quantity}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                          ),
                          secondary: Text(
                            '${item.estimatedPriceEtb.toStringAsFixed(1)} ETB',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF965126),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
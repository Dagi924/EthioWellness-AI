import 'package:flutter/material.dart';
import '../services/food_log_service.dart';
import '../services/fasting_service.dart';
import '../models/fasting_schedule_model.dart';
import 'food_scanner_screen.dart';
import 'food_search_screen.dart';
import 'chapa_payment_screen.dart';
import 'nutritionist_screen.dart';
import 'ai_chat_screen.dart';

class MealLoggerScreen extends StatefulWidget {
  const MealLoggerScreen({super.key});

  @override
  State<MealLoggerScreen> createState() => _MealLoggerScreenState();
}

class _MealLoggerScreenState extends State<MealLoggerScreen> {
  Map<String, dynamic>? _todayData;
  FastingScheduleModel? _fastingStatus;
  bool _isLoading = true;
  bool _showTips = false;
  String _selectedDateFilter = 'today';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final logsRes = await FoodLogService.getTodayLogs();
      FastingScheduleModel? fastRes;
      try {
        fastRes = await FastingService.getTodayFasting();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _todayData = logsRes;
          _fastingStatus = fastRes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load error: $e'),
            backgroundColor: const Color(0xFF542E13),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logWater() async {
    try {
      await FoodLogService.logWater(250);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging water: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _todayData?['totals'] ?? {};
    final logs = (_todayData?['logs'] as List?) ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 860;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm heritage sand background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F2EA),
            border: Border(bottom: BorderSide(color: Color(0xFFEADBCE), width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand Title & Heritage Subtitle
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF542E13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'EthioNutri AI',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF542E13),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Today\'s Nutrition & Fasting',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF78716C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Center Title on wider screens
                if (isWide)
                  const Text(
                    'Food Logging & Nutrition',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D4F28), // Warm terracotta
                    ),
                  ),

                // Top Right Action Controls: Message, Premium, Dietitian, Camera, Refresh
                Row(
                  children: [
                    // 💬 Message / AI Chat Screen Icon
                    _circleButton(
                      Icons.chat_bubble_outline_rounded,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiChatScreen()),
                      ),
                      tooltip: 'AI Nutrition Chat',
                      badgeColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 7),

                    // ⭐ Premium Upgrade Icon (Chapa Payment)
                    _circleButton(
                      Icons.workspace_premium_outlined,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChapaPaymentScreen()),
                      ),
                      tooltip: 'Upgrade to Premium',
                      iconColor: const Color(0xFFB45309),
                      backgroundColor: const Color(0xFFFEF3C7),
                    ),
                    const SizedBox(width: 7),

                    // 🩺 Dietitian Supervision Icon
                    _circleButton(
                      Icons.medical_services_outlined,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NutritionistScreen()),
                      ),
                      tooltip: 'Dietitian Supervision',
                    ),
                    const SizedBox(width: 7),

                    // 📷 AI Food Scanner Camera
                    _circleButton(
                      Icons.camera_alt_outlined,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
                      ).then((_) => _loadData()),
                      tooltip: 'AI Food Scanner',
                    ),
                    const SizedBox(width: 7),

                    // 🔄 Refresh Nutrients
                    _circleButton(
                      Icons.refresh_rounded,
                      _loadData,
                      tooltip: 'Refresh Nutrients',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF542E13)),
            )
          : RefreshIndicator(
              color: const Color(0xFF542E13),
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mobile Screen Title
                    if (!isWide)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Food Logging',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8D4F28),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sync, color: Color(0xFF542E13)),
                              onPressed: _loadData,
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                      ),

                    // --- Date Selector Pills & Log Search Bar ---
                    _buildDateAndSearchFilter(),
                    const SizedBox(height: 16),

                    // --- Quick Action Cards (Voice Log & Manual Entry) ---
                    _buildQuickActionCards(),
                    const SizedBox(height: 20),

                    // --- Main Body (Split for Wide, Stacked for Mobile) ---
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Meals List
                          Expanded(
                            flex: 13,
                            child: Column(
                              children: [
                                if (_fastingStatus != null) _buildFastingBanner(_fastingStatus!),
                                _buildMealSection(
                                  title: 'Breakfast (የቁርስ ሰዓት)',
                                  targetRange: 'Target: 400 - 500 kcal',
                                  mealType: 'breakfast',
                                  logs: logs,
                                ),
                                const SizedBox(height: 16),
                                _buildMealSection(
                                  title: 'Lunch (የምሳ ሰዓት)',
                                  targetRange: 'Target: 600 - 750 kcal',
                                  mealType: 'lunch',
                                  logs: logs,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Column: Daily Running Totals Ring & Macro Summary
                          Expanded(
                            flex: 9,
                            child: Column(
                              children: [
                                _buildDailyRunningTotalsCard(totals),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildDailyRunningTotalsCard(totals),
                          const SizedBox(height: 16),
                          if (_fastingStatus != null) _buildFastingBanner(_fastingStatus!),
                          const SizedBox(height: 16),
                          _buildMealSection(
                            title: 'Breakfast (የቁርስ ሰዓት)',
                            targetRange: 'Target: 400 - 500 kcal',
                            mealType: 'breakfast',
                            logs: logs,
                          ),
                          const SizedBox(height: 16),
                          _buildMealSection(
                            title: 'Lunch & Dinner (የምሳ እና ራት ሰዓት)',
                            targetRange: 'Target: 800 - 1000 kcal',
                            mealType: 'lunch_dinner',
                            logs: logs,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
        ).then((_) => _loadData()),
        backgroundColor: const Color(0xFF542E13),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.search),
        label: const Text(
          'Search FAO Food',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
    );
  }

  // --- Date Filter Pills and Search Bar ---
  Widget _buildDateAndSearchFilter() {
    return Row(
      children: [
        // Date Pills
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFEADBCE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _datePill('yesterday', 'Yesterday'),
              _datePill('today', 'Today (Wed Fast)'),
              _datePill('tomorrow', 'Tomorrow'),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Search Bar Pill
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEADBCE)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFFA8A29E), size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search logged foods, Injera, Misir, Shiro...',
                      hintStyle: TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1C1917)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _datePill(String id, String label) {
    final isSelected = _selectedDateFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedDateFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF542E13) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF78716C),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  // --- Voice Log and Manual Entry Action Cards ---
  Widget _buildQuickActionCards() {
    return Row(
      children: [
        // Voice Log Card
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
            ).then((_) => _loadData()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEADBCE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5EBE1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_none_rounded, color: Color(0xFF8D4F28), size: 22),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Voice Log',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AI Speech Transcription',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Manual Entry Card
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
            ).then((_) => _loadData()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEADBCE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDECE3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, color: Color(0xFF8D4F28), size: 22),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Manual Entry',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ethiopian Food Presets',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Meal Group Card with Sunrise Icon and Food Items ---
  Widget _buildMealSection({
    required String title,
    required String targetRange,
    required String mealType,
    required List logs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              // Sunrise Icon badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    Text(
                      targetRange,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                    ),
                  ],
                ),
              ),
              // Macro Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EBE1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '320 kcal • 8g protein',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF542E13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // + Add Food Outlined Button
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
                ).then((_) => _loadData()),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF542E13)),
                  foregroundColor: const Color(0xFF542E13),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text(
                  '+ Add Food',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Logged Food Item Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F4), // Warm sand item container
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEFE8DF)),
            ),
            child: Row(
              children: [
                // Food Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: const Color(0xFFEADBCE),
                    child: const Icon(Icons.restaurant, color: Color(0xFF8D4F28), size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kinche with Olive Oil / Niter Kibbeh',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1C1917)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'ቂንጬ በቅቤ/ዘይት',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF78716C)),
                          ),
                          const SizedBox(width: 8),
                          // Tsom Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5EBE1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.eco, size: 10, color: Color(0xFF8D4F28)),
                                SizedBox(width: 2),
                                Text(
                                  'Tsom',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Macro Values
                Row(
                  children: [
                    _macroBadge('320', 'kcal', const Color(0xFF8D4F28)),
                    const SizedBox(width: 6),
                    _macroBadge('8g', 'P', const Color(0xFF542E13)),
                    const SizedBox(width: 6),
                    _macroBadge('58g', 'C', const Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    _macroBadge('7g', 'F', const Color(0xFFD97706)),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFA8A29E), size: 18),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBadge(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9.5, color: color.withOpacity(0.8))),
      ],
    );
  }

  // --- Right Side / Mobile Daily Running Totals Ring Gauge ---
  Widget _buildDailyRunningTotalsCard(Map<dynamic, dynamic> totals) {
    final calConsumed = totals['calories'] ?? 320;
    final calTarget = 2000;
    final progress = (calConsumed / calTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Daily Running Totals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Wednesday Fast • 100% Plant-Based',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8D4F28), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
                tooltip: '+250ml Water',
                onPressed: _logWater,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular Calorie Gauge
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFFF0EAE1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF542E13)),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$calConsumed',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF542E13),
                        ),
                      ),
                      const Text(
                        'kcal consumed',
                        style: TextStyle(fontSize: 11, color: Color(0xFF78716C)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Macro Breakdown Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroProgressItem('Protein', '${totals['proteinGrams'] ?? 8}g', const Color(0xFF8D4F28)),
              _macroProgressItem('Carbs', '${totals['carbsGrams'] ?? 58}g', const Color(0xFF2563EB)),
              _macroProgressItem('Fats', '${totals['fatsGrams'] ?? 7}g', const Color(0xFFD97706)),
              _macroProgressItem('Water', '${totals['waterMl'] ?? 250}ml', const Color(0xFF0284C7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroProgressItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF78716C)),
        ),
      ],
    );
  }

  Widget _buildFastingBanner(FastingScheduleModel fast) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFFDE68A),
                child: Icon(Icons.church_outlined, color: Color(0xFFB45309), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fast.displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF542E13),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STRICT VEGAN',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fast.advice,
            style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF78350F)),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    Color? iconColor,
    Color? backgroundColor,
    Color? badgeColor,
  }) {
    Widget btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: backgroundColor != null ? const Color(0xFFFED7AA) : const Color(0xFFEADBCE),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? const Color(0xFF542E13),
        ),
      ),
    );

    if (badgeColor != null) {
      btn = Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: btn,
      );
    }

    return btn;
  }
}
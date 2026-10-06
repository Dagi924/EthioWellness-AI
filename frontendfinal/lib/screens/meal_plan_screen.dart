import 'package:flutter/material.dart';
import '../models/meal_plan_model.dart';
import '../services/meal_plan_service.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  MealPlanModel? _planData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
  }

  Future<void> _fetchCurrentPlan() async {
    setState(() => _isLoading = true);
    try {
      final plan = await MealPlanService.getCurrentPlan();
      if (mounted) {
        setState(() => _planData = plan);
      }
    } catch (_) {
      // Graceful fallback when no plan is currently active
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateNewPlan() async {
    setState(() => _isLoading = true);
    try {
      final plan = await MealPlanService.generateMealPlan();
      if (mounted) {
        setState(() => _planData = plan);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF542E13),
            content: Text('Personalized Ethiopian 7-Day Meal Plan Generated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Canvas
      appBar: AppBar(
        title: const Text(
          'AI Ethiopian Meal Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Generate New Plan',
            onPressed: _generateNewPlan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF542E13)),
            )
          : _planData == null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEADBCE)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF542E13).withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5EBE1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 48,
                              color: Color(0xFF8D4F28),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Personalized 7-Day Plan',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1917),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Tailored for Orthodox & Ramadan fasting schedules, Teff Injera, Shiro, and high-iron Ethiopian nutrition.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF78716C),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _generateNewPlan,
                              icon: const Icon(Icons.bolt_rounded, size: 20),
                              label: const Text(
                                'Generate 7-Day Plan',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF542E13),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBE1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEADBCE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF8D4F28),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _planData!.summary.isNotEmpty
                                  ? _planData!.summary
                                  : 'Custom Ethiopian Heritage Nutrition Plan',
                              style: const TextStyle(
                                color: Color(0xFF542E13),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._planData!.planDays.map((day) => Container(
                          margin: const EdgeInsets.only(bottom: 14),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1C1917),
                                      ),
                                    ),
                                    if (day.isFasting)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield_outlined,
                                              size: 13,
                                              color: Color(0xFF92400E),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tsom / Fasting (ጾም)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const Divider(height: 20, color: Color(0xFFEFE8DF)),
                                ...day.meals.map((m) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            margin: const EdgeInsets.only(right: 8, top: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F3EC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFEADBCE),
                                              ),
                                            ),
                                            child: Text(
                                              m.mealType.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10.5,
                                                color: Color(0xFF542E13),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${m.foodName} (${m.calories.toInt()} kcal, ${m.proteinGrams}g P, ${m.ironMg}mg Fe)',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF44403C),
                                                height: 1.35,
                                              ),
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
}
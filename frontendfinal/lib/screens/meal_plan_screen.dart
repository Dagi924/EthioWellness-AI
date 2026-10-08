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
    setState(() {
      _isLoading = true;
    });

    try {
      final plan = await MealPlanService.getCurrentPlan();

      if (!mounted) return;

      setState(() {
        _planData = plan;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _planData = null;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plan =
          await MealPlanService.generateMealPlan();

      if (!mounted) return;

      setState(() {
        _planData = plan;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Personalized meal and exercise plan generated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generation failed: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _extractExercisePlan() {
    if (_planData == null) {
      return {};
    }

    final dynamic raw = _planData!.rawPlanData;

    if (raw is! Map) {
      return {};
    }

    final exercisePlan =
        raw['exercisePlan'];

    if (exercisePlan is Map) {
      return Map<String, dynamic>.from(
        exercisePlan,
      );
    }

    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F2EA),

      appBar: AppBar(
        title: const Text(
          'AI Personalized Plan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17.5,
          ),
        ),
        backgroundColor:
            const Color(0xFF542E13),
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded),
            tooltip:
                'Generate New Plan',
            onPressed:
                _isLoading
                    ? null
                    : _generateNewPlan,
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFF542E13),
              ),
            )
          : _planData == null
              ? _buildEmptyState()
              : _buildPlan(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 520,
          ),
          padding:
              const EdgeInsets.all(26),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(24),
            border: Border.all(
              color:
                  const Color(0xFFEADBCE),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(16),
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFFF5EBE1),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color:
                      Color(0xFF8D4F28),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'No Personalized Plan',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF1C1917),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Generate a plan using your saved profile information.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Color(0xFF78716C),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _generateNewPlan,
                  icon: const Icon(
                    Icons.bolt_rounded,
                  ),
                  label:
                      const Text(
                    'Generate Plan',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                            0xFF542E13),
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
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

  Widget _buildPlan() {
    final exercisePlan =
        _extractExercisePlan();

    return RefreshIndicator(
      color:
          const Color(0xFF542E13),
      onRefresh:
          _fetchCurrentPlan,
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          if (_planData!
              .summary
              .trim()
              .isNotEmpty)
            _buildSummary(),

          const SizedBox(height: 18),

          _buildSectionTitle(
            'Meal Plan',
            Icons.restaurant_menu_rounded,
          ),

          const SizedBox(height: 10),

          ..._planData!.planDays.map(
            _buildMealDay,
          ),

          const SizedBox(height: 24),

          if (exercisePlan.isNotEmpty) ...[
            _buildSectionTitle(
              'Exercise Plan',
              Icons.fitness_center_rounded,
            ),

            const SizedBox(height: 10),

            _buildExercisePlan(
              exercisePlan,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF5EBE1),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.eco_rounded,
            color:
                Color(0xFF8D4F28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _planData!.summary,
              style:
                  const TextStyle(
                color:
                    Color(0xFF542E13),
                fontWeight:
                    FontWeight.w600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color:
              const Color(0xFF542E13),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xFF1C1917),
          ),
        ),
      ],
    );
  }

  Widget _buildMealDay(
    dynamic day,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.day,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                      color:
                          Color(0xFF1C1917),
                    ),
                  ),
                ),

                if (day.isFasting)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                              0xFFFEF3C7),
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child:
                        const Text(
                      'Fasting',
                      style:
                          TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(
                                0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),

            const Divider(
              height: 20,
            ),

            ...day.meals.map(
              (meal) {
                return Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                                  0xFFF8F3EC),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            6,
                          ),
                        ),
                        child: Text(
                          meal.mealType
                              .toUpperCase(),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 10,
                            color:
                                Color(
                                    0xFF542E13),
                          ),
                        ),
                      ),

                      const SizedBox(
                          width: 8),

                      Expanded(
                        child: Text(
                          '${meal.foodName} • '
                          '${meal.calories.toInt()} kcal • '
                          '${meal.proteinGrams}g protein • '
                          '${meal.ironMg}mg iron',
                          style:
                              const TextStyle(
                            fontSize: 13,
                            color:
                                Color(
                                    0xFF44403C),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisePlan(
    Map<String, dynamic> plan,
  ) {
    final summary =
        plan['summary']?.toString() ?? '';

    final days =
        plan['days'] is List
            ? List<dynamic>.from(
                plan['days'],
              )
            : <dynamic>[];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFE8F5E9),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Text(
              summary,
              style:
                  const TextStyle(
                fontSize: 13,
                color:
                    Color(0xFF2E7D32),
              ),
            ),
          ),

        const SizedBox(height: 12),

        ...days.map(
          (day) => _buildExerciseDay(
            day,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseDay(
    dynamic day,
  ) {
    final dayName =
        day['day']?.toString() ??
            '';

    final focus =
        day['focus']?.toString() ??
            '';

    final restDay =
        day['restDay'] == true;

    final exercises =
        day['exercises'] is List
            ? List<dynamic>.from(
                day['exercises'],
              )
            : <dynamic>[];

    final recovery =
        day['recovery'] is Map
            ? Map<String, dynamic>.from(
                day['recovery'],
              )
            : <String, dynamic>{};

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayName,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              if (restDay)
                const Chip(
                  label:
                      Text('Recovery'),
                  avatar: Icon(
                    Icons.hotel_rounded,
                    size: 16,
                  ),
                ),
            ],
          ),

          if (focus.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              focus,
              style:
                  const TextStyle(
                fontSize: 12,
                color:
                    Color(0xFF78716C),
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (exercises.isEmpty)
            const Text(
              'No exercises scheduled.',
              style: TextStyle(
                color:
                    Color(0xFF78716C),
              ),
            )
          else
            ...exercises.map(
              _buildExercise,
            ),

          if (recovery.isNotEmpty)
            _buildRecovery(
              recovery,
            ),
        ],
      ),
    );
  }

  Widget _buildExercise(
    dynamic exercise,
  ) {
    final name =
        exercise['name']
                ?.toString() ??
            '';

    final type =
        exercise['type']
                ?.toString() ??
            '';

    final duration =
        exercise['durationMinutes'];

    final intensity =
        exercise['intensity']
                ?.toString() ??
            '';

    final calories =
        exercise[
            'estimatedCaloriesBurned'];

    final sets =
        exercise['sets'];

    final repetitions =
        exercise['repetitions'];

    final restSeconds =
        exercise['restSeconds'];

    final instructions =
        exercise['instructions']
                ?.toString() ??
            '';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFAFAF9),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE7E5E4),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 5),

          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              if (type.isNotEmpty)
                Text(
                  type,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF78716C),
                  ),
                ),

              if (duration is num)
                Text(
                  '${duration.toInt()} min',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF78716C),
                  ),
                ),

              if (intensity.isNotEmpty)
                Text(
                  intensity,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF78716C),
                  ),
                ),

              if (calories is num)
                Text(
                  '~${calories.toInt()} kcal',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF2E7D32),
                  ),
                ),
            ],
          ),

          if (sets is num ||
              repetitions is num ||
              restSeconds is num) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                if (sets is num)
                  Text(
                    '${sets.toInt()} sets',
                  ),
                if (repetitions is num)
                  Text(
                    '${repetitions.toInt()} reps',
                  ),
                if (restSeconds is num)
                  Text(
                    '${restSeconds.toInt()}s rest',
                  ),
              ],
            ),
          ],

          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              instructions,
              style:
                  const TextStyle(
                fontSize: 12,
                height: 1.4,
                color:
                    Color(0xFF57534E),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecovery(
    Map<String, dynamic> recovery,
  ) {
    final minutes =
        recovery['recommendedMinutes'];

    final reason =
        recovery['reason']
                ?.toString() ??
            '';

    return Container(
      margin:
          const EdgeInsets.only(
        top: 6,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF5EBE1),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hotel_rounded,
            size: 19,
            color:
                Color(0xFF8D4F28),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              [
                if (minutes is num)
                  'Recommended recovery: ${minutes.toInt()} min.',
                if (reason.isNotEmpty)
                  reason,
              ].join(' '),
              style:
                  const TextStyle(
                fontSize: 12,
                height: 1.4,
                color:
                    Color(0xFF542E13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
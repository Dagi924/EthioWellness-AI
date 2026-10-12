import 'package:flutter/material.dart';

import '../models/meal_plan_model.dart';
import '../services/meal_plan_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  MealPlanModel? _planData;
  bool _isLoading = false;

  static const Color _background = Color(0xFFF7F2EA);
  static const Color _primary = Color(0xFF542E13);
  static const Color _accent = Color(0xFF8D4F28);
  static const Color _border = Color(0xFFEADBCE);
  static const Color _text = Color(0xFF1C1917);
  static const Color _muted = Color(0xFF78716C);

  String _tr(
    String key, {
    Map<String, String> params = const {},
  }) {
    return AppLocalization.instance.tr(
      key,
      params: params,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
  }

  // ============================================================
  // FETCH CURRENT MEAL PLAN
  // ============================================================

  Future<void> _fetchCurrentPlan() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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

  // ============================================================
  // GENERATE A NEW MEAL PLAN
  // ============================================================

  Future<void> _generateNewPlan() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final plan = await MealPlanService.generateMealPlan();

      if (!mounted) return;

      setState(() {
        _planData = plan;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('meal_plan_generated')),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'meal_plan_generation_failed',
              params: {'error': e.toString()},
            ),
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

  // ============================================================
  // LOCALIZE COMMON MEAL TYPES
  // ============================================================

  String _localizedMealType(String value) {
    final normalized = value.trim().toLowerCase();

    const keys = {
      'breakfast': 'meal_type_breakfast',
      'lunch': 'meal_type_lunch',
      'dinner': 'meal_type_dinner',
      'snack': 'meal_type_snack',
    };

    final key = keys[normalized];

    return key == null ? value.toUpperCase() : _tr(key);
  }

  // ============================================================
  // LOCALIZE WEEKDAY NAMES
  // ============================================================

  String _localizedDay(String value) {
    final normalized = value.trim().toLowerCase();

    const keys = {
      'monday': 'day_monday',
      'tuesday': 'day_tuesday',
      'wednesday': 'day_wednesday',
      'thursday': 'day_thursday',
      'friday': 'day_friday',
      'saturday': 'day_saturday',
      'sunday': 'day_sunday',
    };

    final key = keys[normalized];

    return key == null ? value : _tr(key);
  }

  // ============================================================
  // EXTRACT EXERCISE PLAN
  // ============================================================

  Map<String, dynamic> _extractExercisePlan() {
    if (_planData == null) {
      return {};
    }

    final dynamic raw = _planData!.rawPlanData;

    if (raw is! Map) {
      return {};
    }

    final exercisePlan = raw['exercisePlan'];

    if (exercisePlan is Map) {
      return Map<String, dynamic>.from(exercisePlan);
    }

    return {};
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: Text(
              _tr('meal_plan_title'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              const LanguageToggleButton(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: _tr('meal_plan_generate_new'),
                onPressed: _isLoading ? null : _generateNewPlan,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                  ),
                )
              : _planData == null
                  ? _buildEmptyState()
                  : _buildPlan(),
        );
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
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
                  color: _accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _tr('meal_plan_empty_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _tr('meal_plan_empty_description'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateNewPlan,
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(_tr('meal_plan_generate')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  // ============================================================
  // MEAL PLAN CONTENT
  // ============================================================

  Widget _buildPlan() {
    final exercisePlan = _extractExercisePlan();

    return RefreshIndicator(
      color: _primary,
      onRefresh: _fetchCurrentPlan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_planData!.summary.trim().isNotEmpty)
            _buildSummary(),
          const SizedBox(height: 18),
          _buildSectionTitle(
            _tr('meal_plan_section'),
            Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 10),
          ..._planData!.planDays.map(_buildMealDay),
          const SizedBox(height: 24),
          if (exercisePlan.isNotEmpty) ...[
            _buildSectionTitle(
              _tr('exercise_plan_section'),
              Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 10),
            _buildExercisePlan(exercisePlan),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBE1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.eco_rounded,
            color: _accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _planData!.summary,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EACH MEAL-PLAN DAY
  // ============================================================

  Widget _buildMealDay(dynamic day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
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
                    _localizedDay(day.day.toString()),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _text,
                    ),
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
                    ),
                    child: Text(
                      _tr('fasting'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            ...day.meals.map((meal) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F3EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _localizedMealType(meal.mealType.toString()),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${meal.foodName} • '
                        '${meal.calories.toInt()} ${_tr('unit_kcal')} • '
                        '${meal.proteinGrams}g ${_tr('protein')} • '
                        '${meal.ironMg}mg ${_tr('iron')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF44403C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXERCISE PLAN
  // ============================================================

  Widget _buildExercisePlan(Map<String, dynamic> plan) {
    final summary = plan['summary']?.toString() ?? '';

    final days = plan['days'] is List
        ? List<dynamic>.from(plan['days'])
        : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        const SizedBox(height: 12),
        ...days.map(_buildExerciseDay),
      ],
    );
  }

  // ============================================================
  // EXERCISE DAY
  // ============================================================

  Widget _buildExerciseDay(dynamic day) {
    final dayName = day['day']?.toString() ?? '';
    final focus = day['focus']?.toString() ?? '';
    final restDay = day['restDay'] == true;

    final exercises = day['exercises'] is List
        ? List<dynamic>.from(day['exercises'])
        : <dynamic>[];

    final recovery = day['recovery'] is Map
        ? Map<String, dynamic>.from(day['recovery'])
        : <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _localizedDay(dayName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (restDay)
                Chip(
                  label: Text(_tr('recovery')),
                  avatar: const Icon(
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
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (exercises.isEmpty)
            Text(
              _tr('no_exercises_scheduled'),
              style: const TextStyle(color: _muted),
            )
          else
            ...exercises.map(_buildExercise),
          if (recovery.isNotEmpty) _buildRecovery(recovery),
        ],
      ),
    );
  }

  // ============================================================
  // INDIVIDUAL EXERCISE
  // ============================================================

  Widget _buildExercise(dynamic exercise) {
    final name = exercise['name']?.toString() ?? '';
    final type = exercise['type']?.toString() ?? '';
    final duration = exercise['durationMinutes'];
    final intensity = exercise['intensity']?.toString() ?? '';
    final calories = exercise['estimatedCaloriesBurned'];
    final sets = exercise['sets'];
    final repetitions = exercise['repetitions'];
    final restSeconds = exercise['restSeconds'];
    final instructions = exercise['instructions']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              if (duration is num)
                Text(
                  '${duration.toInt()} ${_tr('unit_minutes')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              if (intensity.isNotEmpty)
                Text(
                  intensity,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              if (calories is num)
                Text(
                  '~${calories.toInt()} ${_tr('unit_kcal')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
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
                  Text('${sets.toInt()} ${_tr('sets')}'),
                if (repetitions is num)
                  Text('${repetitions.toInt()} ${_tr('repetitions')}'),
                if (restSeconds is num)
                  Text('${restSeconds.toInt()} ${_tr('seconds_rest')}'),
              ],
            ),
          ],
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              instructions,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF57534E),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // RECOVERY RECOMMENDATION
  // ============================================================

  Widget _buildRecovery(Map<String, dynamic> recovery) {
    final minutes = recovery['recommendedMinutes'];
    final reason = recovery['reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBE1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hotel_rounded,
            size: 19,
            color: _accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (minutes is num)
                  _tr(
                    'recommended_recovery',
                    params: {
                      'minutes': minutes.toInt().toString(),
                    },
                  ),
                if (reason.isNotEmpty) reason,
              ].join(' '),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
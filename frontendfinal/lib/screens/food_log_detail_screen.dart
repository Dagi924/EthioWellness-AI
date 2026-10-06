import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/food_log_service.dart';

class FoodLogDetailScreen extends StatefulWidget {
  final FoodItem food;

  const FoodLogDetailScreen({super.key, required this.food});

  @override
  State<FoodLogDetailScreen> createState() => _FoodLogDetailScreenState();
}

class _FoodLogDetailScreenState extends State<FoodLogDetailScreen> {
  double _portionGrams = 200.0;
  String _mealType = 'lunch';
  bool _isSubmitting = false;

  double get _multiplier => _portionGrams / 100.0;
  double get _scaledCalories => widget.food.caloriesPer100g * _multiplier;
  double get _scaledProtein => widget.food.proteinGrams * _multiplier;
  double get _scaledCarbs => widget.food.carbsGrams * _multiplier;
  double get _scaledFats => widget.food.fatsGrams * _multiplier;
  double get _scaledIron => widget.food.ironMg * _multiplier;

  Future<void> _submitFoodLog() async {
    setState(() => _isSubmitting = true);
    try {
      await FoodLogService.logMeal(
        foodId: widget.food.id,
        foodName: widget.food.name,
        mealType: _mealType,
        portionGrams: _portionGrams,
        calories: double.parse(_scaledCalories.toStringAsFixed(1)),
        proteinGrams: double.parse(_scaledProtein.toStringAsFixed(1)),
        carbsGrams: double.parse(_scaledCarbs.toStringAsFixed(1)),
        fatsGrams: double.parse(_scaledFats.toStringAsFixed(1)),
        ironMg: double.parse(_scaledIron.toStringAsFixed(1)),
        isVegan: widget.food.isVegan,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF542E13),
            content: Text('Logged ${_portionGrams.toInt()}g of ${widget.food.name}!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: Text(
          widget.food.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Nutrient Display Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEADBCE)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF542E13).withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    if (widget.food.nameAmharic != null)
                      Text(
                        widget.food.nameAmharic!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D4F28),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      widget.food.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    if (widget.food.isVegan) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EBE1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEADBCE)),
                        ),
                        child: const Text(
                          'Tsom Compliant (ጾም)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF542E13),
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 30, color: Color(0xFFEFE8DF)),
                    Text(
                      '${_scaledCalories.toInt()} kcal',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF542E13),
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'for ${_portionGrams.toInt()} grams',
                      style: const TextStyle(color: Color(0xFF78716C), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _nutrientPill('Protein', '${_scaledProtein.toStringAsFixed(1)}g', const Color(0xFF542E13)),
                        _nutrientPill('Carbs', '${_scaledCarbs.toStringAsFixed(1)}g', const Color(0xFF8D4F28)),
                        _nutrientPill('Fats', '${_scaledFats.toStringAsFixed(1)}g', const Color(0xFF78716C)),
                        _nutrientPill('Iron', '${_scaledIron.toStringAsFixed(1)}mg', const Color(0xFF965126)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Meal Type Selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEADBCE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meal Category',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: mealTypes.map((type) {
                      final isSel = _mealType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _mealType = type),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF542E13) : const Color(0xFFF8F3EC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? const Color(0xFF542E13) : const Color(0xFFEADBCE),
                              ),
                            ),
                            child: Text(
                              type[0].toUpperCase() + type.substring(1),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : const Color(0xFF542E13),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Portion Slider Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEADBCE)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Portion Size',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EBE1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_portionGrams.toInt()} g',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF542E13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Slider(
                    value: _portionGrams,
                    min: 50,
                    max: 600,
                    divisions: 22,
                    activeColor: const Color(0xFF542E13),
                    inactiveColor: const Color(0xFFEADBCE),
                    onChanged: (v) => setState(() => _portionGrams = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFoodLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'ADD TO DAILY FOOD LOG',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientPill(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADBCE)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF78716C), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
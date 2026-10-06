class MealItem {
  final String mealType;
  final String foodName;
  final double portionGrams;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;
  final double ironMg;

  MealItem({
    required this.mealType,
    required this.foodName,
    this.portionGrams = 200,
    this.calories = 350,
    this.proteinGrams = 12,
    this.carbsGrams = 55,
    this.fatsGrams = 6,
    this.ironMg = 5,
  });

  factory MealItem.fromJson(dynamic raw) {
    if (raw == null) {
      return MealItem(mealType: 'Meal', foodName: 'Ethiopian Dish');
    }
    if (raw is! Map) {
      return MealItem(mealType: 'Meal', foodName: raw.toString());
    }

    final json = Map<String, dynamic>.from(raw);
    return MealItem(
      mealType: json['mealType']?.toString() ?? json['type']?.toString() ?? 'Meal',
      foodName: json['foodName']?.toString() ?? json['name']?.toString() ?? 'Ethiopian Dish',
      portionGrams: (json['portionGrams'] as num?)?.toDouble() ?? 200.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 350.0,
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble() ?? 12.0,
      carbsGrams: (json['carbsGrams'] as num?)?.toDouble() ?? 55.0,
      fatsGrams: (json['fatsGrams'] as num?)?.toDouble() ?? 6.0,
      ironMg: (json['ironMg'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class MealDay {
  final String day;
  final bool isFasting;
  final List<MealItem> meals;

  MealDay({
    required this.day,
    this.isFasting = false,
    required this.meals,
  });

  factory MealDay.fromJson(dynamic raw) {
    if (raw == null || raw is! Map) {
      return MealDay(day: 'Day', meals: []);
    }

    final json = Map<String, dynamic>.from(raw);
    final String dayName = json['day']?.toString() ?? json['dayName']?.toString() ?? 'Day';
    final bool isFasting = json['isFasting'] == true ||
        json['is_fasting'] == true ||
        dayName.toLowerCase().contains('tsom');

    final List<MealItem> parsedMeals = [];

    // Case 1: Standard structured `meals` array
    final rawMeals = json['meals'] ?? json['mealItems'];
    if (rawMeals is List) {
      for (final m in rawMeals) {
        parsedMeals.add(MealItem.fromJson(m));
      }
    } else {
      // Case 2: Flat keys like { breakfast: "...", lunch: "...", dinner: "..." }
      if (json['breakfast'] != null) {
        parsedMeals.add(MealItem(
          mealType: 'Breakfast',
          foodName: json['breakfast'].toString(),
          calories: 320,
          proteinGrams: 8,
        ));
      }
      if (json['lunch'] != null) {
        parsedMeals.add(MealItem(
          mealType: 'Lunch',
          foodName: json['lunch'].toString(),
          calories: 480,
          proteinGrams: 18,
        ));
      }
      if (json['dinner'] != null) {
        parsedMeals.add(MealItem(
          mealType: 'Dinner',
          foodName: json['dinner'].toString(),
          calories: 380,
          proteinGrams: 14,
        ));
      }
      if (json['snack'] != null) {
        parsedMeals.add(MealItem(
          mealType: 'Snack',
          foodName: json['snack'].toString(),
          calories: 180,
          proteinGrams: 5,
        ));
      }
    }

    return MealDay(
      day: dayName,
      isFasting: isFasting,
      meals: parsedMeals,
    );
  }
}

class MealPlanModel {
  final String id;
  final String summary;
  final String weekIdentifier;
  final List<MealDay> planDays;

  MealPlanModel({
    this.id = '',
    this.summary = 'Ethiopian Heritage Meal Plan',
    this.weekIdentifier = 'Current Week',
    required this.planDays,
  });

  factory MealPlanModel.fromJson(dynamic raw) {
    if (raw == null) {
      return MealPlanModel(planDays: []);
    }

    // 1. If backend sends List [...] directly
    if (raw is List) {
      final List<MealDay> days = [];
      for (final item in raw) {
        days.add(MealDay.fromJson(item));
      }
      return MealPlanModel(
        id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
        summary: '7-Day Ethiopian Fasting Nutrition Plan',
        weekIdentifier: 'Current Week',
        planDays: days,
      );
    }

    // 2. If backend sends Map { ... }
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      final List<MealDay> days = [];

      dynamic rawDays = json['planDays'] ??
          json['days'] ??
          json['planData']?['planDays'] ??
          json['planData'] ??
          [];

      if (rawDays is List) {
        for (final item in rawDays) {
          days.add(MealDay.fromJson(item));
        }
      } else if (rawDays is Map) {
        final innerMap = Map<String, dynamic>.from(rawDays);
        if (innerMap['planDays'] is List) {
          for (final item in (innerMap['planDays'] as List)) {
            days.add(MealDay.fromJson(item));
          }
        }
      }

      return MealPlanModel(
        id: json['id']?.toString() ?? 'plan-${DateTime.now().millisecondsSinceEpoch}',
        summary: json['summary']?.toString() ??
            json['planData']?['summary']?.toString() ??
            'Ethiopian Heritage Meal Plan',
        weekIdentifier: json['weekIdentifier']?.toString() ?? 'Current Week',
        planDays: days,
      );
    }

    return MealPlanModel(planDays: []);
  }
}
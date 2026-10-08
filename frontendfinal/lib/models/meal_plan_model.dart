import 'dart:convert';

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
this.portionGrams = 0,
this.calories = 0,
this.proteinGrams = 0,
this.carbsGrams = 0,
this.fatsGrams = 0,
this.ironMg = 0,
});

factory MealItem.fromJson(dynamic raw) {
if (raw == null) {
return MealItem(
mealType: 'Meal',
foodName: '',
);
}

if (raw is! Map) {
  return MealItem(
    mealType: 'Meal',
    foodName: raw.toString(),
  );
}

final json = Map<String, dynamic>.from(raw);

return MealItem(
  mealType:
      json['mealType']?.toString() ??
      json['type']?.toString() ??
      'Meal',
  foodName:
      json['foodName']?.toString() ??
      json['name']?.toString() ??
      '',
  portionGrams:
      (json['portionGrams'] as num?)?.toDouble() ?? 0.0,
  calories:
      (json['calories'] as num?)?.toDouble() ?? 0.0,
  proteinGrams:
      (json['proteinGrams'] as num?)?.toDouble() ?? 0.0,
  carbsGrams:
      (json['carbsGrams'] as num?)?.toDouble() ?? 0.0,
  fatsGrams:
      (json['fatsGrams'] as num?)?.toDouble() ?? 0.0,
  ironMg:
      (json['ironMg'] as num?)?.toDouble() ?? 0.0,
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
return MealDay(
day: 'Day',
meals: [],
);
}

final json = Map<String, dynamic>.from(raw);

final String dayName =
    json['day']?.toString() ??
    json['dayName']?.toString() ??
    json['date']?.toString() ??
    'Day';

final bool isFasting =
    json['isFasting'] == true ||
    json['is_fasting'] == true ||
    dayName.toLowerCase().contains('tsom');

final List<MealItem> parsedMeals = [];

final rawMeals =
    json['meals'] ??
    json['mealItems'];

if (rawMeals is List) {
  for (final meal in rawMeals) {
    parsedMeals.add(
      MealItem.fromJson(meal),
    );
  }
} else {
  if (json['breakfast'] != null) {
    parsedMeals.add(
      MealItem(
        mealType: 'Breakfast',
        foodName: json['breakfast'].toString(),
      ),
    );
  }

  if (json['lunch'] != null) {
    parsedMeals.add(
      MealItem(
        mealType: 'Lunch',
        foodName: json['lunch'].toString(),
      ),
    );
  }

  if (json['dinner'] != null) {
    parsedMeals.add(
      MealItem(
        mealType: 'Dinner',
        foodName: json['dinner'].toString(),
      ),
    );
  }

  if (json['snack'] != null) {
    parsedMeals.add(
      MealItem(
        mealType: 'Snack',
        foodName: json['snack'].toString(),
      ),
    );
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

/// Complete raw response received from the backend.
///
/// This can contain:
/// - mealPlan
/// - exercisePlan
/// - summary
/// - planDays
/// - raw AI text
/// - any other AI-generated fields
final Map<String, dynamic> rawPlanData;

/// Raw AI response when the model returned plain text
/// instead of structured JSON.
final String rawAiText;

MealPlanModel({
this.id = '',
this.summary = '',
this.weekIdentifier = '',
required this.planDays,
this.rawPlanData = const {},
this.rawAiText = '',
});

factory MealPlanModel.fromJson(dynamic raw) {
if (raw == null) {
return MealPlanModel(
planDays: [],
);
}

/*
 * ------------------------------------------------------------
 * CASE 1
 * Backend / AI returned a JSON string.
 *
 * Example:
 * "{\"planDays\":[...]}"
 *
 * Try to decode it first.
 * ------------------------------------------------------------
 */
if (raw is String) {
  final text = raw.trim();

  if (text.isEmpty) {
    return MealPlanModel(
      planDays: [],
      rawAiText: '',
    );
  }

  try {
    final decoded = jsonDecode(text);

    final parsed = MealPlanModel.fromJson(decoded);

    return MealPlanModel(
      id: parsed.id,
      summary: parsed.summary,
      weekIdentifier: parsed.weekIdentifier,
      planDays: parsed.planDays,
      rawPlanData: parsed.rawPlanData,
      rawAiText: text,
    );
  } catch (_) {
    /*
     * This is important for SOFT mode.
     *
     * The AI does NOT have to return valid JSON anymore.
     * We preserve the exact AI text instead of rejecting it.
     */
    return MealPlanModel(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      summary: '',
      weekIdentifier: '',
      planDays: [],
      rawPlanData: {
        'rawAiText': text,
      },
      rawAiText: text,
    );
  }
}

/*
 * ------------------------------------------------------------
 * CASE 2
 * Backend returned the meal days directly.
 *
 * [
 *   {...},
 *   {...}
 * ]
 * ------------------------------------------------------------
 */
if (raw is List) {
  final List<MealDay> days = [];

  for (final item in raw) {
    days.add(
      MealDay.fromJson(item),
    );
  }

  return MealPlanModel(
    id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
    summary: '',
    weekIdentifier: '',
    planDays: days,
    rawPlanData: {
      'planDays': raw,
    },
  );
}

/*
 * ------------------------------------------------------------
 * CASE 3
 * Backend returned an object.
 * ------------------------------------------------------------
 */
if (raw is Map) {
  final json = Map<String, dynamic>.from(raw);

  /*
   * New soft backend format:
   *
   * {
   *   "mealPlan": ...,
   *   "exercisePlan": ...
   * }
   *
   * If mealPlan exists, parse THAT instead of trying to
   * interpret the entire combined response as MealPlanModel.
   */
  dynamic mealPlanData = json['mealPlan'];

  /*
   * Also support:
   *
   * {
   *   "planData": {
   *      "mealPlan": ...
   *   }
   * }
   */
  if (mealPlanData == null &&
      json['planData'] is Map) {
    final planData =
        Map<String, dynamic>.from(
      json['planData'],
    );

    if (planData.containsKey('mealPlan')) {
      mealPlanData = planData['mealPlan'];
    }
  }

  /*
   * If a dedicated mealPlan exists, parse it recursively.
   */
  if (mealPlanData != null) {
    final parsedMealPlan =
        MealPlanModel.fromJson(mealPlanData);

    return MealPlanModel(
      id:
          json['id']?.toString() ??
          parsedMealPlan.id,
      summary:
          json['summary']?.toString() ??
          parsedMealPlan.summary,
      weekIdentifier:
          json['weekIdentifier']?.toString() ??
          parsedMealPlan.weekIdentifier,
      planDays: parsedMealPlan.planDays,
      rawPlanData: json,
      rawAiText: parsedMealPlan.rawAiText,
    );
  }

  /*
   * ----------------------------------------------------------
   * Normal structured format
   * ----------------------------------------------------------
   */
  final List<MealDay> days = [];

  dynamic rawDays =
      json['planDays'] ??
      json['days'];

  /*
   * Support:
   *
   * {
   *   "planData": {
   *      "planDays": [...]
   *   }
   * }
   */
  if (rawDays == null &&
      json['planData'] is Map) {
    final planData =
        Map<String, dynamic>.from(
      json['planData'],
    );

    rawDays =
        planData['planDays'] ??
        planData['days'];
  }

  if (rawDays is List) {
    for (final item in rawDays) {
      days.add(
        MealDay.fromJson(item),
      );
    }
  }

  /*
   * Some AI responses may return:
   *
   * {
   *   "breakfast": "...",
   *   "lunch": "...",
   *   "dinner": "..."
   * }
   *
   * Treat that as one day rather than throwing it away.
   */
  if (days.isEmpty) {
    final hasFlatMealData =
        json['breakfast'] != null ||
        json['lunch'] != null ||
        json['dinner'] != null ||
        json['snack'] != null;

    if (hasFlatMealData) {
      days.add(
        MealDay.fromJson({
          'day':
              json['day']?.toString() ??
              'Today',
          'isFasting':
              json['isFasting'] == true,
          'breakfast': json['breakfast'],
          'lunch': json['lunch'],
          'dinner': json['dinner'],
          'snack': json['snack'],
        }),
      );
    }
  }

  return MealPlanModel(
    id:
        json['id']?.toString() ??
        'plan-${DateTime.now().millisecondsSinceEpoch}',
    summary:
        json['summary']?.toString() ??
        '',
    weekIdentifier:
        json['weekIdentifier']?.toString() ??
        '',
    planDays: days,
    rawPlanData: json,
  );
}

/*
 * ------------------------------------------------------------
 * CASE 4
 * Completely unknown value.
 *
 * Never crash the Flutter app.
 * ------------------------------------------------------------
 */
return MealPlanModel(
  id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
  planDays: [],
  rawPlanData: {
    'rawValue': raw.toString(),
  },
  rawAiText: raw.toString(),
);

}

/*

* Convenient helper for the UI.
*
* True when the backend returned AI text but it could not
* be converted into structured meal days.
  */
  bool get hasRawAiText =>
  rawAiText.trim().isNotEmpty;

/*

* True when there is an actual meal plan that the UI can
* render as individual days.
  */
  bool get hasMealDays =>
  planDays.isNotEmpty;
  }

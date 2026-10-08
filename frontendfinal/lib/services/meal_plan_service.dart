import 'dart:convert';

import 'api_client.dart';
import 'auth_service.dart';
import '../models/meal_plan_model.dart';

class PremiumRequiredException implements Exception {
final String message;

PremiumRequiredException([
this.message =
'Upgrade to EthioNutri Premium to unlock AI Meal Plans & Smart Grocery Generation.',
]);

@override
String toString() => message;
}

class MealPlanService {
/// ============================================================
/// INTERNAL HELPERS
/// ============================================================

/// Safely converts a dynamic value into a Map.
static Map<String, dynamic>? _asMap(dynamic value) {
if (value is Map<String, dynamic>) {
return value;
}


if (value is Map) {
  return Map<String, dynamic>.from(value);
}

return null;

}

/// ============================================================
/// DECODE AI JSON STRING
/// ============================================================
///
/// The AI may return:
///
/// 1. A real Map
/// 2. A List
/// 3. A JSON string
/// 4. Plain text
///
/// If it is valid JSON, decode it.
/// If it is plain text, preserve the text.
///
static dynamic _decodePossibleJson(dynamic value) {
if (value is! String) {
return value;
}


final text = value.trim();

if (text.isEmpty) {
  return '';
}

try {
  return jsonDecode(text);
} catch (_) {
  // Soft mode:
  // Plain AI text is still valid output.
  return text;
}


}

/// ============================================================
/// EXTRACT PLAN DATA
/// ============================================================
///
/// Supports all of these backend responses:
///
/// {
///   "plan": {
///     "planData": {
///       "mealPlan": ...
///     }
///   }
/// }
///
/// {
///   "plan": {
///     "mealPlan": ...
///   }
/// }
///
/// {
///   "planData": {
///     "mealPlan": ...
///   }
/// }
///
/// {
///   "mealPlan": ...
/// }
///
static dynamic _extractPlanData(
Map<String, dynamic> response,
) {
dynamic current = response;

/*
 * ------------------------------------------------------------
 * RESPONSE -> PLAN
 * ------------------------------------------------------------
 */

if (current is Map &&
    current.containsKey('plan')) {
  current = current['plan'];
}

/*
 * ------------------------------------------------------------
 * PLAN -> PLANDATA
 * ------------------------------------------------------------
 */

final currentMap = _asMap(current);

if (currentMap != null &&
    currentMap.containsKey('planData')) {
  current = currentMap['planData'];
}

/*
 * ------------------------------------------------------------
 * PLANDATA -> MEALPLAN
 * ------------------------------------------------------------
 *
 * This is the important new part.
 *
 * Backend now stores:
 *
 * {
 *   mealPlan: ...,
 *   exercisePlan: ...
 * }
 *
 * We only want mealPlan here.
 */

final planDataMap = _asMap(current);

if (planDataMap != null &&
    planDataMap.containsKey('mealPlan')) {
  current = planDataMap['mealPlan'];
}

/*
 * ------------------------------------------------------------
 * OTHER RESPONSE WRAPPERS
 * ------------------------------------------------------------
 */

if (current == null &&
    response.containsKey('mealPlan')) {
  current = response['mealPlan'];
}

if (current == null &&
    response.containsKey('result')) {
  current = response['result'];
}

if (current == null &&
    response.containsKey('data')) {
  current = response['data'];
}

return _decodePossibleJson(current);

}

/// ============================================================
/// PARSE MEAL PLAN
/// ============================================================
///
/// This is deliberately SOFT.
///
/// It does NOT reject the AI just because it returned a
/// different structure.
///
/// Structured data -> planDays
/// JSON string      -> decoded and parsed
/// Plain text       -> rawAiText
///
static MealPlanModel? _parseMealPlan(
dynamic rawPlan, {
String summary =
'Personalized Ethiopian Weekly Plan',
}) {
if (rawPlan == null) {
return null;
}

/*
 * ------------------------------------------------------------
 * DECODE STRING
 * ------------------------------------------------------------
 */

if (rawPlan is String) {
  final text = rawPlan.trim();

  if (text.isEmpty) {
    return MealPlanModel(
      summary: summary,
      planDays: [],
      rawPlanData: {
        'rawAiText': '',
      },
      rawAiText: '',
    );
  }

  /*
   * Try JSON first.
   */

  final decoded =
      _decodePossibleJson(text);

  /*
   * If JSON decoding produced another object,
   * recursively parse it.
   */

  if (decoded is Map ||
      decoded is List) {
    final parsed =
        _parseMealPlan(
      decoded,
      summary: summary,
    );

    if (parsed != null) {
      /*
       * Preserve the original AI string too.
       */
      return MealPlanModel(
        id: parsed.id,
        summary:
            parsed.summary.isNotEmpty
                ? parsed.summary
                : summary,
        weekIdentifier:
            parsed.weekIdentifier,
        planDays: parsed.planDays,
        rawPlanData: {
          ...parsed.rawPlanData,
          'rawAiResponse': text,
        },
        rawAiText: text,
      );
    }
  }

  /*
   * ----------------------------------------------------------
   * PLAIN AI TEXT
   * ----------------------------------------------------------
   *
   * This is exactly what your log currently says:
   *
   * Exercise AI result accepted in SOFT mode: string
   *
   * The same can happen with mealPlan.
   *
   * Do NOT throw.
   * Preserve the text.
   */

  return MealPlanModel(
    id:
        'ai-${DateTime.now().millisecondsSinceEpoch}',
    summary: summary,
    weekIdentifier: '',
    planDays: [],
    rawPlanData: {
      'rawAiText': text,
    },
    rawAiText: text,
  );
}

/*
 * ------------------------------------------------------------
 * LIST
 * ------------------------------------------------------------
 */

if (rawPlan is List) {
  final List<MealDay> days = [];

  for (final item in rawPlan) {
    try {
      days.add(
        MealDay.fromJson(item),
      );
    } catch (e) {
      print(
        'MealDay parsing skipped one item: $e',
      );
    }
  }

  return MealPlanModel(
    id:
        'plan-${DateTime.now().millisecondsSinceEpoch}',
    summary: summary,
    weekIdentifier: '',
    planDays: days,
    rawPlanData: {
      'planDays': rawPlan,
    },
  );
}

/*
 * ------------------------------------------------------------
 * MAP
 * ------------------------------------------------------------
 */

final json = _asMap(rawPlan);

if (json == null) {
  /*
   * Completely unknown type.
   *
   * Do not crash.
   */

  return MealPlanModel(
    id:
        'ai-${DateTime.now().millisecondsSinceEpoch}',
    summary: summary,
    planDays: [],
    rawPlanData: {
      'rawValue': rawPlan.toString(),
    },
    rawAiText: rawPlan.toString(),
  );
}

/*
 * ------------------------------------------------------------
 * NEW BACKEND FORMAT
 * ------------------------------------------------------------
 *
 * {
 *   "mealPlan": ...
 * }
 */

if (json.containsKey('mealPlan')) {
  final nested =
      _decodePossibleJson(
    json['mealPlan'],
  );

  final parsed =
      _parseMealPlan(
    nested,
    summary:
        json['summary']?.toString() ??
        summary,
  );

  if (parsed != null) {
    return MealPlanModel(
      id:
          json['id']?.toString() ??
          parsed.id,
      summary:
          json['summary']?.toString() ??
          parsed.summary,
      weekIdentifier:
          json['weekIdentifier']
              ?.toString() ??
          parsed.weekIdentifier,
      planDays: parsed.planDays,
      rawPlanData: json,
      rawAiText: parsed.rawAiText,
    );
  }
}

/*
 * ------------------------------------------------------------
 * DIRECT PLAN DAYS
 * ------------------------------------------------------------
 */

if (json['planDays'] is List) {
  return MealPlanModel.fromJson(
    {
      ...json,
      'summary':
          json['summary'] ??
          summary,
    },
  );
}

/*
 * ------------------------------------------------------------
 * DAYS FORMAT
 * ------------------------------------------------------------
 *
 * {
 *   "days": [...]
 * }
 */

if (json['days'] is List) {
  return MealPlanModel.fromJson(
    {
      ...json,
      'summary':
          json['summary'] ??
          summary,
      'planDays': json['days'],
    },
  );
}

/*
 * ------------------------------------------------------------
 * NESTED PLAN DATA
 * ------------------------------------------------------------
 */

if (json['planData'] != null) {
  final nested =
      _decodePossibleJson(
    json['planData'],
  );

  final parsed =
      _parseMealPlan(
    nested,
    summary:
        json['summary']?.toString() ??
        summary,
  );

  if (parsed != null) {
    return MealPlanModel(
      id:
          json['id']?.toString() ??
          parsed.id,
      summary:
          json['summary']?.toString() ??
          parsed.summary,
      weekIdentifier:
          json['weekIdentifier']
              ?.toString() ??
          parsed.weekIdentifier,
      planDays: parsed.planDays,
      rawPlanData: json,
      rawAiText: parsed.rawAiText,
    );
  }
}

/*
 * ------------------------------------------------------------
 * FLAT MEAL FORMAT
 * ------------------------------------------------------------
 *
 * {
 *   "breakfast": "...",
 *   "lunch": "...",
 *   "dinner": "..."
 * }
 */

final hasFlatMealData =
    json['breakfast'] != null ||
    json['lunch'] != null ||
    json['dinner'] != null ||
    json['snack'] != null;

if (hasFlatMealData) {
  return MealPlanModel.fromJson({
    'id':
        json['id'] ??
        'plan-${DateTime.now().millisecondsSinceEpoch}',
    'summary':
        json['summary'] ??
        summary,
    'weekIdentifier':
        json['weekIdentifier'] ??
        '',
    'planDays': [
      {
        'day':
            json['day'] ??
            'Today',
        'isFasting':
            json['isFasting'] ??
            false,
        'breakfast':
            json['breakfast'],
        'lunch':
            json['lunch'],
        'dinner':
            json['dinner'],
        'snack':
            json['snack'],
      },
    ],
  });
}

/*
 * ------------------------------------------------------------
 * LAST SOFT FALLBACK
 * ------------------------------------------------------------
 *
 * The response is still valid backend data even if it does
 * not contain planDays.
 *
 * Preserve it instead of returning null.
 */

return MealPlanModel(
  id:
      json['id']?.toString() ??
      'ai-${DateTime.now().millisecondsSinceEpoch}',
  summary:
      json['summary']?.toString() ??
      summary,
  weekIdentifier:
      json['weekIdentifier']?.toString() ??
      '',
  planDays: [],
  rawPlanData: json,
  rawAiText:
      json['text']?.toString() ??
      json['content']?.toString() ??
      '',
);


}

/// ============================================================
/// GET CURRENT PLAN
/// ============================================================

static Future<MealPlanModel?> getCurrentPlan({
String week = 'current',
}) async {
try {
final res =
await ApiClient.get(
'/meal-plans/weekly?week=$week',
);

  final rawPlan =
      _extractPlanData(res);

  return _parseMealPlan(
    rawPlan,
    summary:
        'Weekly Ethiopian Fasting & Nutrition Plan',
  );
} catch (e) {
  print(
    'Error loading current meal plan: $e',
  );

  return null;
}


}

/// ============================================================
/// GENERATE MEAL PLAN
/// ============================================================

static Future<MealPlanModel> generateMealPlan() async {
final isPremium =
await AuthService.isPremiumUser();


if (!isPremium) {
  throw PremiumRequiredException(
    'Upgrade to Premium to generate personalized 7-Day Ethiopian Fasting Meal Plans.',
  );
}

final res =
    await ApiClient.post(
  '/meal-plans/generate',
  {},
);

final rawPlan =
    _extractPlanData(res);

final parsed =
    _parseMealPlan(
  rawPlan,
  summary:
      'Personalized 7-Day Fasting Plan',
);

/*
 * ------------------------------------------------------------
 * SOFT MODE
 * ------------------------------------------------------------
 *
 * Even if the AI returned plain text, _parseMealPlan()
 * creates a MealPlanModel with rawAiText.
 *
 * Therefore we only throw if absolutely nothing came back.
 */

if (parsed == null) {
  throw Exception(
    'The meal-plan endpoint returned no usable data.',
  );
}

print(
  '[MealPlanService] Meal plan received successfully.',
);

print(
  '[MealPlanService] Structured days: '
  '${parsed.planDays.length}',
);

if (parsed.rawAiText.isNotEmpty) {
  print(
    '[MealPlanService] Raw AI text preserved.',
  );
}

return parsed;


}

/// ============================================================
/// GET GROCERY LIST
/// ============================================================

static Future<Map<String, dynamic>>
getGroceryList() async {
final res =
await ApiClient.get(
'/grocery/list',
);


final items =
    res['items'];

return {
  'totalItems':
      res['totalItems'] ?? 0,

  'estimatedTotalEtb':
      (res['estimatedTotalEtb']
              as num?)
          ?.toDouble() ??
      0.0,

  'items':
      items is List
          ? items
          : [],
};

}

/// ============================================================
/// GENERATE GROCERY LIST
/// ============================================================

static Future<Map<String, dynamic>>
generateGroceryList() async {
final isPremium =
await AuthService.isPremiumUser();

if (!isPremium) {
  throw PremiumRequiredException(
    'Upgrade to Premium to generate automated market grocery lists with ETB pricing.',
  );
}

final res =
    await ApiClient.post(
  '/grocery/generate',
  {},
);

final items =
    res['items'];

return {
  'message':
      res['message'] ??
      'Grocery list generated',

  'totalItems':
      res['totalItems'] ?? 0,

  'estimatedTotalEtb':
      (res['estimatedTotalEtb']
              as num?)
          ?.toDouble() ??
      0.0,

  'items':
      items is List
          ? items
          : [],
};

}

/// ============================================================
/// UPDATE GROCERY ITEM
/// ============================================================

static Future<Map<String, dynamic>>
updateGroceryItem({
required String id,
bool? isChecked,
String? quantity,
}) async {
final Map<String, dynamic> body =
{};

if (isChecked != null) {
  body['isChecked'] =
      isChecked;
}

if (quantity != null) {
  body['quantity'] =
      quantity;
}

return await ApiClient.patch(
  '/grocery/items/$id',
  body,
);


}

/// ============================================================
/// DELETE GROCERY ITEM
/// ============================================================

static Future<void>
deleteGroceryItem(
String id,
) async {
await ApiClient.delete(
'/grocery/items/$id',
);
}
}

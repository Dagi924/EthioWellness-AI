
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
  // ============================================================
  // INTERNAL HELPERS
  // ============================================================

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  // ============================================================
  // DECODE POSSIBLE JSON
  // ============================================================

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
      // Plain AI text is valid.
      return text;
    }
  }

  // ============================================================
  // EXTRACT PLAN DATA
  // ============================================================

  static dynamic _extractPlanData(
    Map<String, dynamic> response,
  ) {
    dynamic current = response;

    if (current is Map && current.containsKey('plan')) {
      current = current['plan'];
    }

    final currentMap = _asMap(current);

    if (currentMap != null &&
        currentMap.containsKey('planData')) {
      current = currentMap['planData'];
    }

    final planDataMap = _asMap(current);

    if (planDataMap != null &&
        planDataMap.containsKey('mealPlan')) {
      current = planDataMap['mealPlan'];
    }

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

  // ============================================================
  // EXTRACT RAW MEAL PLAN FOR GROCERY GENERATION
  // ============================================================

  static dynamic _extractRawMealPlanForGrocery(
    dynamic rawPlan,
  ) {
    rawPlan = _decodePossibleJson(rawPlan);

    // ------------------------------------------------------------
    // STRING
    // ------------------------------------------------------------

    if (rawPlan is String) {
      final text = rawPlan.trim();

      if (text.isEmpty) {
        return '';
      }

      final decoded = _decodePossibleJson(text);

      if (decoded is Map ||
          decoded is List) {
        return _extractRawMealPlanForGrocery(decoded);
      }

      return text;
    }

    // ------------------------------------------------------------
    // MAP
    // ------------------------------------------------------------

    final map = _asMap(rawPlan);

    if (map != null) {
      if (map.containsKey('mealPlan')) {
        return _extractRawMealPlanForGrocery(
          map['mealPlan'],
        );
      }

      if (map.containsKey('planData')) {
        return _extractRawMealPlanForGrocery(
          map['planData'],
        );
      }

      if (map.containsKey('rawAiText')) {
        return map['rawAiText'];
      }

      if (map.containsKey('rawAiResponse')) {
        return map['rawAiResponse'];
      }

      return map;
    }

    // ------------------------------------------------------------
    // LIST
    // ------------------------------------------------------------

    if (rawPlan is List) {
      return rawPlan;
    }

    // ------------------------------------------------------------
    // UNKNOWN
    // ------------------------------------------------------------

    if (rawPlan == null) {
      return null;
    }

    return rawPlan.toString();
  }

  // ============================================================
  // PARSE MEAL PLAN
  // ============================================================

  static MealPlanModel? _parseMealPlan(
    dynamic rawPlan, {
    String summary =
        'Personalized Ethiopian Weekly Plan',
  }) {
    if (rawPlan == null) {
      return null;
    }

    // ------------------------------------------------------------
    // STRING
    // ------------------------------------------------------------

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

      final decoded =
          _decodePossibleJson(text);

      if (decoded is Map ||
          decoded is List) {
        final parsed =
            _parseMealPlan(
          decoded,
          summary: summary,
        );

        if (parsed != null) {
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

      // Plain AI text fallback.
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

    // ------------------------------------------------------------
    // LIST
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // MAP
    // ------------------------------------------------------------

    final json = _asMap(rawPlan);

    if (json == null) {
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

    // ------------------------------------------------------------
    // NEW BACKEND FORMAT
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // DIRECT PLAN DAYS
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // DAYS FORMAT
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // NESTED PLAN DATA
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // FLAT MEAL FORMAT
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // LAST SOFT FALLBACK
    // ------------------------------------------------------------

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

  // ============================================================
  // GET CURRENT PLAN
  // ============================================================

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

  // ============================================================
  // GENERATE MEAL PLAN
  // ============================================================

  static Future<MealPlanModel>
      generateMealPlan() async {
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

  // ============================================================
  // GET GROCERY LIST
  // ============================================================
  //
  // NEW BACKEND RESPONSE:
  //
  // {
  //   "message": "...",
  //   "weekIdentifier": "2026-W41",
  //   "groceryText": "..."
  // }
  //
  // No JSON grocery items are expected anymore.
  // ============================================================

  static Future<Map<String, dynamic>>
      getGroceryList() async {
    final res =
        await ApiClient.get(
      '/grocery/list',
    );

    final groceryText =
        res['groceryText']
                ?.toString()
                .trim() ??
            '';

    return {
      'message':
          res['message'] ??
          'Grocery list loaded',

      'weekIdentifier':
          res['weekIdentifier']
              ?.toString() ??
          '',

      'groceryText':
          groceryText,
    };
  }

  // ============================================================
  // GENERATE GROCERY LIST
  // ============================================================
  //
  // Grocery is now PLAIN TEXT.
  //
  // The AI is NOT asked to return JSON.
  // The backend simply returns:
  //
  // {
  //   "groceryText": "..."
  // }
  // ============================================================

  static Future<Map<String, dynamic>>
      generateGroceryList() async {
    final isPremium =
        await AuthService.isPremiumUser();

    if (!isPremium) {
      throw PremiumRequiredException(
        'Upgrade to Premium to generate automated market grocery lists.',
      );
    }

    // ------------------------------------------------------------
    // LOAD CURRENT WEEK'S MEAL PLAN
    // ------------------------------------------------------------

    print(
      '[MealPlanService] Loading current week meal plan for grocery generation...',
    );

    final currentPlan =
        await getCurrentPlan(
      week: 'current',
    );

    if (currentPlan == null) {
      throw Exception(
        'No current weekly meal plan was found. Generate a meal plan first.',
      );
    }

    // ------------------------------------------------------------
    // EXTRACT RAW MEAL DATA
    // ------------------------------------------------------------

    dynamic rawMealPlan =
        currentPlan.rawPlanData;

    if (rawMealPlan == null ||
        (rawMealPlan is Map &&
            rawMealPlan.isEmpty)) {
      if (currentPlan.rawAiText.isNotEmpty) {
        rawMealPlan =
            currentPlan.rawAiText;
      }
    }

    rawMealPlan =
        _extractRawMealPlanForGrocery(
      rawMealPlan,
    );

    if (rawMealPlan == null ||
        (rawMealPlan is String &&
            rawMealPlan.trim().isEmpty)) {
      if (currentPlan.rawAiText.isNotEmpty) {
        rawMealPlan =
            currentPlan.rawAiText;
      }
    }

    if (rawMealPlan == null) {
      throw Exception(
        'The current meal plan contains no usable meal data.',
      );
    }

    // ------------------------------------------------------------
    // PLAIN-TEXT GROCERY INSTRUCTIONS
    // ------------------------------------------------------------

    const groceryInstructions = '''
Generate a complete weekly grocery list from the provided current week's meal plan.

IMPORTANT:
- Use ONLY the meal plan provided.
- Ignore exercise plans and workout information.
- Combine duplicate ingredients across the entire week.
- Calculate practical total quantities for the whole week.
- Use Ethiopian market-friendly units such as kg, g, liters, ml, pieces, bunches, or dozens.
- Consider the meals and servings actually present in the meal plan.
- Do not invent meals.
- Include staple and cooking ingredients only when they are actually needed.
- Include spices and seasonings when reasonably required.

PRICE INFORMATION:
- Give realistic estimated Ethiopian market prices in Ethiopian Birr (ETB).
- Prices are estimates and are not guaranteed exact market prices.
- Give an approximate low-high price range where useful.
- Consider normal differences between markets, locations, season, and product quality.
- Do not claim to have checked a live market.

FORMAT:
Return a clean, readable grocery list as normal text.

Organize it with useful sections such as:

WEEKLY GROCERY LIST

Grains & Staples
- Ingredient — quantity — estimated price

Legumes & Protein
- Ingredient — quantity — estimated price

Vegetables
- Ingredient — quantity — estimated price

Fruits
- Ingredient — quantity — estimated price

Spices & Cooking Ingredients
- Ingredient — quantity — estimated price

Other Ingredients
- Ingredient — quantity — estimated price

ESTIMATED WEEKLY COST
- Approximate total: ETB ...

Keep the response practical and easy to read in a mobile application.

Do NOT return JSON.
Do NOT use a JSON code block.
Do NOT wrap the response in markdown JSON.
Return the grocery list directly as readable text.
''';

    // ------------------------------------------------------------
    // SEND TO BACKEND
    // ------------------------------------------------------------

    final requestBody = {
      'mealPlan': rawMealPlan,
      'instructions': groceryInstructions,
    };

    print(
      "[MealPlanService] Sending current week's meal plan to grocery AI...",
    );

    final res =
        await ApiClient.post(
      '/grocery/generate',
      requestBody,
    );

    // ------------------------------------------------------------
    // READ PLAIN TEXT RESPONSE
    // ------------------------------------------------------------

    final groceryText =
        res['groceryText']
                ?.toString()
                .trim() ??
            '';

    if (groceryText.isEmpty) {
      throw Exception(
        'The grocery endpoint returned an empty grocery list.',
      );
    }

    print(
      '[MealPlanService] Grocery text received successfully.',
    );

    print(
      '[MealPlanService] Grocery text length: '
      '${groceryText.length} characters.',
    );

    // ------------------------------------------------------------
    // RETURN TEXT DIRECTLY TO FLUTTER SCREEN
    // ------------------------------------------------------------

    return {
      'message':
          res['message'] ??
          'Grocery list generated successfully.',

      'weekIdentifier':
          res['weekIdentifier']
              ?.toString() ??
          '',

      'groceryText':
          groceryText,
    };
  }

  // ============================================================
  // UPDATE GROCERY ITEM
  // ============================================================
  //
  // Kept temporarily for backwards compatibility.
  // Plain-text grocery lists do not use these.
  // ============================================================

  static Future<Map<String, dynamic>>
      updateGroceryItem({
    required String id,
    bool? isChecked,
    String? quantity,
  }) async {
    final Map<String, dynamic> body = {};

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

  // ============================================================
  // DELETE GROCERY ITEM
  // ============================================================
  //
  // Kept temporarily for backwards compatibility.
  // Plain-text grocery lists do not use these.
  // ============================================================

  static Future<void>
      deleteGroceryItem(
    String id,
  ) async {
    await ApiClient.delete(
      '/grocery/items/$id',
    );
  }
}

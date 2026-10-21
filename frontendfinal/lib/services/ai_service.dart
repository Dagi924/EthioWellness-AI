import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'app_localization.dart';

// ============================================================================
// AI CHAT RESPONSE
// ============================================================================

class AiChatResponse {
  final String reply;
  final String fastingPractice;
  final String? goal;
  final int foodLogCount;
  final int sleepLogCount;
  final int moodLogCount;
  final int previousChats;
  final String? date;
  final bool aiAvailable;

  AiChatResponse({
    required this.reply,
    required this.fastingPractice,
    this.goal,
    required this.foodLogCount,
    required this.sleepLogCount,
    required this.moodLogCount,
    required this.previousChats,
    this.date,
    required this.aiAvailable,
  });
}

// ============================================================================
// RECIPE RECOMMENDATION MODEL
// Retained for compatibility with existing screens.
// ============================================================================

class RecipeRecommendation {
  final String title;
  final String description;
  final List<String> ingredients;
  final int prepTimeMinutes;
  final String difficulty;
  final bool isVegan;
  final Map<String, dynamic> estimatedNutrition;
  final List<String> instructions;

  RecipeRecommendation({
    required this.title,
    required this.description,
    required this.ingredients,
    required this.prepTimeMinutes,
    required this.difficulty,
    required this.isVegan,
    required this.estimatedNutrition,
    required this.instructions,
  });

  factory RecipeRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    return RecipeRecommendation(
      title: json['title']?.toString() ?? 'Ethiopian Recipe',
      description: json['description']?.toString() ?? '',
      ingredients: json['ingredients'] is List
          ? (json['ingredients'] as List)
              .map((e) => e.toString())
              .toList()
          : [],
      prepTimeMinutes: json['prepTimeMinutes'] is num
          ? (json['prepTimeMinutes'] as num).toInt()
          : 20,
      difficulty: json['difficulty']?.toString() ?? 'Easy',
      isVegan: json['isVegan'] == true,
      estimatedNutrition: json['estimatedNutrition'] is Map
          ? Map<String, dynamic>.from(
              json['estimatedNutrition'],
            )
          : {},
      instructions: json['instructions'] is List
          ? (json['instructions'] as List)
              .map((e) => e.toString())
              .toList()
          : [],
    );
  }
}

// ============================================================================
// AI SERVICE
// ============================================================================

class AiService {
  // ==========================================================================
  // GET RESPONSE LANGUAGE
  // ==========================================================================

  static String _getResponseLanguage(
    String? languageCode,
  ) {
    final selectedLanguage = languageCode ??
        AppLocalization.instance.locale.languageCode;

    return selectedLanguage == 'am' ? 'am' : 'en';
  }

  // ==========================================================================
  // SEND CHAT MESSAGE
  // POST /api/v1/ai/chat
  // ==========================================================================

  static Future<AiChatResponse> sendMessage(
    String message, {
    String? languageCode,
  }) async {
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final responseLanguage =
        _getResponseLanguage(languageCode);

    final res = await ApiClient.post(
      '/ai/chat',
      {
        'prompt': cleanMessage,
        'language': responseLanguage,
      },
    );

    print('==================================================');
    print('[AI FLUTTER] Response language: $responseLanguage');
    print('[AI FLUTTER] Backend response: $res');
    print('==================================================');

    final dynamic rawReply = res['aiResponse'];

    if (rawReply is! String || rawReply.trim().isEmpty) {
      throw Exception(
        'Backend did not return a valid aiResponse. '
        'Response: $res',
      );
    }

    final dynamic contextUsed = res['contextUsed'];

    final Map<String, dynamic> context =
        contextUsed is Map
            ? Map<String, dynamic>.from(contextUsed)
            : {};

    final int foodLogCount =
        _toInt(context['todayFoodLogs'] ?? context['foodLogs']);

    final int sleepLogCount =
        _toInt(context['todaySleepLogs'] ?? context['sleepLogs']);

    final int moodLogCount =
        _toInt(context['todayMoodLogs'] ?? context['moodLogs']);

    final int previousChats =
        _toInt(context['previousChats']);

    final String? date =
        context['date']?.toString();

    final bool aiAvailable =
        res['aiAvailable'] == true;

    final dynamic userContext = res['userContext'];

    String fastingPractice = 'orthodox';
    String? goal;

    if (userContext is Map) {
      final contextMap =
          Map<String, dynamic>.from(userContext);

      if (contextMap['fastingPractice'] != null) {
        fastingPractice =
            contextMap['fastingPractice'].toString();
      }

      if (contextMap['goal'] != null) {
        goal = contextMap['goal'].toString();
      }
    }

    return AiChatResponse(
      reply: rawReply.trim(),
      fastingPractice: fastingPractice,
      goal: goal,
      foodLogCount: foodLogCount,
      sleepLogCount: sleepLogCount,
      moodLogCount: moodLogCount,
      previousChats: previousChats,
      date: date,
      aiAvailable: aiAvailable,
    );
  }

  // ==========================================================================
  // CONVERT NUMERIC VALUES SAFELY
  // ==========================================================================

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==========================================================================
  // PANTRY SMART CHEF — PLAIN-TEXT AI RESPONSE
  // POST /api/v1/ai/smart-recommendations
  // ==========================================================================

  static Future<String> generatePantryRecipes({
    required List<String> ingredients,
    String? languageCode,
    String fastingPractice = 'none',
    List<String> dietaryRestrictions = const [],
    String cuisinePreference = 'Ethiopian',
    String mealType = 'any',
    int recipeCount = 3,
  }) async {
    final cleanIngredients = <String>[
      ...{
        for (final ingredient in ingredients)
          if (ingredient.trim().isNotEmpty)
            ingredient.trim(),
      },
    ];

    if (cleanIngredients.isEmpty) {
      throw Exception('Select at least one ingredient.');
    }

    if (cleanIngredients.length > 60) {
      throw Exception('Select no more than 60 ingredients.');
    }

    final safeRecipeCount =
        recipeCount.clamp(1, 8).toInt();

    final responseLanguage =
        _getResponseLanguage(languageCode);

    // ApiClient.baseUrl is a String, so parse it into a Uri first.
    final baseUrl = Uri.parse(ApiClient.baseUrl);

    // Preserve a possible API path prefix in the configured base URL.
    // For example:
    // https://example.com/api/v1
    // becomes:
    // https://example.com/api/v1/ai/smart-recommendations
    final normalizedBasePath =
        baseUrl.path.replaceFirst(RegExp(r'/+$'), '');

    final uri = baseUrl.replace(
      path: '$normalizedBasePath/ai/smart-recommendations',
      query: null,
      fragment: null,
    );

    // IMPORTANT:
    // The API client must expose the authentication token somehow for
    // this direct text response request. This implementation below
    // uses the existing ApiClient.post() for JSON calls, but plain-text
    // responses need a direct HTTP request.
    //
    // Add your existing token/header logic here if ApiClient uses
    // custom authentication headers.

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'text/plain',
      },
      body: _encodePantryRequest(
        ingredients: cleanIngredients,
        language: responseLanguage,
        fastingPractice: fastingPractice,
        dietaryRestrictions: dietaryRestrictions,
        cuisinePreference: cuisinePreference,
        mealType: mealType,
        recipeCount: safeRecipeCount,
      ),
    );

    print('==================================================');
    print('[PANTRY SMART CHEF] URL: $uri');
    print('[PANTRY SMART CHEF] Status: ${response.statusCode}');
    print('[PANTRY SMART CHEF] Response: ${response.body}');
    print('==================================================');

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        response.body.trim().isNotEmpty
            ? response.body.trim()
            : 'Recipe generation failed (${response.statusCode}).',
      );
    }

    final reply = response.body.trim();

    if (reply.isEmpty) {
      throw Exception('The AI returned empty recipe text.');
    }

    return reply;
  }

  // ==========================================================================
  // ENCODE PANTRY REQUEST
  // ==========================================================================

  static String _encodePantryRequest({
    required List<String> ingredients,
    required String language,
    required String fastingPractice,
    required List<String> dietaryRestrictions,
    required String cuisinePreference,
    required String mealType,
    required int recipeCount,
  }) {
    return jsonEncode({
      'ingredients': ingredients,
      'language': language,
      'fastingPractice': fastingPractice,
      'dietaryRestrictions': dietaryRestrictions,
      'cuisinePreference': cuisinePreference,
      'mealType': mealType,
      'recipeCount': recipeCount,
    });
  }

  // ==========================================================================
  // LEGACY STRUCTURED RECOMMENDATIONS
  // Retained for screens that still expect JSON recipe objects.
  // ==========================================================================

  static Future<List<RecipeRecommendation>>
      getSmartRecommendations({
    required List<String> ingredients,
    String? mealType,
    int numberOfRecipes = 3,
  }) async {
    final res = await ApiClient.post(
      '/ai/smart-recommendations',
      {
        'ingredients': ingredients,
        if (mealType != null) 'mealType': mealType,
        'numberOfRecipes': numberOfRecipes,
      },
    );

    final dynamic rawRecs =
        res['recommendedRecipes'] ??
        res['recommendations'];

    List<dynamic> list = [];

    if (rawRecs is Map &&
        rawRecs['recommendations'] is List) {
      list = rawRecs['recommendations'];
    } else if (rawRecs is List) {
      list = rawRecs;
    }

    return list
        .whereType<Map>()
        .map(
          (item) => RecipeRecommendation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}

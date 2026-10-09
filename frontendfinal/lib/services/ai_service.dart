import 'api_client.dart';

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

      description:
          json['description']?.toString() ?? '',

      ingredients:
          (json['ingredients'] is List)
              ? (json['ingredients'] as List)
                  .map((e) => e.toString())
                  .toList()
              : [],

      prepTimeMinutes:
          json['prepTimeMinutes'] is num
              ? (json['prepTimeMinutes'] as num).toInt()
              : 20,

      difficulty:
          json['difficulty']?.toString() ?? 'Easy',

      isVegan:
          json['isVegan'] == true,

      estimatedNutrition:
          json['estimatedNutrition'] is Map
              ? Map<String, dynamic>.from(
                  json['estimatedNutrition'],
                )
              : {},

      instructions:
          (json['instructions'] is List)
              ? (json['instructions'] as List)
                  .map((e) => e.toString())
                  .toList()
              : [],
    );
  }
}

class AiService {
  // ==========================================================================
  // SEND CHAT MESSAGE
  // POST /api/v1/ai/chat
  // ==========================================================================

  static Future<AiChatResponse> sendMessage(
    String message,
  ) async {
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final res = await ApiClient.post(
      '/ai/chat',
      {
        'prompt': cleanMessage,
      },
    );

    // ------------------------------------------------------------------------
    // DEBUG
    // ------------------------------------------------------------------------

    print('==================================================');
    print('[AI FLUTTER] Backend response:');
    print(res);
    print('==================================================');

    // ------------------------------------------------------------------------
    // GET ACTUAL AI RESPONSE
    // ------------------------------------------------------------------------

    final dynamic rawReply =
        res['aiResponse'];

    if (rawReply == null) {
      throw Exception(
        'Backend did not return aiResponse. '
        'Response: $res',
      );
    }

    if (rawReply is! String) {
      throw Exception(
        'Backend aiResponse is not a String. '
        'Type: ${rawReply.runtimeType}',
      );
    }

    final reply = rawReply.trim();

    if (reply.isEmpty) {
      throw Exception(
        'Backend returned an empty aiResponse.',
      );
    }

    // ------------------------------------------------------------------------
    // CONTEXT USED
    // ------------------------------------------------------------------------

    final dynamic contextUsed =
        res['contextUsed'];

    final Map<String, dynamic> context =
        contextUsed is Map
            ? Map<String, dynamic>.from(
                contextUsed,
              )
            : {};

    final int foodLogCount =
        _toInt(
          context['todayFoodLogs'],
        );

    final int sleepLogCount =
        _toInt(
          context['todaySleepLogs'],
        );

    final int moodLogCount =
        _toInt(
          context['todayMoodLogs'],
        );

    final int previousChats =
        _toInt(
          context['previousChats'],
        );

    final String? date =
        context['date']?.toString();

    // ------------------------------------------------------------------------
    // AI AVAILABILITY
    // ------------------------------------------------------------------------

    final bool aiAvailable =
        res['aiAvailable'] == true;

    // ------------------------------------------------------------------------
    // FASTING PRACTICE
    //
    // The new backend doesn't return userContext, so use a safe default.
    // ------------------------------------------------------------------------

    final dynamic userContext =
        res['userContext'];

    String fastingPractice =
        'orthodox';

    String? goal;

    if (userContext is Map) {
      final contextMap =
          Map<String, dynamic>.from(
            userContext,
          );

      if (contextMap['fastingPractice'] != null) {
        fastingPractice =
            contextMap['fastingPractice']
                .toString();
      }

      if (contextMap['goal'] != null) {
        goal =
            contextMap['goal'].toString();
      }
    }

    // ------------------------------------------------------------------------
    // RETURN REAL AI RESPONSE
    // ------------------------------------------------------------------------

    return AiChatResponse(
      reply: reply,

      fastingPractice:
          fastingPractice,

      goal: goal,

      foodLogCount:
          foodLogCount,

      sleepLogCount:
          sleepLogCount,

      moodLogCount:
          moodLogCount,

      previousChats:
          previousChats,

      date:
          date,

      aiAvailable:
          aiAvailable,
    );
  }

  // ==========================================================================
  // CONVERT ANY NUMERIC VALUE SAFELY TO INT
  // ==========================================================================

  static int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  // ==========================================================================
  // SMART RECIPES FROM PANTRY INGREDIENTS
  // POST /api/v1/ai/smart-recommendations
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

        if (mealType != null)
          'mealType': mealType,

        'numberOfRecipes':
            numberOfRecipes,
      },
    );

    final dynamic rawRecs =
        res['recommendedRecipes'] ??
        res['recommendations'];

    List<dynamic> list = [];

    if (rawRecs is Map &&
        rawRecs['recommendations'] is List) {
      list =
          rawRecs['recommendations'];
    } else if (rawRecs is List) {
      list = rawRecs;
    }

    return list
        .whereType<Map>()
        .map(
          (item) =>
              RecipeRecommendation.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }
}
import 'api_client.dart';

class AiChatResponse {
  final String reply;
  final String fastingPractice;
  final String? goal;
  final int foodLogCount;

  AiChatResponse({
    required this.reply,
    required this.fastingPractice,
    this.goal,
    required this.foodLogCount,
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

  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    return RecipeRecommendation(
      title: json['title'] ?? 'Ethiopian Recipe',
      description: json['description'] ?? '',
      ingredients: (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
      prepTimeMinutes: json['prepTimeMinutes'] ?? 20,
      difficulty: json['difficulty'] ?? 'Easy',
      isVegan: json['isVegan'] ?? false,
      estimatedNutrition: json['estimatedNutrition'] is Map<String, dynamic>
          ? json['estimatedNutrition']
          : {},
      instructions: (json['instructions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AiService {
  /// =========================================================================
  /// 1. SEND CHAT MESSAGE TO ETHIONUTRI AI
  /// Endpoint: POST /api/v1/ai/chat
  /// =========================================================================
  static Future<AiChatResponse> sendMessage(String message) async {
    final res = await ApiClient.post('/ai/chat', {
      'prompt': message.trim(),
      'message': message.trim(),
    });

    // Check all possible reply keys from backend
    final String reply = res['aiResponse'] ??
        res['reply'] ??
        res['data']?['response'] ??
        res['data']?['reply'] ??
        res['message'] ??
        'Selam! I am your EthioNutri AI assistant. How can I guide your heritage fasting nutrition today?';

    final userContext = res['userContext'] ?? res['data']?['userContext'] ?? {};

    return AiChatResponse(
      reply: reply,
      fastingPractice: userContext['fastingPractice'] ?? 'orthodox',
      goal: userContext['goal'],
      foodLogCount: userContext['foodLogCount'] ?? 0,
    );
  }

  /// =========================================================================
  /// 2. SMART RECIPES FROM PANTRY INGREDIENTS
  /// Endpoint: POST /api/v1/ai/smart-recommendations
  /// =========================================================================
  static Future<List<RecipeRecommendation>> getSmartRecommendations({
    required List<String> ingredients,
    String? mealType,
    int numberOfRecipes = 3,
  }) async {
    final res = await ApiClient.post('/ai/smart-recommendations', {
      'ingredients': ingredients,
      if (mealType != null) 'mealType': mealType,
      'numberOfRecipes': numberOfRecipes,
    });

    final rawRecs = res['recommendedRecipes'] ?? res['recommendations'];
    List<dynamic> list = [];

    if (rawRecs is Map && rawRecs['recommendations'] is List) {
      list = rawRecs['recommendations'];
    } else if (rawRecs is List) {
      list = rawRecs;
    }

    return list.map((item) => RecipeRecommendation.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
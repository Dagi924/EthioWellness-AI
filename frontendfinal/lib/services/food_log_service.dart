import 'api_client.dart';

class FoodLogService {
  static Future<List<dynamic>> searchFoods(String query) async {
    final res = await ApiClient.get(
      '/foods/search?query=${Uri.encodeComponent(query)}',
      requiresAuth: false,
    );
    return res['foods'] ?? [];
  }

  static Future<List<dynamic>> getOrthodoxFoods() async {
    final res = await ApiClient.get('/foods/search?query=fasting', requiresAuth: false);
    return res['foods'] ?? [];
  }

  static Future<Map<String, dynamic>> logMeal({
    String? foodId,
    required String foodName,
    required String mealType,
    required double portionGrams,
    required double calories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatsGrams,
    double ironMg = 0.0,
    bool isVegan = false,
  }) async {
    return await ApiClient.post('/food-logs/manual', {
      if (foodId != null) 'foodId': foodId,
      'foodName': foodName,
      'mealType': mealType,
      'portionGrams': portionGrams,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatsGrams': fatsGrams,
      'ironMg': ironMg,
      'isVegan': isVegan,
    });
  }

  static Future<Map<String, dynamic>> logWater(double amountMl) async {
    return await ApiClient.post('/food-logs/water', {
      'amountMl': amountMl,
    });
  }

  static Future<Map<String, dynamic>> getTodayLogs() async {
    return await ApiClient.get('/food-logs/today');
  }
}
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
  /// GET /api/v1/meal-plans/weekly?week=current
  static Future<MealPlanModel?> getCurrentPlan({String week = 'current'}) async {
    try {
      final res = await ApiClient.get('/meal-plans/weekly?week=$week');
      final dynamic rawPlan = res['plan']?['planData'] ?? res['plan'] ?? res['data'];

      if (rawPlan == null) return null;

      // Handle both List format [...] and Object format { planDays: [...] }
      if (rawPlan is List) {
        return MealPlanModel.fromJson({
          'summary': 'Weekly Ethiopian Fasting & Nutrition Plan',
          'planDays': rawPlan,
        });
      } else if (rawPlan is Map<String, dynamic>) {
        return MealPlanModel.fromJson(rawPlan);
      } else if (rawPlan is Map) {
        return MealPlanModel.fromJson(Map<String, dynamic>.from(rawPlan));
      }
      return null;
    } catch (e) {
      print('Error parsing meal plan: $e');
      return null;
    }
  }

  /// POST /api/v1/meal-plans/generate
  static Future<MealPlanModel> generateMealPlan() async {
    final isPremium = await AuthService.isPremiumUser();
    if (!isPremium) {
      throw PremiumRequiredException(
        'Upgrade to Premium to generate personalized 7-Day Ethiopian Fasting Meal Plans.',
      );
    }

    final res = await ApiClient.post('/meal-plans/generate', {});
    final dynamic rawPlan = res['plan']?['planData'] ?? res['plan'] ?? res['result'] ?? res['data'];

    if (rawPlan is List) {
      return MealPlanModel.fromJson({
        'summary': 'Personalized 7-Day Fasting Plan',
        'planDays': rawPlan,
      });
    } else if (rawPlan is Map<String, dynamic>) {
      return MealPlanModel.fromJson(rawPlan);
    } else if (rawPlan is Map) {
      return MealPlanModel.fromJson(Map<String, dynamic>.from(rawPlan));
    }
    throw Exception('Invalid meal plan structure returned from backend AI service.');
  }

  /// GET /api/v1/grocery/list
  static Future<Map<String, dynamic>> getGroceryList() async {
    final res = await ApiClient.get('/grocery/list');
    return {
      'totalItems': res['totalItems'] ?? 0,
      'estimatedTotalEtb': (res['estimatedTotalEtb'] as num?)?.toDouble() ?? 0.0,
      'items': res['items'] ?? [],
    };
  }

  /// POST /api/v1/grocery/generate
  static Future<Map<String, dynamic>> generateGroceryList() async {
    final isPremium = await AuthService.isPremiumUser();
    if (!isPremium) {
      throw PremiumRequiredException(
        'Upgrade to Premium to generate automated market grocery lists with ETB pricing.',
      );
    }

    final res = await ApiClient.post('/grocery/generate', {});
    return {
      'message': res['message'] ?? 'Grocery list generated',
      'totalItems': res['totalItems'] ?? 0,
      'estimatedTotalEtb': (res['estimatedTotalEtb'] as num?)?.toDouble() ?? 0.0,
      'items': res['items'] ?? [],
    };
  }

  /// PATCH /api/v1/grocery/items/:id
  static Future<Map<String, dynamic>> updateGroceryItem({
    required String id,
    bool? isChecked,
    String? quantity,
  }) async {
    final Map<String, dynamic> body = {};
    if (isChecked != null) body['isChecked'] = isChecked;
    if (quantity != null) body['quantity'] = quantity;

    return await ApiClient.patch('/grocery/items/$id', body);
  }

  /// DELETE /api/v1/grocery/items/:id
  static Future<void> deleteGroceryItem(String id) async {
    await ApiClient.delete('/grocery/items/$id');
  }
}
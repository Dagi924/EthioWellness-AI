import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../screens/main_shell_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/nutritionist_dashboard_screen.dart';

class AuthService {
  static const String _roleKey = 'userRole';
  static const String _isPremiumKey = 'isPremium';

  /// Save user role to local storage
  static Future<void> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  /// Get cached user role
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? 'user';
  }

  /// Save isPremium status to local storage
  static Future<void> setPremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, isPremium);
  }

  /// Check if current user is premium
  static Future<bool> isPremiumUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPremiumKey) ?? false;
  }

  /// Helper to route based on user role
 /// Helper to route based on user role
static Widget getDashboardForRole(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return const AdminDashboardScreen();

    case 'nutritionist':
      return const NutritionistDashboardScreen();

    case 'user':
    default:
      return const MainShellScreen();
  }
}

/// Get dashboard for currently logged-in user
static Future<Widget> getDashboardForCurrentUser() async {
  final role = await getUserRole();
  return getDashboardForRole(role);
}
  /// =========================================================================
  /// REGISTER NEW USER
  /// =========================================================================
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? fastingPractice,
    List<String>? healthConditions,
    String? language,
    String? theme,
    bool? notificationsEnabled,
    int? age,
    String? gender,
    double? weightKg,
    double? targetWeightKg,
    double? heightCm,
    String? goal,
    String? budgetLevel,
    int? dailyCalorieTarget,
    int? dailyProteinTarget,
    int? dailyCarbsTarget,
    int? dailyFatsTarget,
    double? dailyWaterTarget,
  }) async {
    final payload = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (fastingPractice != null) 'fastingPractice': fastingPractice,
      if (healthConditions != null) 'healthConditions': healthConditions,
      if (language != null) 'language': language,
      if (theme != null) 'theme': theme,
      if (notificationsEnabled != null) 'notificationsEnabled': notificationsEnabled,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (weightKg != null) 'weightKg': weightKg,
      if (targetWeightKg != null) 'targetWeightKg': targetWeightKg,
      if (heightCm != null) 'heightCm': heightCm,
      if (goal != null) 'goal': goal,
      if (budgetLevel != null) 'budgetLevel': budgetLevel,
      if (dailyCalorieTarget != null) 'dailyCalorieTarget': dailyCalorieTarget,
      if (dailyProteinTarget != null) 'dailyProteinTarget': dailyProteinTarget,
      if (dailyCarbsTarget != null) 'dailyCarbsTarget': dailyCarbsTarget,
      if (dailyFatsTarget != null) 'dailyFatsTarget': dailyFatsTarget,
      if (dailyWaterTarget != null) 'dailyWaterTarget': dailyWaterTarget,
    };

    final res = await ApiClient.post('/auth/register', payload, requiresAuth: false);

    if (res['accessToken'] != null) {
      await ApiClient.setTokens(res['accessToken'], res['refreshToken'] ?? '');
      final user = res['user'] ?? {};
      await setUserRole(user['role'] ?? 'user');
      await setPremiumStatus(user['isPremium'] == true);
    }
    return res;
  }

  /// =========================================================================
  /// USER LOGIN
  /// =========================================================================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    }, requiresAuth: false);

    if (res['accessToken'] != null) {
      await ApiClient.setTokens(res['accessToken'], res['refreshToken'] ?? '');
      final user = res['user'] ?? {};
      await setUserRole(user['role'] ?? 'user');
      await setPremiumStatus(user['isPremium'] == true);
    }
    return res;
  }

  /// =========================================================================
  /// LOGOUT
  /// =========================================================================
  static Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {}
    await ApiClient.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_isPremiumKey);
  }

  /// =========================================================================
  /// GET PROFILE
  /// =========================================================================
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await ApiClient.get('/user/profile');
    final user = res['user'] ?? {};
    if (user['role'] != null) {
      await setUserRole(user['role']);
    }
    if (user['isPremium'] != null) {
      await setPremiumStatus(user['isPremium'] == true);
    }
    return res;
  }

  /// =========================================================================
  /// UPDATE PROFILE
  /// =========================================================================
  static Future<Map<String, dynamic>> updateProfile({
    int? age,
    String? gender,
    double? weightKg,
    double? targetWeightKg,
    double? heightCm,
    String? activityLevel,
    String? goal,
    String? fastingPractice,
    String? budgetLevel,
    int? dailyCalorieTarget,
    int? dailyProteinTarget,
    int? dailyCarbsTarget,
    int? dailyFatsTarget,
    double? dailyWaterTarget,
  }) async {
    return await ApiClient.put('/user/profile', {
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (weightKg != null) 'weightKg': weightKg,
      if (targetWeightKg != null) 'targetWeightKg': targetWeightKg,
      if (heightCm != null) 'heightCm': heightCm,
      if (activityLevel != null) 'activityLevel': activityLevel,
      if (goal != null) 'goal': goal,
      if (fastingPractice != null) 'fastingPractice': fastingPractice,
      if (budgetLevel != null) 'budgetLevel': budgetLevel,
      if (dailyCalorieTarget != null) 'dailyCalorieTarget': dailyCalorieTarget,
      if (dailyProteinTarget != null) 'dailyProteinTarget': dailyProteinTarget,
      if (dailyCarbsTarget != null) 'dailyCarbsTarget': dailyCarbsTarget,
      if (dailyFatsTarget != null) 'dailyFatsTarget': dailyFatsTarget,
      if (dailyWaterTarget != null) 'dailyWaterTarget': dailyWaterTarget,
    });
  }
}
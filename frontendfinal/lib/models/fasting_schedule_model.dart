class ActiveFast {
  final String type; // 'orthodox' or 'ramadan'
  final String title;
  final String? titleAmharic;
  final String dietaryRule;
  final bool isVeganRequired;
  final bool isFasting;
  final String allowedDescription;

  ActiveFast({
    required this.type,
    required this.title,
    this.titleAmharic,
    required this.dietaryRule,
    required this.isVeganRequired,
    required this.isFasting,
    required this.allowedDescription,
  });

  factory ActiveFast.fromJson(Map<String, dynamic> json) {
    return ActiveFast(
      type: json['type'] ?? 'orthodox',
      title: json['title'] ?? 'Fasting Day',
      titleAmharic: json['titleAmharic'],
      dietaryRule: json['dietaryRule'] ?? 'Strict Vegan',
      isVeganRequired: json['isVeganRequired'] ?? false,
      isFasting: json['fasting'] ?? true,
      allowedDescription: json['allowedDescription'] ?? '',
    );
  }
}

class NutritionTip {
  final String id;
  final String title;
  final String category;
  final String description;

  NutritionTip({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
  });

  factory NutritionTip.fromJson(Map<String, dynamic> json) {
    return NutritionTip(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'Nutrition',
      description: json['description'] ?? '',
    );
  }
}

class FastingScheduleModel {
  final bool success;
  final String date;
  final String fastingPractice; // 'orthodox', 'ramadan', 'none'
  final bool isFastingDay;
  final ActiveFast? activeFast;
  final List<NutritionTip> nutritionTips;

  FastingScheduleModel({
    required this.success,
    required this.date,
    required this.fastingPractice,
    required this.isFastingDay,
    this.activeFast,
    required this.nutritionTips,
  });

  factory FastingScheduleModel.fromJson(Map<String, dynamic> json) {
    return FastingScheduleModel(
      success: json['success'] ?? false,
      date: json['date'] ?? '',
      fastingPractice: json['fastingPractice'] ?? 'none',
      isFastingDay: json['isFastingDay'] ?? false,
      activeFast: json['activeFast'] != null
          ? ActiveFast.fromJson(json['activeFast'])
          : null,
      nutritionTips: (json['nutritionTips'] as List?)
              ?.map((tip) => NutritionTip.fromJson(tip))
              .toList() ??
          [],
    );
  }

  // Friendly title helper for UI
  String get displayTitle {
    if (!isFastingDay) return 'Non-Fasting Day (የፍስክ ቀን)';
    if (activeFast?.titleAmharic != null) {
      return '${activeFast!.title} (${activeFast!.titleAmharic})';
    }
    return activeFast?.title ?? 'Fasting (ጾም)';
  }

  String get advice {
    if (!isFastingDay) {
      return 'Regular balanced diet. Maintain your daily protein, carbs, and iron targets.';
    }
    return activeFast?.allowedDescription ??
        'Follow your fasting guidelines and focus on plant-based Ethiopian legumes.';
  }
}
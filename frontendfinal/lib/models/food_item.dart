class FoodItem {
  final String id;
  final String name;
  final String? nameAmharic;
  final String category;
  final double caloriesPer100g;
  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;
  final double fiberGrams;
  final double waterGrams;
  final double ironMg;
  final bool isVegan;

  const FoodItem({
    required this.id,
    required this.name,
    this.nameAmharic,
    this.category = '',
    required this.caloriesPer100g,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    this.fiberGrams = 0.0,
    this.waterGrams = 0.0,
    this.ironMg = 0.0,
    this.isVegan = false,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    double numberValue(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    bool boolValue(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;

      final normalized = value?.toString().toLowerCase().trim();

      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes';
    }

    return FoodItem(
      id: (json['code'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown food').toString(),
      nameAmharic: json['nameAmharic']?.toString(),
      category: (json['category'] ?? '').toString(),

      caloriesPer100g: numberValue(
        json['energyKcal'] ?? json['caloriesPer100g'],
      ),

      proteinGrams: numberValue(
        json['proteinG'] ?? json['proteinGrams'],
      ),

      carbsGrams: numberValue(
        json['carbsG'] ?? json['carbsGrams'],
      ),

      fatsGrams: numberValue(
        json['fatG'] ?? json['fatsGrams'],
      ),

      fiberGrams: numberValue(
        json['fiberG'] ?? json['fiberGrams'],
      ),

      waterGrams: numberValue(
        json['waterG'] ?? json['waterGrams'],
      ),

      ironMg: numberValue(json['ironMg']),

      // Vegan status must come from explicit data.
      isVegan: boolValue(json['isVegan']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': id,
      'name': name,
      'nameAmharic': nameAmharic,
      'category': category,
      'energyKcal': caloriesPer100g,
      'proteinG': proteinGrams,
      'carbsG': carbsGrams,
      'fatG': fatsGrams,
      'fiberG': fiberGrams,
      'waterG': waterGrams,
      'ironMg': ironMg,
      'isVegan': isVegan,
    };
  }

  /// Returns nutrition values adjusted for a given portion size.
  Map<String, double> nutritionForPortion(double portionGrams) {
    final multiplier = portionGrams / 100.0;

    return {
      'calories': caloriesPer100g * multiplier,
      'proteinGrams': proteinGrams * multiplier,
      'carbsGrams': carbsGrams * multiplier,
      'fatsGrams': fatsGrams * multiplier,
      'fiberGrams': fiberGrams * multiplier,
      'waterGrams': waterGrams * multiplier,
      'ironMg': ironMg * multiplier,
    };
  }
}

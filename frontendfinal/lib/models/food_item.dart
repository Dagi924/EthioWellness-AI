class FoodItem {
  final String id;
  final String name;
  final String? nameAmharic;
  final String category;
  final double caloriesPer100g;
  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;
  final double ironMg;
  final double zincMg;
  final double calciumMg;
  final bool isVegan;
  final bool isTraditional;
  final String? faoReference;

  FoodItem({
    required this.id,
    required this.name,
    this.nameAmharic,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    this.ironMg = 0.0,
    this.zincMg = 0.0,
    this.calciumMg = 0.0,
    this.isVegan = false,
    this.isTraditional = true,
    this.faoReference,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      nameAmharic: json['nameAmharic'] ?? json['name_amharic'],
      category: json['category'] ?? 'General',
      caloriesPer100g: (json['caloriesPer100g'] ?? json['calories_per_100g'] ?? 0).toDouble(),
      proteinGrams: (json['proteinGrams'] ?? json['protein_grams'] ?? 0).toDouble(),
      carbsGrams: (json['carbsGrams'] ?? json['carbs_grams'] ?? 0).toDouble(),
      fatsGrams: (json['fatsGrams'] ?? json['fats_grams'] ?? 0).toDouble(),
      ironMg: (json['ironMg'] ?? json['iron_mg'] ?? 0).toDouble(),
      zincMg: (json['zincMg'] ?? json['zinc_mg'] ?? 0).toDouble(),
      calciumMg: (json['calciumMg'] ?? json['calcium_mg'] ?? 0).toDouble(),
      isVegan: json['isVegan'] ?? json['is_vegan'] ?? false,
      isTraditional: json['isTraditional'] ?? json['is_traditional'] ?? true,
      faoReference: json['faoReference'] ?? json['fao_reference'],
    );
  }
}
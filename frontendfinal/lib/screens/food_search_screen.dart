import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/food_log_service.dart';
import 'food_log_detail_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<FoodItem> _foods = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawFoods = await FoodLogService.searchFoods(query);
      if (!mounted) return;
      setState(() {
        _foods = rawFoods.map((f) => FoodItem.fromJson(f)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search error: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ethiopian Food Table (FAO)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5),
            ),
            Text(
              'Verified Ethiopian Institute of Public Health Data',
              style: TextStyle(fontSize: 11, color: Color(0xFFEADBCE)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Container with valid decoration configuration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFEADBCE)),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => _performSearch(val),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1C1917)),
              decoration: InputDecoration(
                hintText: 'Search Teff, Shiro, Misir, Gomen, Doro...',
                hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8D4F28)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF78716C)),
                        onPressed: () {
                          _searchCtrl.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F3EC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF542E13), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF542E13)),
                  )
                : _foods.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5EBE1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 32,
                                  color: Color(0xFF8D4F28),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Ethiopian foods found.',
                                style: TextStyle(color: Color(0xFF78716C), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _foods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final food = _foods[idx];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEADBCE)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      food.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1C1917),
                                      ),
                                    ),
                                  ),
                                  if (food.isVegan)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5EBE1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFEADBCE)),
                                      ),
                                      child: const Text(
                                        'Tsom / ጾም',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF542E13),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (food.nameAmharic != null)
                                      Text(
                                        food.nameAmharic!,
                                        style: const TextStyle(
                                          color: Color(0xFF8D4F28),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${food.caloriesPer100g.toInt()} kcal • P: ${food.proteinGrams}g • C: ${food.carbsGrams}g • Fe: ${food.ironMg}mg (per 100g)',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8F3EC),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFF542E13),
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FoodLogDetailScreen(food: food),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
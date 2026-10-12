import 'dart:async';

import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/food_log_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

import 'food_log_detail_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _debounce;

  List<FoodItem> _foods = [];

  bool _isLoading = false;
  String? _errorMessage;

  String _t(String key) => AppLocalization.instance.tr(key);

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    setState(() {});

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _performSearch(query.trim());
      },
    );
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawFoods = await FoodLogService.searchFoods(query);

      if (!mounted) return;

      final foods = rawFoods
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList();

      setState(() {
        _foods = foods;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _foods = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();

    setState(() {});

    _performSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) {
        return _buildScreen();
      },
    );
  }

  Widget _buildScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('food_table_title'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
              ),
            ),
            Text(
              _t('food_table_subtitle'),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFEADBCE),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Center(
              child: LanguageToggleButton(),
            ),
          ),
        ],
        backgroundColor: const Color(0xFF542E13),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEADBCE),
                ),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1C1917),
              ),
              decoration: InputDecoration(
                hintText: _t('food_search_hint'),
                hintStyle: const TextStyle(
                  color: Color(0xFFA8A29E),
                  fontSize: 13.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF8D4F28),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Color(0xFF78716C),
                        ),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F3EC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFEADBCE),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFEADBCE),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF542E13),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF542E13),
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _foods.isEmpty
                        ? _buildEmptyState()
                        : _buildFoodList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            Text(
              _t('foods_load_failed'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1C1917),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF78716C),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _performSearch(_searchCtrl.text.trim());
              },
              child: Text(_t('try_again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            Text(
              _searchCtrl.text.trim().isEmpty
                  ? _t('no_foods_available')
                  : _t('no_ethiopian_foods_found'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF78716C),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _foods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final food = _foods[idx];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEADBCE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
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
                      border: Border.all(
                        color: const Color(0xFFEADBCE),
                      ),
                    ),
                    child: Text(
                      _t('fasting_food_label'),
                      style: const TextStyle(
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
                  if (food.nameAmharic != null &&
                      food.nameAmharic!.isNotEmpty)
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
                    '${food.caloriesPer100g.toStringAsFixed(0)} ${_t('kcal_unit')} • '
                    '${_t('protein_short')}: ${food.proteinGrams.toStringAsFixed(1)}g • '
                    '${_t('carbs_short')}: ${food.carbsGrams.toStringAsFixed(1)}g • '
                    '${_t('iron_short')}: ${food.ironMg.toStringAsFixed(1)}mg ${_t('per_100g')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
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
    );
  }
}

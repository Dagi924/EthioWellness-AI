
import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

import 'meal_logger_screen.dart';
import 'food_search_screen.dart';
import 'meal_and_grocery_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  static const Color _backgroundColor = Color(0xFFF7F2EA);
  static const Color _primaryColor = Color(0xFF542E13);
  static const Color _inactiveColor = Color(0xFF78716C);
  static const Color _borderColor = Color(0xFFEADBCE);
  static const Color _indicatorColor = Color(0xFFF5EBE1);

  final List<Widget> _screens = const [
    MealLoggerScreen(),
    FoodSearchScreen(),
    MealAndGroceryScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  String _tr(String key) {
    return AppLocalization.instance.tr(key);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundColor,

          // --------------------------------------------------
          // APP BAR
          // --------------------------------------------------
          appBar: AppBar(
            backgroundColor: _backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,

            title: Text(
              _tr('app_name'),
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),

            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: LanguageToggleButton(),
                ),
              ),
            ],
          ),

          // --------------------------------------------------
          // SCREEN CONTENT
          // --------------------------------------------------
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // --------------------------------------------------
          // BOTTOM NAVIGATION
          // --------------------------------------------------
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: _borderColor,
                  width: 1,
                ),
              ),
            ),

            child: NavigationBar(
              selectedIndex: _currentIndex,

              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },

              backgroundColor: Colors.white,
              indicatorColor: _indicatorColor,
              elevation: 0,
              height: 66,

              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,

              destinations: [
                NavigationDestination(
                  icon: const Icon(
                    Icons.dashboard_outlined,
                    color: _inactiveColor,
                    size: 22,
                  ),
                  selectedIcon: const Icon(
                    Icons.dashboard_rounded,
                    color: _primaryColor,
                    size: 23,
                  ),
                  label: _tr('nav_today'),
                ),

                NavigationDestination(
                  icon: const Icon(
                    Icons.search_outlined,
                    color: _inactiveColor,
                    size: 22,
                  ),
                  selectedIcon: const Icon(
                    Icons.search_rounded,
                    color: _primaryColor,
                    size: 23,
                  ),
                  label: _tr('nav_fao_foods'),
                ),

                NavigationDestination(
                  icon: const Icon(
                    Icons.restaurant_menu_outlined,
                    color: _inactiveColor,
                    size: 22,
                  ),
                  selectedIcon: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: _primaryColor,
                    size: 23,
                  ),
                  label: _tr('nav_meal_grocery'),
                ),

                NavigationDestination(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _inactiveColor,
                    size: 22,
                  ),
                  selectedIcon: const Icon(
                    Icons.chat_bubble_rounded,
                    color: _primaryColor,
                    size: 23,
                  ),
                  label: _tr('nav_ai_coach'),
                ),

                NavigationDestination(
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: _inactiveColor,
                    size: 22,
                  ),
                  selectedIcon: const Icon(
                    Icons.person_rounded,
                    color: _primaryColor,
                    size: 23,
                  ),
                  label: _tr('nav_profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
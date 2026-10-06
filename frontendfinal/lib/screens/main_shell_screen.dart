import 'package:flutter/material.dart';
import 'meal_logger_screen.dart';
import 'food_search_screen.dart';
import 'meal_and_grocery_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

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
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand canvas
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEADBCE), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFF5EBE1), // Soft sand rounded indicator pill
          elevation: 0,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            // 1. Daily Meal & Water Log
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: Color(0xFF78716C), size: 22),
              selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF542E13), size: 23),
              label: 'Today',
            ),
            // 2. FAO Ethiopian Food Database Search
            NavigationDestination(
              icon: Icon(Icons.search_outlined, color: Color(0xFF78716C), size: 22),
              selectedIcon: Icon(Icons.search_rounded, color: Color(0xFF542E13), size: 23),
              label: 'FAO Foods',
            ),
            // 3. 7-Day Heritage Meal Plan & Smart Grocery Generator
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined, color: Color(0xFF78716C), size: 22),
              selectedIcon: Icon(Icons.restaurant_menu_rounded, color: Color(0xFF542E13), size: 23),
              label: 'Meal & Grocery',
            ),
            // 4. Gemini AI Ethiopian Nutritionist Coach
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF78716C), size: 22),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: Color(0xFF542E13), size: 23),
              label: 'AI Coach',
            ),
            // 5. User Profile, Fasting Preferences & Goals
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: Color(0xFF78716C), size: 22),
              selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF542E13), size: 23),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
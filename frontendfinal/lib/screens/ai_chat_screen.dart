import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

// ============================================================================
// CHAT MESSAGE
// ============================================================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? fastingPractice;
  final String? translationKey;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fastingPractice,
    this.translationKey,
  });
}

// ============================================================================
// AI CHAT SCREEN
// ============================================================================

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageCtrl =
      TextEditingController();

  final ScrollController _scrollCtrl =
      ScrollController();

  final List<ChatMessage> _messages = [];

  bool _isLoading = false;

  String _activeFastingRule = 'Orthodox (ጾም)';

  final List<String> _quickPrompts = [
    'How do I balance iron during Orthodox fasting?',
    'What are the nutritional benefits of Red Teff vs White Teff?',
    'High-protein fasting meal ideas using Shiro and Telba.',
    'Am I on track with my calories & protein today?',
  ];

  final List<String> _quickPromptKeys = [
    'chat_quick_prompt_iron',
    'chat_quick_prompt_teff',
    'chat_quick_prompt_protein',
    'chat_quick_prompt_daily_nutrition',
  ];

  // ==========================================================================
  // PANTRY INGREDIENTS
  // ==========================================================================

  final Map<String, List<String>> _pantryCategories = {
    'Grains & staples': [
      'Teff Flour',
      'Teff Injera',
      'Wheat Flour',
      'Rice',
      'Oats',
      'Pasta',
      'Bread',
      'Potatoes',
      'Sweet Potatoes',
    ],
    'Legumes & protein': [
      'Shiro Powder',
      'Lentils',
      'Chickpeas',
      'Split Peas',
      'Beans',
      'Peanuts',
      'Telba (Flaxseed)',
      'Sunflower Seeds',
      'Eggs',
      'Milk',
      'Yogurt',
      'Cheese',
      'Chicken',
      'Beef',
      'Fish',
    ],
    'Vegetables': [
      'Onion',
      'Garlic',
      'Tomato',
      'Carrot',
      'Cabbage',
      'Spinach',
      'Kale',
      'Green Pepper',
      'Potato',
      'Pumpkin',
    ],
    'Spices & oils': [
      'Berbere',
      'Mitmita',
      'Turmeric',
      'Ginger',
      'Black Pepper',
      'Cumin',
      'Olive Oil',
      'Vegetable Oil',
      'Salt',
    ],
    'Other': [
      'Banana',
      'Avocado',
      'Lemon',
      'Honey',
      'Sugar',
      'Coffee',
    ],
  };

  final Map<String, String> _pantryTranslationKeys = {
    'Teff Flour': 'chat_pantry_teff_flour',
    'Shiro Powder': 'chat_pantry_shiro_powder',
    'Onion': 'chat_pantry_onion',
    'Berbere': 'chat_pantry_berbere',
    'Garlic': 'chat_pantry_garlic',
    'Lentils': 'chat_pantry_lentils',
  };

  String _tr(String key) {
    return AppLocalization.instance.tr(key);
  }

  String get _responseLanguage {
    final languageCode =
        AppLocalization.instance.locale.languageCode;

    return languageCode == 'am' ? 'am' : 'en';
  }

  @override
  void initState() {
    super.initState();

    _messages.add(
      ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        translationKey: 'chat_welcome_message',
      ),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _messageText(ChatMessage message) {
    if (message.translationKey != null) {
      return _tr(message.translationKey!);
    }

    return message.text;
  }

  String _pantryLabel(String item) {
    final key = _pantryTranslationKeys[item];

    return key == null ? item : _tr(key);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;

      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _addMessage({
    required String text,
    required bool isUser,
    String? fastingPractice,
  }) {
    _messages.add(
      ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
        fastingPractice: fastingPractice,
      ),
    );
  }

  // ==========================================================================
  // NORMAL AI CHAT
  // ==========================================================================

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMessage = text.trim();
    final languageCode = _responseLanguage;

    _messageCtrl.clear();

    setState(() {
      _addMessage(
        text: userMessage,
        isUser: true,
      );

      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiResult = await AiService.sendMessage(
        userMessage,
        languageCode: languageCode,
      );

      if (!mounted) return;

      setState(() {
        _activeFastingRule =
            aiResult.fastingPractice.toUpperCase();

        _addMessage(
          text: aiResult.reply,
          isUser: false,
          fastingPractice: aiResult.fastingPractice,
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _addMessage(
          text: '${_tr('chat_connection_error')}: $error',
          isUser: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ==========================================================================
  // PANTRY SMART CHEF
  //
  // Calls the dedicated plain-text recipe endpoint through AiService.
  // It does NOT send pantry requests to the normal chatbot endpoint.
  // ==========================================================================

  Future<void> _generatePantryRecipes({
    required List<String> ingredients,
    required String fastingPractice,
    required List<String> dietaryRestrictions,
    required String cuisinePreference,
    required String mealType,
    required int recipeCount,
  }) async {
    if (_isLoading) return;

    final languageCode = _responseLanguage;

    final summary = StringBuffer()
      ..writeln('Create $recipeCount $cuisinePreference recipe(s).')
      ..writeln('Ingredients: ${ingredients.join(', ')}')
      ..writeln('Fasting practice: $fastingPractice')
      ..writeln('Dietary restrictions: '
          '${dietaryRestrictions.isEmpty ? 'None specified' : dietaryRestrictions.join(', ')}')
      ..writeln('Meal type: $mealType');

    setState(() {
      _addMessage(
        text: summary.toString().trim(),
        isUser: true,
        fastingPractice: fastingPractice,
      );

      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final recipeText = await AiService.generatePantryRecipes(
        ingredients: ingredients,
        languageCode: languageCode,
        fastingPractice: fastingPractice,
        dietaryRestrictions: dietaryRestrictions,
        cuisinePreference: cuisinePreference,
        mealType: mealType,
        recipeCount: recipeCount,
      );

      if (!mounted) return;

      setState(() {
        _addMessage(
          text: recipeText,
          isUser: false,
          fastingPractice: fastingPractice,
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _addMessage(
          text: 'Could not generate recipes: $error',
          isUser: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ==========================================================================
  // PANTRY BOTTOM SHEET
  // ==========================================================================

  void _openPantryRecipeSheet() {
    final Set<String> selected = {
      'Teff Flour',
      'Shiro Powder',
      'Onion',
    };

    final Set<String> selectedRestrictions = {};

    String searchQuery = '';
    String fastingPractice = 'Orthodox fasting';
    String cuisinePreference = 'Ethiopian';
    String mealType = 'Any meal';
    int recipeCount = 3;

    final List<String> fastingOptions = [
      'None',
      'Orthodox fasting',
      'Ramadan fasting',
      'Vegetarian',
      'Vegan',
    ];

    final List<String> cuisineOptions = [
      'Ethiopian',
      'East African',
      'Mediterranean',
      'Asian',
      'Mixed',
    ];

    final List<String> mealOptions = [
      'Any meal',
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snack',
    ];

    final List<String> restrictionOptions = [
      'Gluten-free',
      'Dairy-free',
      'Nut-free',
      'Low-sodium',
      'No added sugar',
      'High-protein',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: AppLocalization.instance,
          builder: (context, child) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final query = searchQuery.toLowerCase().trim();

                final visibleCategories =
                    _pantryCategories.entries
                        .map((entry) {
                          final items = entry.value.where((item) {
                            return query.isEmpty ||
                                item.toLowerCase().contains(query);
                          }).toList();

                          return MapEntry(entry.key, items);
                        })
                        .where((entry) => entry.value.isNotEmpty)
                        .toList();

                return SafeArea(
                  child: FractionallySizedBox(
                    heightFactor: 0.92,
                    child: Column(
                      children: [
                        // ----------------------------------------------------
                        // HEADER
                        // ----------------------------------------------------

                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            18,
                            12,
                            8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5EBE1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.kitchen_rounded,
                                  color: Color(0xFF8D4F28),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tr('chat_pantry_title'),
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF542E13),
                                      ),
                                    ),
                                    Text(
                                      _tr('chat_pantry_description'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF78716C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext),
                                icon: const Icon(
                                  Icons.close_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(
                          color: Color(0xFFEADBCE),
                          height: 1,
                        ),

                        // ----------------------------------------------------
                        // SCROLLABLE OPTIONS
                        // ----------------------------------------------------

                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              16,
                              20,
                              20,
                            ),
                            children: [
                              // Search ingredients.
                              TextField(
                                onChanged: (value) {
                                  setSheetState(() {
                                    searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search ingredients...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                  ),
                                  filled: true,
                                  fillColor:
                                      const Color(0xFFF8F3EC),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Your ingredients',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF542E13),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${selected.length} selected',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF78716C),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Ingredient categories.
                              ...visibleCategories.map((category) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                        top: 10,
                                        bottom: 5,
                                      ),
                                      child: Text(
                                        category.key,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF78716C),
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: category.value.map((item) {
                                        final isSelected =
                                            selected.contains(item);

                                        return FilterChip(
                                          label: Text(
                                            _pantryLabel(item),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor:
                                              const Color(0xFFF5EBE1),
                                          backgroundColor:
                                              const Color(0xFFF8F3EC),
                                          checkmarkColor:
                                              const Color(0xFF542E13),
                                          onSelected: (value) {
                                            setSheetState(() {
                                              if (value) {
                                                selected.add(item);
                                              } else {
                                                selected.remove(item);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                );
                              }),

                              const SizedBox(height: 22),

                              // Cuisine preference.
                              const Text(
                                'Cuisine preference',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF542E13),
                                ),
                              ),

                              const SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                value: cuisinePreference,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor:
                                      const Color(0xFFF8F3EC),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: cuisineOptions.map((option) {
                                  return DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setSheetState(() {
                                    cuisinePreference = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 18),

                              // Fasting preference.
                              const Text(
                                'Fasting and diet preference',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF542E13),
                                ),
                              ),

                              const SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                value: fastingPractice,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor:
                                      const Color(0xFFF8F3EC),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: fastingOptions.map((option) {
                                  return DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setSheetState(() {
                                    fastingPractice = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 18),

                              // Meal type.
                              const Text(
                                'Meal type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF542E13),
                                ),
                              ),

                              const SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                value: mealType,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor:
                                      const Color(0xFFF8F3EC),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: mealOptions.map((option) {
                                  return DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setSheetState(() {
                                    mealType = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 18),

                              // Dietary restrictions.
                              const Text(
                                'Additional dietary requirements',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF542E13),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: restrictionOptions.map((item) {
                                  final isSelected =
                                      selectedRestrictions.contains(item);

                                  return FilterChip(
                                    label: Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (value) {
                                      setSheetState(() {
                                        if (value) {
                                          selectedRestrictions.add(item);
                                        } else {
                                          selectedRestrictions.remove(item);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 18),

                              // Recipe count.
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Number of recipes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF542E13),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5EBE1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$recipeCount',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF542E13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Slider(
                                value: recipeCount.toDouble(),
                                min: 1,
                                max: 8,
                                divisions: 7,
                                activeColor:
                                    const Color(0xFF542E13),
                                onChanged: (value) {
                                  setSheetState(() {
                                    recipeCount = value.round();
                                  });
                                },
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),

                        // ----------------------------------------------------
                        // GENERATE BUTTON
                        // ----------------------------------------------------

                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            16,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFFEADBCE),
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF542E13),
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 19,
                              ),
                              label: Text(
                                'Generate $recipeCount recipe(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      final ingredients =
                                          selected.toList();

                                      final restrictions =
                                          selectedRestrictions.toList();

                                      Navigator.pop(sheetContext);

                                      _generatePantryRecipes(
                                        ingredients: ingredients,
                                        fastingPractice:
                                            fastingPractice,
                                        dietaryRestrictions:
                                            restrictions,
                                        cuisinePreference:
                                            cuisinePreference,
                                        mealType: mealType,
                                        recipeCount: recipeCount,
                                      );
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // BUILD SCREEN
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F2EA),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('chat_screen_title'),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _tr('chat_screen_subtitle'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEADBCE),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF542E13),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              const LanguageToggleButton(),
              IconButton(
                icon: const Icon(Icons.kitchen_outlined),
                tooltip: _tr('chat_pantry_title'),
                onPressed: _isLoading
                    ? null
                    : _openPantryRecipeSheet,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Active fasting context.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE1),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFEADBCE),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Color(0xFF8D4F28),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_tr('chat_fasting_context')}: '
                        '$_activeFastingRule',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF542E13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Chat messages.
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];

                    return Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                                  0.82,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? const Color(0xFF542E13)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(
                              message.isUser ? 18 : 4,
                            ),
                            bottomRight: Radius.circular(
                              message.isUser ? 4 : 18,
                            ),
                          ),
                          border: message.isUser
                              ? null
                              : Border.all(
                                  color: const Color(0xFFEADBCE),
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              _messageText(message),
                              style: TextStyle(
                                color: message.isUser
                                    ? Colors.white
                                    : const Color(0xFF1C1917),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                                '${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: message.isUser
                                      ? Colors.white.withOpacity(0.7)
                                      : const Color(0xFFA8A29E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Loading indicator.
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF542E13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _tr('chat_loading_message'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF78716C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Quick prompts.
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ActionChip(
                      label: Text(
                        _tr(_quickPromptKeys[index]),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF542E13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFEADBCE),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(
                                _quickPrompts[index],
                              ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Message input.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFEADBCE),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageCtrl,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.send,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1C1917),
                          ),
                          decoration: InputDecoration(
                            hintText: _tr('chat_input_hint'),
                            hintStyle: const TextStyle(
                              color: Color(0xFFA8A29E),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F3EC),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFFEADBCE),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFFEADBCE),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFF542E13),
                                width: 1.6,
                              ),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF542E13),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: _tr('chat_send_message'),
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _sendMessage(
                                    _messageCtrl.text,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

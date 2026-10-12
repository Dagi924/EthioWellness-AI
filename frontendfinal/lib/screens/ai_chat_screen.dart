import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

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

  final List<String> _pantryItems = [
    'Teff Flour',
    'Shiro Powder',
    'Onion',
    'Berbere',
    'Garlic',
    'Lentils',
  ];

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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMessage = text.trim();

    _messageCtrl.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: userMessage,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiResult =
          await AiService.sendMessage(userMessage);

      if (!mounted) return;

      setState(() {
        _activeFastingRule =
            aiResult.fastingPractice.toUpperCase();

        _messages.add(
          ChatMessage(
            text: aiResult.reply,
            isUser: false,
            timestamp: DateTime.now(),
            fastingPractice: aiResult.fastingPractice,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: '${_tr('chat_connection_error')}: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
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

  void _openPantryRecipeSheet() {
    final selected = <String>{
      'Teff Flour',
      'Shiro Powder',
      'Onion',
    };

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
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5EBE1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.kitchen_rounded,
                                    color: Color(0xFF8D4F28),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _tr('chat_pantry_title'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: Color(0xFF542E13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF78716C),
                            ),
                            onPressed: () =>
                                Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tr('chat_pantry_description'),
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pantryItems.map((item) {
                          final isSelected =
                              selected.contains(item);

                          final translationKey =
                              _pantryTranslationKeys[item]!;

                          return FilterChip(
                            label: Text(
                              _tr(translationKey),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF542E13)
                                    : const Color(0xFF44403C),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor:
                                const Color(0xFFF5EBE1),
                            backgroundColor:
                                const Color(0xFFF8F3EC),
                            checkmarkColor:
                                const Color(0xFF542E13),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF542E13)
                                    : const Color(0xFFEADBCE),
                              ),
                            ),
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF542E13),
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _tr('chat_generate_recipes'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  final ingredients =
                                      selected.join(', ');

                                  Navigator.pop(sheetContext);

                                  _sendMessage(
                                    'Suggest 3 healthy Ethiopian '
                                    'fasting meals I can make right '
                                    'now using only: $ingredients.',
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

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
                onPressed: _openPantryRecipeSheet,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Active profile and fasting context.
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
                        margin:
                            const EdgeInsets.only(bottom: 12),
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
                              color:
                                  Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _messageText(message),
                              style: TextStyle(
                                color: message.isUser
                                    ? Colors.white
                                    : const Color(0xFF1C1917),
                                fontSize: 14,
                                height: 1.45,
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
                                      ? Colors.white
                                          .withOpacity(0.7)
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                  ),
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
                      Text(
                        _tr('chat_loading_message'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF78716C),
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
                      onPressed: () =>
                          _sendMessage(_quickPrompts[index]),
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
                          onPressed: () =>
                              _sendMessage(_messageCtrl.text),
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
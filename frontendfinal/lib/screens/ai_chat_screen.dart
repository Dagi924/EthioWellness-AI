import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? fastingPractice;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fastingPractice,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _activeFastingRule = 'Orthodox (ጾም)';

  final List<String> _quickPrompts = [
    'How do I balance iron during Orthodox fasting?',
    'What are the nutritional benefits of Red Teff vs White Teff?',
    'High-protein fasting meal ideas using Shiro and Telba.',
    'Am I on track with my calories & protein today?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Selam! I am EthioNutri AI, calibrated to your profile metrics, Ethiopian fasting calendar (ጾም), and FAO food tables. Ask me anything about your meals or daily nutrition!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = text.trim();
    _messageCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMsg,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final aiResult = await AiService.sendMessage(userMsg);
      if (mounted) {
        setState(() {
          _activeFastingRule = aiResult.fastingPractice.toUpperCase();
          _messages.add(ChatMessage(
            text: aiResult.reply,
            isUser: false,
            timestamp: DateTime.now(),
            fastingPractice: aiResult.fastingPractice,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error connecting to AI nutrition engine: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _openPantryRecipeSheet() {
    final List<String> pantry = ['Teff Flour', 'Shiro Powder', 'Onion', 'Berbere', 'Garlic', 'Lentils'];
    final selected = <String>{'Teff Flour', 'Shiro Powder', 'Onion'};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5EBE1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.kitchen_rounded, color: Color(0xFF8D4F28), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Pantry Smart Chef',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF78716C)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select ingredients currently in your kitchen for AI recipe generation:',
                style: TextStyle(color: Color(0xFF78716C), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pantry.map((item) {
                  final isSel = selected.contains(item);
                  return FilterChip(
                    label: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? const Color(0xFF542E13) : const Color(0xFF44403C),
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFFF5EBE1),
                    backgroundColor: const Color(0xFFF8F3EC),
                    checkmarkColor: const Color(0xFF542E13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? const Color(0xFF542E13) : const Color(0xFFEADBCE),
                      ),
                    ),
                    onSelected: (val) {
                      setSheetState(() {
                        if (val) {
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13), // Brown Action Button
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Generate Ethiopian Recipes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _sendMessage('Suggest 3 healthy Ethiopian fasting meals I can make right now using only: ${selected.join(', ')}.');
                      },
              ),
            ],
          ),
        ),
      ),
    );
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
              'EthioNutri AI Assistant',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
            Text(
              'Profile & FAO Food Table Synced',
              style: TextStyle(fontSize: 11, color: Color(0xFFEADBCE)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF542E13), // Warm Brown
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Pantry Chef',
            onPressed: _openPantryRecipeSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Profile Context Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF5EBE1),
              border: Border(bottom: BorderSide(color: Color(0xFFEADBCE))),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF8D4F28)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Grounded in your Profile & Fasting Schedule: $_activeFastingRule',
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

          // Chat Feed
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF542E13) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                      border: msg.isUser ? null : Border.all(color: const Color(0xFFEADBCE)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser ? Colors.white : const Color(0xFF1C1917),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: msg.isUser ? Colors.white.withOpacity(0.7) : const Color(0xFFA8A29E),
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

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF542E13)),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Consulting Ethiopian FAO Food Table...',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF78716C)),
                  ),
                ],
              ),
            ),

          // Quick Action Chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                return ActionChip(
                  label: Text(
                    _quickPrompts[idx],
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF542E13), fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFEADBCE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _sendMessage(_quickPrompts[idx]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEADBCE))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1C1917)),
                      decoration: InputDecoration(
                        hintText: 'Ask about Ethiopian foods, Teff, fasting...',
                        hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8F3EC), // Warm input fill
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF542E13), width: 1.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onSubmitted: (val) => _sendMessage(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF542E13), // Brown send button
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(_messageCtrl.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
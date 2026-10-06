import 'package:flutter/material.dart';
import '../services/api_client.dart';

class NutritionistScreen extends StatefulWidget {
  /// Optional nutritionist ID.
  ///
  /// If supplied, messages can be sent immediately.
  /// If null, the screen tries to discover the nutritionist
  /// from existing chat history.
  final String? nutritionistId;

  const NutritionistScreen({
    super.key,
    this.nutritionistId,
  });

  @override
  State<NutritionistScreen> createState() => _NutritionistScreenState();
}

class _NutritionistScreenState extends State<NutritionistScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  String? _nutritionistId;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _nutritionistId = widget.nutritionistId;
    _loadChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD CHAT HISTORY
  // ---------------------------------------------------------------------------
  Future<void> _loadChat() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.get('/supervision/chat/history');

      final messages = (response['messages'] as List?) ?? [];

      String? discoveredNutritionistId = _nutritionistId;

      // Discover nutritionist ID from previous messages.
      if (discoveredNutritionistId == null) {
        for (final message in messages) {
          final id = message['nutritionistId'];

          if (id != null && id.toString().isNotEmpty) {
            discoveredNutritionistId = id.toString();
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _nutritionistId = discoveredNutritionistId;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load nutritionist chat: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (_nutritionistId == null || _nutritionistId!.isEmpty) {
      _showNoNutritionistDialog();
      return;
    }

    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final response = await ApiClient.post(
        '/supervision/chat/send',
        {
          'nutritionistId': _nutritionistId,
          'message': text,
        },
      );

      final sentMessage = response['chatMessage'];

      _messageController.clear();

      if (mounted && sentMessage != null) {
        setState(() {
          _messages.add(sentMessage);
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SCROLL
  // ---------------------------------------------------------------------------
 void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  });
}

  // ---------------------------------------------------------------------------
  // NO NUTRITIONIST DIALOG
  // ---------------------------------------------------------------------------
  void _showNoNutritionistDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xFF8D4F28),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Nutritionist Required',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You do not have an active nutritionist assigned yet. '
            'Once a nutritionist is assigned or you book a consultation, '
            'you will be able to message them directly here.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF57534E),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FORMAT DATE
  // ---------------------------------------------------------------------------
  String _formatMessageTime(dynamic value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return '';
    }

    final local = parsed.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ---------------------------------------------------------------------------
  // MESSAGE BUBBLE
  // ---------------------------------------------------------------------------
  Widget _buildMessageBubble(dynamic message) {
    final senderRole = (message['senderRole'] ?? 'user').toString();
    final isUser = senderRole == 'user';
    final text = (message['message'] ?? '').toString();
    final time = _formatMessageTime(message['sentAt']);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 50 : 0,
          right: isUser ? 0 : 50,
          bottom: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF542E13) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: const Color(0xFFEADBCE),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF1C1917),
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isUser
                      ? Colors.white.withOpacity(0.75)
                      : const Color(0xFF78716C),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY CHAT
  // ---------------------------------------------------------------------------
  Widget _buildEmptyChat() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: Color(0xFF8D4F28),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nutritionist Supervision',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chat directly with your certified clinical dietitian about fasting diets, meal adjustments, iron balance, or clinical concerns.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF78716C),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF542E13),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your clinical dietitian reviews your daily nutrient logs to provide authentic, culturally grounded dietary advice.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF542E13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutritionist Chat',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Clinical nutrition supervision',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFEADBCE),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh conversation',
            onPressed: _loadChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------------
          // CONNECTION / STATUS HEADER
          // ---------------------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEADBCE),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _nutritionistId != null
                        ? const Color(0xFF166534)
                        : const Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nutritionistId != null
                        ? 'Nutritionist consultation channel active'
                        : 'No nutritionist assigned yet',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _nutritionistId != null
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------
          // CHAT
          // ---------------------------------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF542E13),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : RefreshIndicator(
                        onRefresh: _loadChat,
                        color: const Color(0xFF542E13),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            18,
                            16,
                            18,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(
                              _messages[index],
                            );
                          },
                        ),
                      ),
          ),

          // ---------------------------------------------------------------
          // MESSAGE INPUT
          // ---------------------------------------------------------------
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFEADBCE),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2EA),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFEADBCE),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        enabled: _nutritionistId != null && !_isSending,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1C1917),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message your nutritionist...',
                          hintStyle: TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
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
                      onPressed: _nutritionistId == null || _isSending
                          ? null
                          : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 19,
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
  }
}

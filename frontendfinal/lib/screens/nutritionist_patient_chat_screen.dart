import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_localization.dart';

class NutritionistPatientChatScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const NutritionistPatientChatScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<NutritionistPatientChatScreen> createState() =>
      _NutritionistPatientChatScreenState();
}

class _NutritionistPatientChatScreenState
    extends State<NutritionistPatientChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController =
      ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  static const Color primaryBrown = Color(0xFF7A3E1D);
  static const Color darkBrown = Color(0xFF4A2411);
  static const Color lightBrown = Color(0xFFF3EDE4);
  static const Color lightBrownAccent = Color(0xFFE7DDD1);
  static const Color background = Color(0xFFF8F4EE);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF2C1810);
  static const Color textMuted = Color(0xFF7C6D65);
  static const Color textLight = Color(0xFFEADBCE);
  static const Color borderColor = Color(0xFFE7DDD1);

  String _t(String key) =>
      AppLocalization.instance.tr(key);

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD CONVERSATION HISTORY
  // ------------------------------------------------------------

  Future<void> _loadMessages() async {
    try {
      final response = await ApiClient.get(
        '/supervision/dietitian/patients/'
        '${widget.patientId}/messages',
      );

      if (!mounted) return;

      setState(() {
        _messages = (response['messages'] as List?) ?? [];
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showError(
        '${_t('chat_load_failed')}: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // SEND MESSAGE
  // ------------------------------------------------------------

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final response = await ApiClient.post(
        '/supervision/dietitian/patients/'
        '${widget.patientId}/messages',
        {
          'message': message,
        },
      );

      if (!mounted) return;

      _messageController.clear();

      final newMessage = response['message'];

      if (newMessage != null) {
        setState(() {
          _messages.add(newMessage);
        });
      } else {
        await _loadMessages();
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      _showError(
        '${_t('chat_send_failed')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SCROLL
  // ------------------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------
  // INITIALS
  // ------------------------------------------------------------

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'P';

    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ------------------------------------------------------------
  // BUILD — REACT TO LANGUAGE TOGGLE
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: _t('chat_back'),
        ),
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryBrown,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFA6633E),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(widget.patientName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: darkBrown,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _t('clinical_consultation_subtitle'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
            tooltip: _t('refresh_conversation'),
            onPressed: _isLoading ? null : _loadMessages,
            style: IconButton.styleFrom(
              backgroundColor: primaryBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Column(
        children: [
          // Confidentiality banner.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: lightBrown,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _t('clinical_chat_confidentiality'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: darkBrown,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _t('loading_consultation_history'),
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyConversation()
                    : _buildMessages(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY CONVERSATION
  // ------------------------------------------------------------

  Widget _buildEmptyConversation() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: textDark.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightBrown,
                  shape: BoxShape.circle,
                  border: Border.all(color: lightBrownAccent),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  size: 36,
                  color: primaryBrown,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_t('start_consultation_with')} '
                '${widget.patientName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('consultation_empty_description'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _quickTipChip(_t('tip_anemia_iron')),
                  _quickTipChip(_t('tip_orthodox_fasting')),
                  _quickTipChip(_t('tip_shiro_protein')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickTipChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: lightBrown,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: darkBrown,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MESSAGE LIST
  // ------------------------------------------------------------

  Widget _buildMessages() {
    return RefreshIndicator(
      color: darkBrown,
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return _buildMessageBubble(_messages[index]);
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // MESSAGE BUBBLE
  // ------------------------------------------------------------

  Widget _buildMessageBubble(dynamic message) {
    final senderRole =
        (message['senderRole'] ?? message['role'] ?? '')
            .toString()
            .toLowerCase();

    final isNutritionist =
        senderRole == 'nutritionist' ||
        senderRole == 'dietitian';

    final text =
        (message['message'] ?? message['content'] ?? '').toString();

    final createdAt = DateTime.tryParse(
      (message['createdAt'] ?? '').toString(),
    )?.toLocal();

    final time = createdAt == null
        ? ''
        : '${createdAt.hour.toString().padLeft(2, '0')}:'
            '${createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isNutritionist
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        decoration: BoxDecoration(
          color: isNutritionist ? darkBrown : surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isNutritionist ? 16 : 4),
            bottomRight: Radius.circular(isNutritionist ? 4 : 16),
          ),
          border: isNutritionist
              ? null
              : Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isNutritionist
                  ? darkBrown.withOpacity(0.2)
                  : textDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isNutritionist
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isNutritionist)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.patientName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryBrown,
                  ),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: isNutritionist ? Colors.white : textDark,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isNutritionist ? textLight : textMuted,
                    ),
                  ),
                  if (isNutritionist) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 13,
                      color: textLight,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MESSAGE INPUT
  // ------------------------------------------------------------

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: surfaceWhite,
          border: Border(
            top: BorderSide(color: borderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: textDark.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: lightBrown,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: _t('clinical_message_hint'),
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: darkBrown,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: darkBrown.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: _t('send_message'),
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
    );
  }
}

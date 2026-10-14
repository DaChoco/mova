import 'package:flutter/material.dart';

import 'services/chat_service.dart' as chat;
import 'services/ride_chat_service.dart' as rideservice;
import 'services/auth_service.dart' as userservice;
import 'config/app_config.dart';

class MessageScreen extends StatefulWidget {
  final String rideId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;

  const MessageScreen({
    super.key,
    required this.rideId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController messageController = TextEditingController();

  late final chat.ChatService _chatService;
  late final rideservice.RideChatService _rideChatService;
  late final userservice.AuthService _authService;

  List<chat.Message> _messages = [];

  bool _loading = true;
  bool _sending = false;

  String? _error;

  String _displayName = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();

    _chatService = chat.ChatService();

    _authService = userservice.AuthService(baseUrl: AppConfig.backendBaseUrl);

    _rideChatService = rideservice.RideChatService(
      baseUrl: AppConfig.backendBaseUrl,
      getAccessToken: _authService.refreshAccessToken,
    );

    _displayName = widget.otherUserName;

    _loadOtherUser();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _connectToRideChat();
    await _loadMessages();
  }

  @override
  void dispose() {
    _rideChatService.disconnect();
    messageController.dispose();
    super.dispose();
  }

  void _addMessageIfNew(chat.Message message) {
    if (!mounted) return;

    setState(() {
      final alreadyExists = _messages.any(
        (existing) => existing.id == message.id,
      );

      if (!alreadyExists) {
        _messages.add(message);
      }
    });
  }

  void _markMessageReadLocally(String messageId) {
    if (!mounted) return;

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1 || _messages[index].isRead) return;

    setState(() {
      _messages[index] = _messages[index].copyWith(isRead: true);
    });
  }

  Future<void> _connectToRideChat() async {
    try {
      await _rideChatService.connect(
        rideId: widget.rideId,
        onMessage: (message) {
          _addMessageIfNew(message);
        },
        onMessageRead: _markMessageReadLocally,
      );
    } catch (e) {
      debugPrint('SignalR connection failed: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await _chatService.getMessages(widget.rideId);

      if (!mounted) return;
      for (final message in messages) {
        final isIncoming = message.senderId != widget.currentUserId;

        if (isIncoming && !message.isRead) {
          try {
            await _chatService.markMessageAsRead(widget.rideId, message.id);
          } catch (e) {
            debugPrint('Could not mark message ${message.id} as read: $e');
          }
        }
      }

      setState(() {
        final merged = <String, chat.Message>{
          for (final message in messages) message.id: message,
          for (final message in _messages) message.id: message,
        };

        _messages = merged.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });

      // Mark incoming messages as read on the backend.
      // ChatService notifies the Chats and Home screens when successful.
      await _chatService.markRideRead(widget.rideId);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load messages';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadOtherUser() async {
    try {
      final user = await _chatService.getUser(widget.otherUserId);

      if (!mounted) return;

      final firstName = user['firstName']?.toString() ?? '';

      final surname = user['surname']?.toString() ?? '';

      final fullName = '$firstName $surname'.trim();

      setState(() {
        if (fullName.isNotEmpty) {
          _displayName = fullName;
        }

        final profileIcon = user['profileIcon']?.toString().trim();

        setState(() {
          if (fullName.isNotEmpty) {
            _displayName = fullName;
          }

          if (profileIcon != null && profileIcon.isNotEmpty) {
            _profileImageUrl = profileIcon.startsWith('http')
                ? profileIcon
                : 'https://zeedqugdftxrbscmhgmq.supabase.co/storage/v1/object/public/user-icons/$profileIcon';
          } else {
            _profileImageUrl = null;
          }
        });
      });
    } catch (e) {
      // Keep the name passed into the screen.
      // The default person icon will be displayed
      // if the profile picture cannot be loaded.
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    messageController.clear();

    setState(() {
      _sending = true;
    });

    try {
      final sentMessage = await _chatService.sendMessage(widget.rideId, text);

      if (!mounted) return;

      _addMessageIfNew(sentMessage);
    } catch (e) {
      if (!mounted) return;

      messageController.text = text;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message failed to send')));
    } finally {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });
    }
  }

  Widget _profileAvatar() {
    final imageUrl = _profileImageUrl?.trim();

    if (imageUrl == null ||
        imageUrl.isEmpty ||
        !(imageUrl.startsWith('https://') || imageUrl.startsWith('http://'))) {
      return const CircleAvatar(radius: 20, child: Icon(Icons.person));
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Failed to load chat profile image: $error');

              return const Center(child: Icon(Icons.person));
            },
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(chat.Message message) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isMe = message.senderId == widget.currentUserId;

    const radius = Radius.circular(18);

    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF254D42)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: isMe ? radius : Radius.zero,
            bottomRight: isMe ? Radius.zero : radius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 5),

            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? colorScheme.onPrimary.withValues(alpha: 0.7)
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),

                if (isMe)
                  Icon(
                    Icons.done_all,
                    size: 18,
                    color: message.isRead
                        ? const Color(0xFF40C4FF)
                        : colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadMessages, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];

        return _messageBubble(message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _profileAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _messageList()),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(Icons.send, color: colorScheme.onPrimary),
                      onPressed: _sending ? null : _send,
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

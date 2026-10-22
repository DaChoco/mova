import 'package:flutter/material.dart';

import 'services/chat_service.dart' as chat;
import 'services/ride_chat_service.dart' as rideservice;
import 'services/auth_service.dart' as userservice;
import 'config/app_config.dart';

// One-to-one conversation screen for a specific ride. Loads message history,
// listens for new messages in real time (SignalR) and lets the user reply.
class MessageScreen extends StatefulWidget {
  // The ride this conversation belongs to.
  final String rideId;

  // The logged-in user, used to tell sent messages from received ones.
  final String currentUserId;

  // The person being chatted with.
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
  // Controller for the message input box.
  final TextEditingController messageController = TextEditingController();

  // Services: REST chat calls, real-time ride chat, and user/auth calls.
  late final chat.ChatService _chatService;
  late final rideservice.RideChatService _rideChatService;
  late final userservice.AuthService _authService;

  // Messages currently shown, oldest first.
  List<chat.Message> _messages = [];

  // True while the message history is loading.
  bool _loading = true;

  // True while a message is being sent (disables the send button).
  bool _sending = false;

  // Error text shown if the history can't be loaded.
  String? _error;

  // Name and picture shown in the app bar.
  String _displayName = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();

    _chatService = chat.ChatService();

    _authService = userservice.AuthService(baseUrl: AppConfig.backendBaseUrl);

    // The real-time service asks the auth service for a fresh access token.
    _rideChatService = rideservice.RideChatService(
      baseUrl: AppConfig.backendBaseUrl,
      getAccessToken: _authService.refreshAccessToken,
    );

    // Start with the name passed in; replaced by the full name once loaded.
    _displayName = widget.otherUserName;

    _loadOtherUser();
    _initializeChat();
  }

  // Connects to the real-time chat first, then loads the message history.
  Future<void> _initializeChat() async {
    await _connectToRideChat();
    await _loadMessages();
  }

  @override
  void dispose() {
    // Close the real-time connection and release the text controller.
    _rideChatService.disconnect();
    messageController.dispose();
    super.dispose();
  }

  // Adds a message to the list unless one with the same ID is already there
  // (prevents duplicates when a message arrives via more than one route).
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

  // Marks a message as read in the local list (used to show the blue ticks).
  void _markMessageReadLocally(String messageId) {
    if (!mounted) return;

    final index = _messages.indexWhere((m) => m.id == messageId);
    // Ignore unknown messages and ones already marked as read.
    if (index == -1 || _messages[index].isRead) return;

    setState(() {
      _messages[index] = _messages[index].copyWith(isRead: true);
    });
  }

  // Opens the real-time connection for this ride's chat.
  Future<void> _connectToRideChat() async {
    try {
      await _rideChatService.connect(
        rideId: widget.rideId,
        // Called whenever a new message arrives.
        onMessage: (message) {
          _addMessageIfNew(message);
        },
        // Called when the other user reads one of our messages.
        onMessageRead: _markMessageReadLocally,
      );
    } catch (e) {
      // The chat still works through normal requests if this fails.
      debugPrint('SignalR connection failed: $e');
    }
  }

  // Loads the message history, marks incoming messages as read and merges
  // them with any messages that already arrived in real time.
  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await _chatService.getMessages(widget.rideId);

      if (!mounted) return;

      // Mark each unread incoming message as read, one at a time.
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
        // Merge by ID so duplicates collapse into one. Messages already in
        // _messages come last, so they win over the freshly loaded copies.
        final merged = <String, chat.Message>{
          for (final message in messages) message.id: message,
          for (final message in _messages) message.id: message,
        };

        // Keep the list sorted oldest to newest.
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
      // Hide the loading spinner whether it succeeded or failed.
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Loads the other user's full name and profile picture for the app bar.
  Future<void> _loadOtherUser() async {
    try {
      final user = await _chatService.getUser(widget.otherUserId);

      if (!mounted) return;

      final firstName = user['firstName']?.toString() ?? '';

      final surname = user['surname']?.toString() ?? '';

      final fullName = '$firstName $surname'.trim();

      setState(() {
        // Only replace the name if the backend returned one.
        if (fullName.isNotEmpty) {
          _displayName = fullName;
        }

        final profileIcon = user['profileIcon']?.toString().trim();

        // Note: this setState is nested inside the one above.
        setState(() {
          if (fullName.isNotEmpty) {
            _displayName = fullName;
          }

          if (profileIcon != null && profileIcon.isNotEmpty) {
            // Use full URLs as they are; otherwise build the Supabase
            // storage URL from the file name.
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

  // Sends the typed message and adds it to the list.
  Future<void> _send() async {
    final text = messageController.text.trim();

    // Ignore empty messages and double taps while one is already sending.
    if (text.isEmpty || _sending) {
      return;
    }

    // Clear the box straight away so it feels instant.
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

      // Put the text back so the user doesn't lose what they typed.
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

  // Round profile picture shown in the app bar. Falls back to a default
  // person icon if there is no valid image URL or the image fails to load.
  Widget _profileAvatar() {
    final imageUrl = _profileImageUrl?.trim();

    // Only accept complete http/https URLs.
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
            // If the image can't be displayed, show the default icon.
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Failed to load chat profile image: $error');

              return const Center(child: Icon(Icons.person));
            },
          ),
        ),
      ),
    );
  }

  // Builds one chat bubble. Our messages sit on the right in the primary
  // colour; the other person's sit on the left.
  Widget _messageBubble(chat.Message message) {
    final colorScheme = Theme.of(context).colorScheme;

    // True when the logged-in user sent this message.
    final bool isMe = message.senderId == widget.currentUserId;

    const radius = Radius.circular(18);

    // Time sent, formatted as HH:mm.
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
          // Own messages use the primary colour; received messages use a
          // dark green in dark mode or a light grey in light mode.
          color: isMe
              ? colorScheme.primary
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF254D42)
              : colorScheme.surfaceContainerHighest,
          // Square off the bottom corner nearest the sender to form the
          // bubble "tail".
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
            // Message text.
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 5),

            // Time on the left, read receipt on the right.
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

                // Double tick on our own messages: blue once read.
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

  // The scrolling list of messages, or a loading / error / empty state.
  Widget _messageList() {
    // Loading state.
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state with a retry button.
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

    // Empty state.
    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(fontSize: 16)),
      );
    }

    // `reverse: true` keeps the newest message at the bottom, so the index
    // is flipped to read the list from the end.
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
      // App bar shows a back button, the other user's avatar and name.
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
          // Messages fill all the space above the input bar.
          Expanded(child: _messageList()),

          // Input bar. SafeArea (bottom only) keeps it clear of the
          // phone's home indicator.
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
                  // Text box that grows from 1 up to 4 lines.
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

                  // Circular send button; shows a spinner while sending.
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

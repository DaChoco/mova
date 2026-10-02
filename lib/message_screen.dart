import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/auth_service.dart';

class Message {
  final String id;
  final String senderId;
  final String senderType;
  final String text;
  final DateTime sentAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.text,
    required this.sentAt,
    required this.isRead,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['messageId'].toString(),
      senderId: json['senderId'].toString(),
      senderType: json['senderType']?.toString() ?? '',
      text: json['message']?.toString() ?? '',
      sentAt: DateTime.parse(json['sentAt'].toString()),
      isRead: json['isRead'] ?? false,
    );
  }
}

class ChatService {
  static const String baseUrl = 'http://26.223.171.250:80';

  final AuthService authService;

  ChatService({required this.authService});

  Future<Map<String, String>> _headers() async {
    final token = await authService.storage.read(key: 'jwt');

    if (token == null) {
      throw Exception('No login session found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Message>> getMessages(String rideId) async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('$baseUrl/api/rides/$rideId/messages'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired');
    }

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception('Failed to load messages');
    }

    final List<dynamic> messages = data['messages'] ?? [];

    return messages
        .map((message) => Message.fromJson(message as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage(String rideId, String text) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/$rideId/messages'),
      headers: headers,
      body: jsonEncode({'message': text}),
    );

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired');
    }

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception('Failed to send message');
    }

    return Message.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('$baseUrl/api/user/$userId'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired');
    }

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception('Failed to load user');
    }

    return data['user'] as Map<String, dynamic>;
  }
}

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

  late final AuthService _authService;
  late final ChatService _chatService;

  List<Message> _messages = [];

  bool _loading = true;
  bool _sending = false;

  String? _error;

  String _displayName = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();

    _authService = AuthService(baseUrl: ChatService.baseUrl);

    _chatService = ChatService(authService: _authService);

    _displayName = widget.otherUserName;

    _loadMessages();
    _loadOtherUser();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await _chatService.getMessages(widget.rideId);

      if (!mounted) return;

      setState(() {
        _messages = messages;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load messages';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
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

        _profileImageUrl = user['profileIcon']?.toString();
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

      setState(() {
        _messages.add(sentMessage);
      });
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
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(_profileImageUrl!),
      );
    }

    return const CircleAvatar(radius: 20, child: Icon(Icons.person));
  }

  Widget _messageBubble(Message message) {
    final colorScheme = Theme.of(context).colorScheme;

    final bool isMe = message.senderId == widget.currentUserId;

    const radius = Radius.circular(18);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: isMe ? radius : Radius.zero,
            bottomRight: isMe ? Radius.zero : radius,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 15,
            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
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

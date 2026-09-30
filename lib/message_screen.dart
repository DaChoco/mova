import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  // MongoDB documents use "_id"
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['_id'],
    senderId: json['senderId'],
    text: json['text'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class ChatService {
  // 10.0.2.2 = your PC's localhost from the Android emulator.
  // Use your PC's LAN IP on a real phone, or the hosted URL later.
  static const baseUrl = 'http://10.0.2.2:3000/api';

  Future<List<Message>> getMessages(String conversationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
    );
    if (res.statusCode != 200) throw Exception('Failed to load messages');
    return (jsonDecode(res.body) as List)
        .map((m) => Message.fromJson(m))
        .toList();
  }

  Future<Message> sendMessage(
    String conversationId,
    String senderId,
    String text,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'senderId': senderId, 'text': text}),
    );
    if (res.statusCode != 201) throw Exception('Failed to send message');
    return Message.fromJson(jsonDecode(res.body));
  }
}

class MessageScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String otherUserName;

  const MessageScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final messageController = TextEditingController();
  final _service = ChatService();
  List<Message> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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
      final msgs = await _service.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() => _messages = msgs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load messages');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    try {
      final sent = await _service.sendMessage(
        widget.conversationId,
        widget.currentUserId,
        text,
      );
      if (!mounted) return;
      setState(() => _messages.add(sent));
    } catch (e) {
      if (!mounted) return;
      messageController.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message failed to send')));
    }
  }

  Widget _bubble(Message msg) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMe = msg.senderId == widget.currentUserId;
    const r = Radius.circular(18);

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
            topLeft: r,
            topRight: r,
            bottomLeft: isMe ? r : Radius.zero,
            bottomRight: isMe ? Radius.zero : r,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 15,
            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _messageList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _loadMessages, child: const Text('Retry')),
          ],
        ),
      );
    }
    // reverse: true keeps the newest message at the bottom
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[_messages.length - 1 - i]),
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
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(radius: 20, child: Icon(Icons.person)),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                      icon: Icon(Icons.send, color: colorScheme.onPrimary),
                      onPressed: _send,
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

import 'package:flutter/material.dart';

import 'message_screen.dart';
import 'services/chat_service.dart' as chat;

class ChatsScreen extends StatelessWidget {
  final String currentUserId;

  const ChatsScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ChatList(currentUserId: currentUserId),
    );
  }
}

class ChatList extends StatefulWidget {
  final String currentUserId;
  final int? limit;

  const ChatList({super.key, required this.currentUserId, this.limit});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final chat.ChatService _service = chat.ChatService();

  late Future<List<Conversation>> _chats;

  @override
  void initState() {
    super.initState();
    _chats = _service.getConversations();
    chatsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    chatsChanged.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _chats = _service.getConversations();
      });
    }
  }

  String _time(DateTime t) {
    final now = DateTime.now();

    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(t.year, t.month, t.day)).inDays;

    if (days == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    return days == 1 ? 'Yesterday' : '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Conversation>>(
      future: _chats,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load chats'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }

        final all = snap.data ?? [];

        if (all.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 56,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No chats yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find a driver or passenger to start chatting',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        final chats = widget.limit == null
            ? all
            : all.take(widget.limit!).toList();

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _chats.catchError((_) => <Conversation>[]);
          },
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 84),
            itemBuilder: (context, i) {
              final c = chats[i];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.person),
                ),
                title: Text(
                  c.otherUserName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  c.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Text(
                  _time(c.updatedAt),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageScreen(
                        rideId: c.rideId,
                        currentUserId: widget.currentUserId,
                        otherUserId: c.otherUserId,
                        otherUserName: c.otherUserName,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

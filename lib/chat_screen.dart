import 'package:flutter/material.dart';

import 'message_screen.dart';
import 'services/chat_service.dart' as chat;

// Small count bubble. Shows nothing when there are no unread messages.
// Also used on the home screen's Messages button.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // No `alignment` on the Container: it would make the badge expand to the
    // full width available, which breaks ListTile's trailing slot.
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

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

  late Future<List<chat.Conversation>> _chats;

  // Cache profile image URLs to avoid repeatedly requesting the same user.
  final Map<int, Future<String?>> _profileImageCache = {};

  @override
  void initState() {
    super.initState();

    _chats = _service.getConversations();

    chat.chatsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    chat.chatsChanged.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _chats = _service.getConversations();
    });
  }

  String? _profileImageUrl(String? path) {
    final value = path?.trim();

    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }

    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }

    return 'https://zeedqugdftxrbscmhgmq.supabase.co'
        '/storage/v1/object/public/user-icons/$value';
  }

  Future<String?> _loadProfileImage(int userId) async {
    try {
      final user = await _service.getUser(userId.toString());

      return _profileImageUrl(user['profileIcon']?.toString());
    } catch (e) {
      debugPrint('Could not load profile image for user $userId: $e');

      return null;
    }
  }

  Future<String?> _getProfileImage(int userId) {
    return _profileImageCache.putIfAbsent(
      userId,
      () => _loadProfileImage(userId),
    );
  }

  String _time(DateTime t) {
    final now = DateTime.now();

    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(t.year, t.month, t.day)).inDays;

    if (days == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    }

    return days == 1 ? 'Yesterday' : '${t.day}/${t.month}/${t.year}';
  }

  Widget _chatAvatar(int userId) {
    return FutureBuilder<String?>(
      future: _getProfileImage(userId),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        if (imageUrl == null || imageUrl.isEmpty) {
          return const CircleAvatar(radius: 26, child: Icon(Icons.person));
        }

        return CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey.shade300,
          child: ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to display chat profile image: $error');

                  return const Center(child: Icon(Icons.person));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<chat.Conversation>>(
      future: _chats,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          debugPrint('[ChatList] Failed to load chats');
          debugPrint('Error: ${snap.error}');
          debugPrint('Stack trace:\n${snap.stackTrace}');

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
            setState(() {
              _chats = _service.getConversations();
              _profileImageCache.clear();
            });

            await _chats.catchError((_) => <chat.Conversation>[]);
          },
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) {
              return const Divider(height: 1, indent: 84);
            },
            itemBuilder: (context, i) {
              final c = chats[i];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),

                leading: _chatAvatar(c.otherUserId),

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

                // Time, with the unread count underneath
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _time(c.updatedAt),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (c.unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      UnreadBadge(count: c.unreadCount),
                    ],
                  ],
                ),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageScreen(
                        rideId: c.rideId,
                        currentUserId: widget.currentUserId,
                        otherUserId: c.otherUserId.toString(),
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

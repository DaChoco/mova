import 'package:flutter/material.dart';

import 'message_screen.dart';
import 'services/chat_service.dart' as chat;

// Small count bubble. Shows nothing when there are no unread messages.
// Also used on the home screen's Messages button.
class UnreadBadge extends StatelessWidget {
  // Number of unread messages to display.
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    // Render nothing at all when there is nothing unread.
    if (count <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // No `alignment` on the Container: it would make the badge expand to the
    // full width available, which breaks ListTile's trailing slot.
    return Container(
      // Minimum size keeps single digits looking like a circle.
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        // Shrink-wrap the centre so the badge only takes the space it needs.
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          // Cap very large counts at "99+".
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

// Full-page screen that wraps the chat list in a Scaffold with an app bar.
class ChatsScreen extends StatelessWidget {
  // ID of the logged-in user, passed on to the message screen.
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

// The list of conversations. Kept separate from ChatsScreen so it can be
// reused elsewhere (the optional [limit] caps how many chats are shown).
class ChatList extends StatefulWidget {
  final String currentUserId;

  // Optional maximum number of conversations to display.
  final int? limit;

  const ChatList({super.key, required this.currentUserId, this.limit});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final chat.ChatService _service = chat.ChatService();

  // The in-flight or completed request for the user's conversations.
  late Future<List<chat.Conversation>> _chats;

  // Cache profile image URLs to avoid repeatedly requesting the same user.
  final Map<int, Future<String?>> _profileImageCache = {};

  @override
  void initState() {
    super.initState();

    // Load the conversations when the widget is first created.
    _chats = _service.getConversations();

    // Reload whenever the chat service signals that chats have changed
    // (e.g. a new message arrived or messages were marked as read).
    chat.chatsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    // Stop listening to avoid calling _reload on a disposed widget.
    chat.chatsChanged.removeListener(_reload);
    super.dispose();
  }

  // Fetches the conversations again and rebuilds the list.
  void _reload() {
    if (!mounted) return;

    setState(() {
      _chats = _service.getConversations();
    });
  }

  // Turns the stored profile icon value into a full image URL.
  // Returns null when there is no usable value.
  String? _profileImageUrl(String? path) {
    final value = path?.trim();

    // Treat empty values and the literal string 'null' as "no image".
    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }

    // Already a complete URL, so use it as is.
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }

    // Otherwise it is a file name in the Supabase public storage bucket.
    return 'https://zeedqugdftxrbscmhgmq.supabase.co'
        '/storage/v1/object/public/user-icons/$value';
  }

  // Requests the user from the backend and returns their profile image URL.
  // Returns null if the request fails.
  Future<String?> _loadProfileImage(int userId) async {
    try {
      final user = await _service.getUser(userId.toString());

      return _profileImageUrl(user['profileIcon']?.toString());
    } catch (e) {
      debugPrint('Could not load profile image for user $userId: $e');

      return null;
    }
  }

  // Returns the cached image lookup for a user, creating it on first use.
  Future<String?> _getProfileImage(int userId) {
    return _profileImageCache.putIfAbsent(
      userId,
      () => _loadProfileImage(userId),
    );
  }

  // Formats a timestamp for the chat list:
  // today -> HH:mm, yesterday -> "Yesterday", older -> d/m/yyyy.
  String _time(DateTime t) {
    final now = DateTime.now();

    // Compare calendar days only, ignoring the time of day.
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

  // Builds the round avatar for a conversation, falling back to a person
  // icon while loading, when there is no image, or if the image fails.
  Widget _chatAvatar(int userId) {
    return FutureBuilder<String?>(
      future: _getProfileImage(userId),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        // No image yet (or none exists): show the default icon.
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
                // If the image can't be displayed, show the default icon.
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
        // Loading state.
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state: log the details and offer a retry button.
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

        // Empty state: the user has no conversations yet.
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

        // Apply the optional limit on how many chats are shown.
        final chats = widget.limit == null
            ? all
            : all.take(widget.limit!).toList();

        // Pull-to-refresh reloads the chats and clears the image cache.
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _chats = _service.getConversations();
              _profileImageCache.clear();
            });

            // Wait for the reload to finish, ignoring any error here
            // (the FutureBuilder above shows the error state).
            await _chats.catchError((_) => <chat.Conversation>[]);
          },
          child: ListView.separated(
            itemCount: chats.length,
            // Thin divider, indented so it starts after the avatar.
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

                // Other user's profile picture.
                leading: _chatAvatar(c.otherUserId),

                // Other user's name.
                title: Text(
                  c.otherUserName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Preview of the most recent message, limited to one line.
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
                    // Only show the badge when there are unread messages.
                    if (c.unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      UnreadBadge(count: c.unreadCount),
                    ],
                  ],
                ),

                // Open the conversation for this ride.
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

final _host = AppConfig.backendBaseUrl;

// Bumped whenever a message is sent or read so chat lists and badges reload
final ValueNotifier<int> chatsChanged = ValueNotifier<int>(0);

// Represents a single chat message and its read status.
class Message {
  final String id, senderId, text;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  // Creates a copy of this message, optionally changing its read status.
  Message copyWith({bool? isRead}) {
    return Message(
      id: id,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  // Creates a Message object from the fields returned by the backend.
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['messageId'],
    senderId: json['senderId'].toString(), // backend sends an int
    text: json['message'],
    createdAt: DateTime.parse(json['sentAt']).toLocal(),
    isRead: json['isRead'] == true,
  );
}

// Represents a chat conversation associated with a ride and another user.
class Conversation {
  final String rideId, otherUserName, lastMessage;
  final int otherUserId;
  final DateTime updatedAt;
  final int unreadCount;

  Conversation({
    required this.rideId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  // Creates a Conversation object from the backend's JSON response.
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    rideId: json['rideId'].toString(),
    otherUserId: (json['otherUserId'] as num?)?.toInt() ?? 0,
    otherUserName: json['otherUserName']?.toString() ?? 'Unknown',
    lastMessage: json['lastMessage']?.toString() ?? '',
    updatedAt: DateTime.parse(json['sentAt'] ?? json['lastMessageAt'])
        .toLocal(),
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  );
}

// Handles API requests related to chats, messages, and user details.
class ChatService {
  final _auth = AuthService(baseUrl: _host);
  final _storage = const FlutterSecureStorage();

  // Sends the JWT; on a 401 it refreshes the token and retries once
  Future<http.Response> _call(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    // Builds the headers used for authenticated JSON API requests.
    Map<String, String> headers(String? jwt) => {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };

    // Makes the request with the currently stored access token.
    var res = await request(headers(await _storage.read(key: 'jwt')));
    // If the token has expired, refresh it and retry the request once.
    if (res.statusCode == 401) {
      final jwt = await _auth.refreshAccessToken();
      if (jwt != null) res = await request(headers(jwt));
    }
    return res;
  }

  // Marks a specific message as read for the given ride.
  Future<void> markMessageAsRead(String rideId, String? messageId) async {
    // Sends a PATCH request to the endpoint for marking this message as read.
    final response = await _call(
      (headers) => http.patch(
        Uri.parse('$_host/api/rides/$rideId/messages/$messageId/read'),
        headers: headers,
      ),
    );

    // Stops processing if no message ID was supplied.
    if (messageId == null) {
      return;
    }

    // Updates the chat-change notifier when the request succeeds.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      chatsChanged.value++;
    } else {
      // Reports the response status and body when the request fails.
      throw Exception(
        'Failed to mark message as read: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  // Caches resolved user names to avoid repeated user-detail requests.
  final Map<int, String> _nameCache = {};

  // Gets a user's display name, using the supplied fallback if needed.
  Future<String> _nameFor(int userId, String fallback) async {
    if (userId == 0) return fallback;
    final cached = _nameCache[userId];
    if (cached != null) return cached;
    try {
      // Fetches the user details and combines the first name and surname.
      final user = await getUser(userId.toString());
      final first = user['firstName']?.toString() ?? '';
      final last = user['surname']?.toString() ?? '';
      final name = '$first $last'.trim();
      final resolved = name.isEmpty ? fallback : name;
      _nameCache[userId] = resolved;
      return resolved;
    } catch (e) {
      // Logs the error and returns the fallback name if lookup fails.
      debugPrint('getUser failed for $userId: $e');
      return fallback;
    }
  }

  // Retrieves conversations and resolves the display name of each participant.
  Future<List<Conversation>> getConversations() async {
    final res = await _call(
      (h) => http.get(Uri.parse('$_host/api/chats'), headers: h),
    );
    // Stops and reports an error if the backend request was unsuccessful.
    if (res.statusCode != 200) throw Exception('Failed to load chats');

    // Decodes the chat list and converts each entry into a Conversation.
    final convos = (jsonDecode(res.body)['chats'] as List)
        .map((c) => Conversation.fromJson(c))
        .toList();

    // Resolves participant names for all conversations asynchronously.
    return Future.wait(
      convos.map((c) async {
        final name = await _nameFor(c.otherUserId, c.otherUserName);
        return Conversation(
          rideId: c.rideId,
          otherUserId: c.otherUserId,
          otherUserName: name,
          lastMessage: c.lastMessage,
          updatedAt: c.updatedAt,
          unreadCount: c.unreadCount,
        );
      }),
    );
  }

  // NEW: total unread messages across all conversations (home badge).
  Future<int> getUnreadTotal() async {
    final chats = await getConversations();

    // Adds the unread-message counts from every conversation.
    return chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  // NEW: marks the other participants' messages in this ride as read.
  // Backend endpoint: PATCH /api/rides/{rideId}/messages/read

  Future<void> markRideRead(String rideId) async {
    try {
      // Sends a request to mark the ride's messages as read.
      final res = await _call(
        (h) => http.patch(
          Uri.parse('$_host/api/rides/$rideId/messages/read'),
          headers: h,
        ),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Refresh the Chats screen and Home unread badge.
        chatsChanged.value++;
      } else {
        // Logs the server response if the request does not succeed.
        debugPrint(
          'Failed to mark messages as read. '
          'Status: ${res.statusCode}, Response: ${res.body}',
        );
      }
    } catch (e) {
      // Logs unexpected errors without allowing them to escape this method.
      debugPrint('markRideRead failed for ride $rideId: $e');
    }
  }

  // Retrieves all messages associated with the specified ride.
  Future<List<Message>> getMessages(String rideId) async {
    final res = await _call(
      (h) =>
          http.get(Uri.parse('$_host/api/rides/$rideId/messages'), headers: h),
    );
    if (res.statusCode != 200) throw Exception('Failed to load messages');
    // Converts each returned JSON message into a Message object.
    return (jsonDecode(res.body)['messages'] as List)
        .map((m) => Message.fromJson(m))
        .toList();
  }

  // Sends a new message for the specified ride.
  Future<Message> sendMessage(String rideId, String text) async {
    final res = await _call(
      (h) => http.post(
        Uri.parse('$_host/api/rides/$rideId/messages'),
        headers: h,
        body: jsonEncode({'message': text}),
      ),
    );
    if (res.statusCode != 200) throw Exception('Failed to send message');
    // Notifies listeners that chat data may need to be refreshed.
    chatsChanged.value++;
    // Converts the server's returned message data into a Message object.
    return Message.fromJson(jsonDecode(res.body)['message']);
  }

  // Retrieves a user's profile data from the backend.
  Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await _call(
      (h) => http.get(Uri.parse('$_host/api/user/$userId'), headers: h),
    );

    // Throws an exception if the HTTP request did not succeed.
    if (res.statusCode != 200) {
      throw Exception('Failed to load user');
    }

    // Decodes the response body from JSON into a Dart object.
    final data = jsonDecode(res.body);

    // Checks the API's success flag before returning the user data.
    if (data['success'] != true) {
      throw Exception('Failed to load user');
    }

    // Returns the user object from the API response.
    return data['user'] as Map<String, dynamic>;
  }
}

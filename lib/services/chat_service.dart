import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

final _host = AppConfig.backendBaseUrl;

// Bumped whenever a message is sent or read so chat lists and badges reload
final ValueNotifier<int> chatsChanged = ValueNotifier<int>(0);

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

  Message copyWith({bool? isRead}) {
  return Message(
    id: id,
    senderId: senderId,
    text: text,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );
}

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['messageId'],
    senderId: json['senderId'].toString(), // backend sends an int
    text: json['message'],
    createdAt: DateTime.parse(json['sentAt']).toLocal(),
    isRead: json['isRead'] == true
  );
}

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

class ChatService {
  final _auth = AuthService(baseUrl: _host);
  final _storage = const FlutterSecureStorage();

  

  // Sends the JWT; on a 401 it refreshes the token and retries once
  Future<http.Response> _call(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    Map<String, String> headers(String? jwt) => {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };

    


    var res = await request(headers(await _storage.read(key: 'jwt')));
    if (res.statusCode == 401) {
      final jwt = await _auth.refreshAccessToken();
      if (jwt != null) res = await request(headers(jwt));
    }
    return res;
  }

  
  Future<void> markMessageAsRead(
  String rideId,
  String? messageId,
) async { 

  final response = await _call(
    (headers) => http.patch(
      Uri.parse(
        '$_host/api/rides/$rideId/messages/$messageId/read',
      ),
      headers: headers,
    ),
  );

  if (messageId == null){
    return;
  }

  if (response.statusCode >= 200 && response.statusCode < 300) {
    chatsChanged.value++;
  } else {
    throw Exception(
      'Failed to mark message as read: '
      '${response.statusCode} ${response.body}',
    );
  }
}


  

  final Map<int, String> _nameCache = {};

  Future<String> _nameFor(int userId, String fallback) async {
    if (userId == 0) return fallback;
    final cached = _nameCache[userId];
    if (cached != null) return cached;
    try {
      final user = await getUser(userId.toString());
      final first = user['firstName']?.toString() ?? '';
      final last = user['surname']?.toString() ?? '';
      final name = '$first $last'.trim();
      final resolved = name.isEmpty ? fallback : name;
      _nameCache[userId] = resolved;
      return resolved;
    } catch (e) {
      debugPrint('getUser failed for $userId: $e');
      return fallback;
    }
  }

  Future<List<Conversation>> getConversations() async {
    final res = await _call(
      (h) => http.get(Uri.parse('$_host/api/chats'), headers: h),
    );
    if (res.statusCode != 200) throw Exception('Failed to load chats');

    final convos = (jsonDecode(res.body)['chats'] as List)
        .map((c) => Conversation.fromJson(c))
        .toList();

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

    return chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  // NEW: marks the other participants' messages in this ride as read.
  // Backend endpoint: PATCH /api/rides/{rideId}/messages/read

  Future<void> markRideRead(String rideId) async {
    try {
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
        debugPrint(
          'Failed to mark messages as read. '
          'Status: ${res.statusCode}, Response: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('markRideRead failed for ride $rideId: $e');
    }
  }

  Future<List<Message>> getMessages(String rideId) async {
    final res = await _call(
      (h) =>
          http.get(Uri.parse('$_host/api/rides/$rideId/messages'), headers: h),
    );
    if (res.statusCode != 200) throw Exception('Failed to load messages');
    return (jsonDecode(res.body)['messages'] as List)
        .map((m) => Message.fromJson(m))
        .toList();
  }

  Future<Message> sendMessage(String rideId, String text) async {
    final res = await _call(
      (h) => http.post(
        Uri.parse('$_host/api/rides/$rideId/messages'),
        headers: h,
        body: jsonEncode({'message': text}),
      ),
    );
    if (res.statusCode != 200) throw Exception('Failed to send message');
    chatsChanged.value++;
    return Message.fromJson(jsonDecode(res.body)['message']);
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await _call(
      (h) => http.get(Uri.parse('$_host/api/user/$userId'), headers: h),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load user');
    }

    final data = jsonDecode(res.body);

    if (data['success'] != true) {
      throw Exception('Failed to load user');
    }

    return data['user'] as Map<String, dynamic>;
  }
}

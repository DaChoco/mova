import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

const _host = AppConfig.backendBaseUrl;

// Bumped whenever a message is sent so chat lists reload themselves
final ValueNotifier<int> chatsChanged = ValueNotifier<int>(0);

class Message {
  final String id, senderId, text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['messageId'],
    senderId: json['senderId'].toString(), // backend sends an int
    text: json['message'],
    createdAt: DateTime.parse(json['sentAt']).toLocal(),
  );
}

class Conversation {
  final String rideId, otherUserName, lastMessage;
  final int otherUserId;
  final DateTime updatedAt;

  Conversation({
    required this.rideId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    rideId: json['rideId'].toString(),
    otherUserId: (json['otherUserId'] as num?)?.toInt() ?? 0,
    otherUserName: json['otherUserName']?.toString() ?? 'Unknown',
    lastMessage: json['lastMessage']?.toString() ?? '',
    updatedAt: DateTime.parse(json['sentAt'] ?? json['lastMessageAt'])
        .toLocal(),
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
        );
      }),
    );
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

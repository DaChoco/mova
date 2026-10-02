import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const _host = 'http://26.223.171.250:80';

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
    rideId: json['rideId'],
    otherUserId: json['otherUserId'],
    otherUserName: json['otherUserName'],
    lastMessage: json['lastMessage'],
    updatedAt: DateTime.parse(json['sentAt']).toLocal(),
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

  Future<List<Conversation>> getConversations() async {
    final res = await _call(
      (h) => http.get(Uri.parse('$_host/api/chats'), headers: h),
    );
    if (res.statusCode != 200) throw Exception('Failed to load chats');
    return (jsonDecode(res.body)['chats'] as List)
        .map((c) => Conversation.fromJson(c))
        .toList();
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

  Future<Message> sendMessage(
    String rideId,
    int recipientId,
    String text,
  ) async {
    final res = await _call(
      (h) => http.post(
        Uri.parse('$_host/api/rides/$rideId/messages'),
        headers: h,
        body: jsonEncode({'message': text, 'recipientId': recipientId}),
      ),
    );
    if (res.statusCode != 200) throw Exception('Failed to send message');
    chatsChanged.value++;
    return Message.fromJson(jsonDecode(res.body)['message']);
  }
}


// MANAGES SIGNAL IR CONNECTION TO .NET
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter/foundation.dart';

import 'chat_service.dart';


class RideChatService {
  final String baseUrl;
  final Future<String?> Function() getAccessToken;
  

  HubConnection? _connection;

  RideChatService({
    required this.baseUrl,
    required this.getAccessToken,
  });

  Future<void> connect({
    required String rideId,
    required void Function(Message) onMessage,
    required void Function(String messageId) onMessageRead,
    
  }) async {
    
    // Avoid opening a duplicate connection.
    if (_connection?.state == HubConnectionState.Connected) {
      return;
    }

    final hubUrl = '$baseUrl/hubs/ride-chat';

    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async {
            final token = await getAccessToken();

            if (token == null || token.isEmpty) {
              throw Exception('No access token found. Please log in again.');
            }

            return token;
  },
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Register the listener before the connection.
    _connection!.on('ReceiveMessage', (arguments) {
      if (arguments == null || arguments.isEmpty) return;

      final payload = arguments.first;

      if (payload is! Map) return;

      final json = Map<String, dynamic>.from(payload);

      // Forward the incoming message to your chat UI.
      onMessage(Message.fromJson(json));
    });

    _connection!.on('MessageRead', (arguments) {
      if (arguments == null || arguments.isEmpty) return;

      final payload = arguments.first;
      if (payload is! Map) return;

      final messageId = payload['messageId']?.toString();
      if (messageId == null || messageId.isEmpty) return;
      });

    

    await _connection!.start();


    await _connection!.invoke(
      'JoinRide',
      args: <Object>[rideId],
    );
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;

    if (connection != null) {
      await connection.stop();
    }
  }
}

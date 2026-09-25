import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
class MessageService{

  final String baseurl;

  MessageService({
    required this.baseurl,
  });

// /api/rides/{rideId}/messages - GET

Future<List<MessageRecieved>> getMessages(String rideId) async {
    final url = Uri.parse(
      '$baseurl/api/rides/$rideId/messages',
    );

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);

      return jsonData
          .map(
            (json) => MessageRecieved.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    throw Exception(
      'Failed to load messages. '
      'Status code: ${response.statusCode}',
    );
  }

  /// POST /api/rides/{rideId}/messages
  Future<void> sendMessage({
    required String rideId,
    required String message,
  }) async {
    final url = Uri.parse(
      '$baseurl/api/rides/$rideId/messages',
    );

    final messageSent = MessageSent(
      message: message,
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        messageSent.toJson(),
      ),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        'Failed to send message. '
        'Status code: ${response.statusCode}',
      );
    }
  }


}
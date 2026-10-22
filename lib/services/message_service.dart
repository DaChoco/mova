// Provides functions for encoding and decoding JSON data.
import 'dart:convert';

// Imports the HTTP package for sending requests to the backend.
import 'package:http/http.dart' as http;

// Imports the message model classes used by this service.
import '../models/message.dart';

// Handles retrieving messages, sending messages, and updating read status.
class MessageService {
  // Stores the base URL of the backend API.
  final String baseurl;

  // Creates the service and requires the backend base URL.
  MessageService({required this.baseurl});

  // /api/rides/{rideId}/messages - GET

  // Retrieves all messages associated with a specific ride.
  Future<List<MessageRecieved>> getMessages(String rideId) async {
    // Builds the URL using the backend address and the ride ID.
    final url = Uri.parse('$baseurl/api/rides/$rideId/messages');

    // Sends a GET request to retrieve the messages.
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    // Checks whether the server returned a successful response.
    if (response.statusCode == 200) {
      // Converts the JSON response body into a list of dynamic values.
      final List<dynamic> jsonData = jsonDecode(response.body);

      // Converts each JSON item into a MessageRecieved object.
      return jsonData
          .map((json) => MessageRecieved.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // Throws an exception if the messages could not be retrieved.
    throw Exception(
      'Failed to load messages. '
      'Status code: ${response.statusCode}',
    );
  }

  /// POST /api/rides/{rideId}/messages
  // Sends a new message to the specified ride's conversation.
  Future<void> sendMessage({
    required String rideId,
    required String message,
  }) async {
    // Builds the URL for the ride's message endpoint.
    final url = Uri.parse('$baseurl/api/rides/$rideId/messages');

    // Creates a MessageSent object containing the message text.
    final messageSent = MessageSent(message: message);

    // Sends the message to the backend as a JSON POST request.
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(messageSent.toJson()),
    );

    // Checks whether the server returned an unsuccessful status code.
    if (response.statusCode != 200 && response.statusCode != 201) {
      // Reports an error if the message could not be sent.
      throw Exception(
        'Failed to send message. '
        'Status code: ${response.statusCode}',
      );
    }
  }

  /// PATCH /api/rides/{rideId}/messages/{messageId}/read
  // Marks a specific message as read.
  Future<void> markMessageAsRead({
    required String rideId,
    required String messageId,
  }) async {
    // Builds the URL for the selected message's read-status endpoint.
    final url = Uri.parse(
      '$baseurl/api/rides/$rideId/messages/$messageId/read',
    );

    // Sends a PATCH request to update the message's read status.
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    // Checks whether the server returned an accepted success status code.
    if (response.statusCode != 200 && response.statusCode != 204) {
      // Throws an exception if the read status could not be updated.
      throw Exception(
        'Failed to mark message as read. '
        'Status code: ${response.statusCode}',
      );
    }
  }
}

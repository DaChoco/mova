import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../models/auth.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  // Secure storage for JWT and refresh token
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'studentNumber': request.studentNumber,
        'password': request.password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Save tokens if the backend provides them
      if (data['jwt'] != null && data['refreshToken'] != null) {
        await _saveTokens(data['jwt'], data['refreshToken']);
      }

      return LoginResponse.fromJson(data);
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid student number or password');
    }

    throw Exception('Login failed. Server returned ${response.statusCode}');
  }

  Future<void> register(RegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'studentName': request.studentName,
        'studentSurname': request.studentSurname,
        'studentNumber': request.studentNumber,
        'password': request.password,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 409) {
      throw Exception('Student number is already registered');
    }

    throw Exception(
      'Registration failed. Server returned ${response.statusCode}',
    );
  }

  Future<void> _saveTokens(String jwt, String refreshToken) async {
    await storage.write(key: 'jwt', value: jwt);
    await storage.write(key: 'refreshToken', value: refreshToken);
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await storage.read(key: 'refreshToken');

    if (refreshToken == null) {
      return null;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await _saveTokens(data['jwt'], data['refreshToken']);

      return data['jwt'];
    }

    // Refresh token is expired or invalid.
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'refreshToken');

    return null;
  }

  Future<User> getUser() async {
    final jwt = await storage.read(key: 'jwt');

    if (jwt == null) {
      throw Exception('No login token found');
    }

    // JWT format: header.payload.signature
    final parts = jwt.split('.');

    if (parts.length != 3) {
      throw Exception('Invalid login token');
    }

    // Decode the JWT payload
    final payload = parts[1];

    final normalizedPayload = base64Url.normalize(payload);

    final payloadBytes = base64Url.decode(normalizedPayload);

    final payloadData = jsonDecode(utf8.decode(payloadBytes));

    // The backend puts the user ID in the "sub" claim.
    final userId = int.parse(payloadData['sub'].toString());

    final response = await http.get(
      Uri.parse('$baseUrl/api/user/$userId'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return User.fromJson(data['user']);
    }

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired');
    }

    throw Exception(
      'Failed to load user. Server returned ${response.statusCode}',
    );
  }

  // Uploads the user's profile picture to the backend.

  Future<String> uploadProfilePicture(XFile image) async {
    final token = await storage.read(key: 'jwt');

    if (token == null) {
      throw Exception('No login session found');
    }

    final bytes = await image.readAsBytes();

    // Determine the MIME type from the selected file.
    final fileName = image.name.toLowerCase();

    MediaType contentType;

    if (fileName.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (fileName.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      contentType = MediaType('image', 'jpeg');
    } else {
      throw Exception('Please select a JPEG, PNG or WEBP image.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/user/profile-picture'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    print('PROFILE UPLOAD STATUS: ${response.statusCode}');
    print('PROFILE UPLOAD RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final returnedUrl = data['url'] as String;

      // The backend currently returns:
      // /profilepicture/filename.jpg
      //
      // Convert it into a complete URL for Flutter.
      if (returnedUrl.startsWith('http')) {
        return returnedUrl;
      }

      return '$baseUrl$returnedUrl';
    }

    if (response.statusCode == 400) {
      throw Exception(data['message'] ?? 'Invalid profile picture.');
    }

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired.');
    }

    if (response.statusCode == 404) {
      throw Exception('User account could not be found.');
    }

    throw Exception(
      data['message'] ??
          'Profile picture upload failed. '
              'Server returned ${response.statusCode}.',
    );
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'refreshToken');
  }

  Future<void> changePassword(ChangePasswordRequest request) async {
    final token = await storage.read(key: 'jwt');

    if (token == null) {
      throw Exception('No login session found');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/user/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(request.toJson()),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    if (response.statusCode == 401) {
      throw Exception(data['message'] ?? 'Current password is incorrect.');
    }

    if (response.statusCode == 400) {
      throw Exception(data['message'] ?? 'Invalid password.');
    }

    if (response.statusCode == 404) {
      throw Exception('User account could not be found.');
    }

    throw Exception(
      data['message'] ??
          'Password change failed. Server returned ${response.statusCode}.',
    );
  }

  Future<void> updateDriverStatus({
    required int userId,
    required bool isDriver,
  }) async {
    final token = await storage.read(key: 'jwt');

    if (token == null) {
      throw Exception('No login session found');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/user/update/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'isDriver': isDriver}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    if (response.statusCode == 401) {
      throw Exception('Your login session has expired.');
    }

    throw Exception(
      data['message'] ??
          'Failed to update account role. '
              'Server returned ${response.statusCode}.',
    );
  }
}

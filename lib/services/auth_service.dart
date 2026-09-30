import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
}

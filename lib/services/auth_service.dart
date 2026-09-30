import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

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
}

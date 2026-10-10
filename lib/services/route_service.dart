import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mova/config/app_config.dart';

class RoadRoute {
  final double distanceKm;
  final double durationMinutes;

  // OSRM coordinates are [longitude, latitude].
  final List<List<double>> coordinates;

  const RoadRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.coordinates,
  });

  factory RoadRoute.fromJson(Map<String, dynamic> json) {
    final rawCoordinates = json['coordinates'] as List? ?? [];

    return RoadRoute(
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMinutes: (json['durationMinutes'] as num).toDouble(),
      coordinates: rawCoordinates.map<List<double>>((coordinate) {
        final pair = coordinate as List;

        return [(pair[0] as num).toDouble(), (pair[1] as num).toDouble()];
      }).toList(),
    );
  }
}

class RouteService {
  RouteService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<RoadRoute> getRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    final token = await _storage.read(key: 'jwt');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again to load the route.');
    }

    final baseUrl = AppConfig.backendBaseUrl.replaceFirst(RegExp(r'/+$'), '');

    final uri = Uri.parse('$baseUrl/api/routes').replace(
      queryParameters: {
        'startLat': startLat.toString(),
        'startLon': startLon.toString(),
        'endLat': endLat.toString(),
        'endLon': endLon.toString(),
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 503) {
      throw Exception('The routing service is currently unavailable.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Could not calculate route (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('The routing service returned an invalid response.');
    }

    return RoadRoute.fromJson(decoded);
  }
}

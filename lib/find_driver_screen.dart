import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'message_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';

class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  User? _currentUser;

  final List<_NearbyMatch> _matches = const [
    _NearbyMatch(
      userId: '2',
      rideId: 'ride-001',
      name: 'Lorem',
      distanceKm: 5.0,
      pickup: 'Bellville',
      destination: 'Eduvos',
      time: '08:00',
    ),
    _NearbyMatch(
      userId: '3',
      rideId: 'ride-002',
      name: 'Ipsum',
      distanceKm: 2.3,
      pickup: 'Durbanville',
      destination: 'Eduvos',
      time: '08:30',
    ),
    _NearbyMatch(
      userId: '4',
      rideId: 'ride-003',
      name: 'Dolor',
      distanceKm: 8.1,
      pickup: 'Goodwood',
      destination: 'Eduvos',
      time: '09:00',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getUser();

      if (!mounted) return;

      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load your user information.')),
      );
    }
  }

  void _openMessageScreen(_NearbyMatch match) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while your account is loaded.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          rideId: match.rideId,
          currentUserId: _currentUser!.userId.toString(),
          otherUserId: match.userId,
          otherUserName: match.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          _buildMap(),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildBackButton(context),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.20,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.20, 0.32, 0.80],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag handle
                    _buildDragHandle(context),

                    // Heading
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nearby Drivers',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: () {
                              // Filters will be added later
                            },
                          ),
                        ],
                      ),
                    ),

                    // Driver cards
                    ..._matches.map((match) => _buildMatchCard(context, match)),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildMap() {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-33.88, 18.63),
        zoom: 11,
      ),
      styleString: 'https://tiles.openfreemap.org/styles/bright',
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Center(
        child: Container(
          width: 45,
          height: 5,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, _NearbyMatch match) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Driver information
            Row(
              children: [
                const CircleAvatar(radius: 25, child: Icon(Icons.person)),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              match.pickup,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              match.destination,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '${match.distanceKm.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      match.time,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Message driver button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  _openMessageScreen(match);
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Message Driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyMatch {
  final String userId;
  final String rideId;
  final String name;
  final double distanceKm;
  final String pickup;
  final String destination;
  final String time;

  const _NearbyMatch({
    required this.userId,
    required this.rideId,
    required this.name,
    required this.distanceKm,
    required this.pickup,
    required this.destination,
    required this.time,
  });
}

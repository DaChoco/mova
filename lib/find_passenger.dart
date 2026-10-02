import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'message_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';

class FindPassengerScreen extends StatefulWidget {
  const FindPassengerScreen({super.key});

  @override
  State<FindPassengerScreen> createState() => _FindPassengerScreenState();
}

class _FindPassengerScreenState extends State<FindPassengerScreen> {
  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  User? _currentUser;

  final List<_NearbyPassenger> _passengers = const [
    _NearbyPassenger(
      userId: '5',
      rideId: 'ride-004',
      name: 'Sarah Smith',
      distanceKm: 3.2,
      pickup: 'Bellville',
      destination: 'Eduvos',
      time: '08:00',
    ),
    _NearbyPassenger(
      userId: '6',
      rideId: 'ride-005',
      name: 'Michael Jones',
      distanceKm: 4.7,
      pickup: 'Durbanville',
      destination: 'Eduvos',
      time: '08:30',
    ),
    _NearbyPassenger(
      userId: '7',
      rideId: 'ride-006',
      name: 'Emily Williams',
      distanceKm: 6.1,
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

  void _openMessageScreen(_NearbyPassenger passenger) {
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
          rideId: passenger.rideId,
          currentUserId: _currentUser!.userId.toString(),
          otherUserId: passenger.userId,
          otherUserName: passenger.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find a Passenger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.88, 18.63),
                zoom: 11,
              ),
              styleString: 'https://tiles.openfreemap.org/styles/bright',
            ),
          ),

          // Draggable passenger menu
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.25,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.25, 0.42, 0.85],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10, bottom: 5),
                      child: Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search destination...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Heading
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Passengers Looking for Rides',
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

                    // Passenger cards
                    ..._passengers.map(
                      (passenger) => _buildPassengerCard(context, passenger),
                    ),

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

  Widget _buildPassengerCard(BuildContext context, _NearbyPassenger passenger) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Passenger information
            Row(
              children: [
                const CircleAvatar(radius: 25, child: Icon(Icons.person)),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger.name,
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
                              passenger.pickup,
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
                              passenger.destination,
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
                        '${passenger.distanceKm.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time
                Column(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      passenger.time,
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

            // Message passenger
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  _openMessageScreen(passenger);
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Message Passenger'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyPassenger {
  final String userId;
  final String rideId;
  final String name;
  final double distanceKm;
  final String pickup;
  final String destination;
  final String time;

  const _NearbyPassenger({
    required this.userId,
    required this.rideId,
    required this.name,
    required this.distanceKm,
    required this.pickup,
    required this.destination,
    required this.time,
  });
}

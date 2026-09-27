import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  final List<_NearbyMatch> _matches = const [
    _NearbyMatch(
      name: 'Lorem',
      distanceKm: 5.0,
      pickup: 'Bellville',
      destination: 'Eduvos',
      time: '08:00',
    ),
    _NearbyMatch(
      name: 'Ipsum',
      distanceKm: 2.3,
      pickup: 'Durbanville',
      destination: 'Eduvos',
      time: '08:30',
    ),
    _NearbyMatch(
      name: 'Dolor',
      distanceKm: 8.1,
      pickup: 'Goodwood',
      destination: 'Eduvos',
      time: '09:00',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Map layer
          _buildMap(),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildBackButton(context),
            ),
          ),

          // Draggable bottom sheet
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
                      color: Colors.black.withOpacity(0.2),
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
            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
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

                      Text(
                        '${match.pickup} → ${match.destination}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
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

                Text(
                  match.time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  // Ride request functionality will be added later
                },
                child: const Text('View Driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyMatch {
  final String name;
  final double distanceKm;
  final String pickup;
  final String destination;
  final String time;

  const _NearbyMatch({
    required this.name,
    required this.distanceKm,
    required this.pickup,
    required this.destination,
    required this.time,
  });
}

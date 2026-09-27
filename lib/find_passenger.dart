import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class FindPassengerScreen extends StatelessWidget {
  const FindPassengerScreen({super.key});

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
          // Map - Using MapLibre
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),

                // IMPORTANT:
                // The whole menu is now controlled by the
                // DraggableScrollableSheet scroll controller.
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag handle area
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10, bottom: 5),
                      child: Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.4,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // Search section
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

                    // Passenger heading
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
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
                    _buildPassengerCard(
                      context,
                      name: 'Sarah Smith',
                      pickup: 'Bellville',
                      destination: 'Eduvos',
                      time: '08:00',
                    ),

                    _buildPassengerCard(
                      context,
                      name: 'Michael Jones',
                      pickup: 'Durbanville',
                      destination: 'Eduvos',
                      time: '08:30',
                    ),

                    _buildPassengerCard(
                      context,
                      name: 'Emily Williams',
                      pickup: 'Goodwood',
                      destination: 'Eduvos',
                      time: '09:00',
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

  Widget _buildPassengerCard(
    BuildContext context, {
    required String name,
    required String pickup,
    required String destination,
    required String time,
  }) {
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
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '$pickup → $destination',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  time,
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
                  // Passenger request functionality will be added later
                },
                child: const Text('View Passenger'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

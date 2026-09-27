import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  final List<_NearbyMatch> _matches = const [
    _NearbyMatch(name: 'Lorem', distanceKm: 5.0),
    _NearbyMatch(name: 'Ipsum', distanceKm: 2.3),
    _NearbyMatch(name: 'Dolor', distanceKm: 8.1),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- Map layer (placeholder for now) ---
          _buildMap(),

          // --- Back button, floating over the map ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildBackButton(context),
            ),
          ),

          // --- Draggable bottom sheet layer ---
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.18,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDragHandle(),
                    ..._matches.map(_buildMatchRow),
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
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
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

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 60,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchRow(_NearbyMatch match) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 22,
        backgroundColor: Color(0xFFE0E0E0),
        child: Icon(Icons.person, color: Colors.black54),
      ),
      title: Text(match.name, style: const TextStyle(fontSize: 16)),
      trailing: Text(
        '${match.distanceKm.toStringAsFixed(0)}Km',
        style: const TextStyle(fontSize: 16, color: Colors.black54),
      ),
      onTap: () {
        // TODO: navigate to a "confirm ride" / details screen.
      },
    );
  }
}

class _NearbyMatch {
  final String name;
  final double distanceKm;

  const _NearbyMatch({required this.name, required this.distanceKm});
}

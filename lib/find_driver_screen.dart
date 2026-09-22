import 'package:flutter/material.dart';

/// "Find Driver/Passenger" screen.
///
/// Layout: a full-screen map area with a DraggableScrollableSheet
/// docked to the bottom, matching the wireframe (map on top, a
/// draggable panel below showing nearby drivers/passengers).
///
/// NOTE: the map is currently a plain placeholder box so the screen
/// runs with zero setup. Once you're ready to wire in the real map,
/// add `google_maps_flutter` to pubspec.yaml, set up the API key for
/// each platform, and swap `_buildMapPlaceholder()` below for a real
/// `GoogleMap` widget (see the commented-out version at the bottom
/// of this file).
class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  // Placeholder data — replace with results from your matching
  // backend / Distance Matrix API call.
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
          _buildMapPlaceholder(),

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

  Widget _buildMapPlaceholder() {
    return Container(
      color: const Color(0xFFF2F2F2),
      alignment: Alignment.center,
      child: const Text(
        'Map of Location',
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
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

// ---------------------------------------------------------------------
// When you're ready to wire in the real map:
// 1. Run: flutter pub add google_maps_flutter
// 2. Add your API key to AndroidManifest.xml / AppDelegate.swift.
// 3. Add this import at the top of the file:
//      import 'package:google_maps_flutter/google_maps_flutter.dart';
// 4. Replace `_buildMapPlaceholder()` in build() with a GoogleMap,
//    e.g.:
//
//      GoogleMap(
//        initialCameraPosition: const CameraPosition(
//          target: LatLng(-33.9249, 18.4241), // Cape Town, placeholder
//          zoom: 14,
//        ),
//        myLocationEnabled: true,
//        myLocationButtonEnabled: false,
//        zoomControlsEnabled: false,
//        onMapCreated: (controller) => _mapController = controller,
//      ),
//
//    and re-add a `GoogleMapController? _mapController;` field.
// ---------------------------------------------------------------------

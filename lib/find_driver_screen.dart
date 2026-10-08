import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;

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

  List<Map<String, dynamic>> _rides = [];

  bool _isLoading = true;

  int? _requestingRideId;

  MapLibreMapController? _mapController;

  bool _mapStyleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableRides();
  }

  Future<void> _loadAvailableRides() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getUser();

      final rides = await _authService.getAvailableRides();
      debugPrint('AVAILABLE RIDES: $rides');

      if (!mounted) return;

      setState(() {
        _currentUser = user;
        _rides = rides;
        _isLoading = false;
      });

      await _addRideMarkers();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _addRideMarkers() async {
    if (_mapController == null || !_mapStyleLoaded) {
      return;
    }

    try {
      await _mapController!.clearCircles();
      await _mapController!.clearLines();

      for (final ride in _rides) {
        final pickupLatitude = double.tryParse(
          ride['pickupLatitude']?.toString() ?? '',
        );

        final pickupLongitude = double.tryParse(
          ride['pickupLongitude']?.toString() ?? '',
        );

        final destinationLatitude = double.tryParse(
          ride['destinationLatitude']?.toString() ?? '',
        );

        final destinationLongitude = double.tryParse(
          ride['destinationLongitude']?.toString() ?? '',
        );

        // BLUE DOT = Pickup / Start
        if (pickupLatitude != null && pickupLongitude != null) {
          await _mapController!.addCircle(
            CircleOptions(
              geometry: LatLng(pickupLatitude, pickupLongitude),
              circleRadius: 9,
              circleColor: '#0000FF',
              circleOpacity: 1.0,
              circleStrokeWidth: 3,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }

        // RED DOT = Destination / Eduvos
        if (destinationLatitude != null && destinationLongitude != null) {
          await _mapController!.addCircle(
            CircleOptions(
              geometry: LatLng(destinationLatitude, destinationLongitude),
              circleRadius: 9,
              circleColor: '#FF0000',
              circleOpacity: 1.0,
              circleStrokeWidth: 3,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }

        // DRAW THE ACTUAL ROAD ROUTE
        if (pickupLatitude != null &&
            pickupLongitude != null &&
            destinationLatitude != null &&
            destinationLongitude != null) {
          await _drawRoute(
            pickupLatitude: pickupLatitude,
            pickupLongitude: pickupLongitude,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load map route: $e')));
    }
  }

  Future<void> _drawRoute({
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (_mapController == null || !_mapStyleLoaded) {
      return;
    }

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '$pickupLongitude,$pickupLatitude;'
          '$destinationLongitude,$destinationLatitude'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('OSRM returned status ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'Ok') {
        throw Exception('OSRM could not find a route.');
      }

      final routes = data['routes'];

      if (routes == null || routes.isEmpty) {
        throw Exception('No route was found.');
      }

      final coordinates = routes[0]['geometry']['coordinates'] as List;

      final routePoints = coordinates.map<LatLng>((coordinate) {
        final longitude = (coordinate[0] as num).toDouble();
        final latitude = (coordinate[1] as num).toDouble();

        return LatLng(latitude, longitude);
      }).toList();

      if (routePoints.isEmpty) {
        return;
      }

      await _mapController!.addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: '#0F6E56',
          lineWidth: 5.0,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load route: $e')));
    }
  }

  Future<void> _focusOnRide(Map<String, dynamic> ride) async {
    if (_mapController == null) {
      return;
    }

    final latitude = double.tryParse(ride['pickupLatitude']?.toString() ?? '');

    final longitude = double.tryParse(
      ride['pickupLongitude']?.toString() ?? '',
    );

    if (latitude == null || longitude == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(latitude, longitude), zoom: 14),
      ),
    );
  }

  Future<void> _requestRide(Map<String, dynamic> ride) async {
    final rideId = int.tryParse(ride['rideId'].toString());

    if (rideId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid ride ID.')));

      return;
    }

    setState(() {
      _requestingRideId = rideId;
    });

    try {
      await _authService.requestRide(rideId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request sent successfully.')),
      );

      await _loadAvailableRides();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _requestingRideId = null;
        });
      }
    }
  }

  String _formatScheduledTime(dynamic scheduledFor) {
    if (scheduledFor == null) {
      return 'Unknown time';
    }

    try {
      final date = DateTime.parse(scheduledFor.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    } catch (_) {
      return 'Unknown time';
    }
  }

  String _formatFare(dynamic estimatedFare) {
    if (estimatedFare == null) {
      return 'Not available';
    }

    final fare = double.tryParse(estimatedFare.toString());

    if (fare == null) {
      return 'Not available';
    }

    return 'R${fare.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find a Driver',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAvailableRides,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh rides',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildRideContent(colorScheme),
    );
  }

  Widget _buildMap() {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-33.88, 18.63),
        zoom: 11,
      ),
      styleString: 'https://tiles.openfreemap.org/styles/bright',

      onMapCreated: (controller) {
        _mapController = controller;
      },

      onStyleLoadedCallback: () async {
        _mapStyleLoaded = true;
        await _addRideMarkers();
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 30, 25, 35),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 60,
                  color: colorScheme.onSurfaceVariant,
                ),

                const SizedBox(height: 15),

                const Text(
                  'No Rides Available',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'There are currently no available rides. '
                  'Check again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loadAvailableRides,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Search Again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRideContent(ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),

        DraggableScrollableSheet(
          initialChildSize: 0.48,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.25, 0.48, 0.85],
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
                  Container(
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

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Rides',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_rides.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ..._rides.map((ride) => _buildRideCard(context, ride)),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final colorScheme = Theme.of(context).colorScheme;

    final rideId = int.tryParse(ride['rideId'].toString());

    final isRequesting = rideId != null && _requestingRideId == rideId;

    final pickup = ride['pickupAddress']?.toString() ?? 'Unknown pickup';

    final destination =
        ride['destinationAddress']?.toString() ?? 'Unknown destination';

    final seats = ride['availableSeats']?.toString() ?? 'Unknown';

    final scheduled = _formatScheduledTime(ride['scheduledFor']);

    final fare = _formatFare(ride['estimatedFare']);

    return Card(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _focusOnRide(ride);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Text(
                      'Driver',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fare,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Text(
                        'estimated fare',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 21,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(pickup, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 21,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(destination, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _buildDetail(
                      icon: Icons.access_time_outlined,
                      text: scheduled,
                      colorScheme: colorScheme,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _buildDetail(
                      icon: Icons.people_outline,
                      text: '$seats seats',
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Tap the ride to view its pickup location',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isRequesting
                      ? null
                      : () {
                          _requestRide(ride);
                        },
                  icon: isRequesting
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.directions_car_outlined),
                  label: Text(isRequesting ? 'Requesting...' : 'Request Ride'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail({
    required IconData icon,
    required String text,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

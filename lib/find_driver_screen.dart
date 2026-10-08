import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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

      if (!mounted) return;

      setState(() {
        _currentUser = user;
        _rides = rides;
        _isLoading = false;
      });
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

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.88, 18.63),
              zoom: 11,
            ),
            styleString: 'https://tiles.openfreemap.org/styles/bright',
          ),
        ),

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
        // -------------------------------------------------------------
        // MAP
        // -------------------------------------------------------------

        Positioned.fill(
          child: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.88, 18.63),
              zoom: 11,
            ),
            styleString: 'https://tiles.openfreemap.org/styles/bright',
          ),
        ),

        // -------------------------------------------------------------
        // RIDE LIST
        // -------------------------------------------------------------
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
                  // Drag handle
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

                  // Heading
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

                  // Ride cards
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------
            // RIDE HEADER
            // ---------------------------------------------------------

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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

            // ---------------------------------------------------------
            // PICKUP
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // DESTINATION
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // RIDE DETAILS
            // ---------------------------------------------------------
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

            const SizedBox(height: 16),

            // ---------------------------------------------------------
            // REQUEST BUTTON
            // ---------------------------------------------------------
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

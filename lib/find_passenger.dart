import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mova/config/app_config.dart';
import 'package:mova/services/route_service.dart';

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
    baseUrl: AppConfig.backendBaseUrl,
  );

  final RouteService _routeService = RouteService();

  final Map<int, String?> _passengerImageUrls = {};
  final Set<int> _loadingPassengerImages = {};

  MapLibreMapController? _mapController;

  bool _mapStyleLoaded = false;
  User? _currentUser;
  Map<String, dynamic>? _activeRide;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRideRequests();
  }

  // ---------------------------------------------------------------
  // PASSENGER PROFILE PICTURES
  // ---------------------------------------------------------------

  Future<void> _loadPassengerProfileImage(Map<String, dynamic> request) async {
    final passengerId = int.tryParse(request['passengerId']?.toString() ?? '');

    if (passengerId == null ||
        _passengerImageUrls.containsKey(passengerId) ||
        _loadingPassengerImages.contains(passengerId)) {
      return;
    }

    _loadingPassengerImages.add(passengerId);

    try {
      final response = await _authService.getUserProfile(passengerId);

      // Support responses that wrap the user inside a "user" object.
      final nestedUser = response['user'];

      final profile = nestedUser is Map
          ? Map<String, dynamic>.from(nestedUser)
          : response;

      String? readText(List<String> keys) {
        for (final key in keys) {
          final value = profile[key]?.toString().trim();

          if (value != null && value.isNotEmpty && value != 'null') {
            return value;
          }
        }

        return null;
      }

      // IMPORTANT: Prefer the complete Supabase URL.
      final rawUrl = readText([
        'profileIconUrl',
        'profileImageUrl',
        'profilePictureUrl',
        'avatarUrl',
        'profileIcon',
        'profileicon',
        'profileImage',
        'profilePicture',
      ]);

      String? imageUrl;

      if (rawUrl != null) {
        final uri = Uri.tryParse(rawUrl);

        // Use a complete HTTP or HTTPS URL directly.
        if (uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty) {
          imageUrl = rawUrl;
        }
      }

      if (!mounted) return;

      setState(() {
        _passengerImageUrls[passengerId] = imageUrl;
      });
    } catch (e) {
      debugPrint('Could not load passenger profile image: $e');

      if (!mounted) return;

      setState(() {
        _passengerImageUrls[passengerId] = null;
      });
    } finally {
      _loadingPassengerImages.remove(passengerId);
    }
  }

  // ---------------------------------------------------------------
  // LOAD ACTIVE RIDE AND REQUESTS
  // ---------------------------------------------------------------

  Future<void> _loadRideRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getUser();
      final ride = await _authService.getActiveRide();

      if (!mounted) return;

      if (ride == null) {
        setState(() {
          _currentUser = user;
          _activeRide = null;
          _requests = [];
          _isLoading = false;
        });

        return;
      }

      final rideId = int.tryParse(ride['rideId'].toString());

      if (rideId == null) {
        throw Exception('Invalid ride ID returned by the server.');
      }

      final requests = await _authService.getRideRequests(rideId);

      if (!mounted) return;

      setState(() {
        _currentUser = user;
        _activeRide = ride;
        _requests = requests;
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

  Future<void> _refreshRequests() async {
    if (_activeRide == null) {
      await _loadRideRequests();
      return;
    }

    final rideId = int.tryParse(_activeRide!['rideId'].toString());

    if (rideId == null) return;

    try {
      final requests = await _authService.getRideRequests(rideId);

      if (!mounted) return;

      setState(() {
        _requests = requests;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---------------------------------------------------------------
  // ACCEPT OR REJECT PASSENGER
  // ---------------------------------------------------------------

  Future<void> _acceptPassenger(Map<String, dynamic> request) async {
    final rideId = int.tryParse(_activeRide?['rideId'].toString() ?? '');

    final passengerId = int.tryParse(request['passengerId']?.toString() ?? '');

    if (rideId == null || passengerId == null) return;

    try {
      await _authService.acceptPassenger(
        rideId: rideId,
        passengerId: passengerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Passenger accepted.')));

      await _refreshRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _rejectPassenger(Map<String, dynamic> request) async {
    final rideId = int.tryParse(_activeRide?['rideId'].toString() ?? '');

    final passengerId = int.tryParse(request['passengerId']?.toString() ?? '');

    if (rideId == null || passengerId == null) return;

    try {
      await _authService.rejectPassenger(
        rideId: rideId,
        passengerId: passengerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passenger request rejected.')),
      );

      await _refreshRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---------------------------------------------------------------
  // OPEN MESSAGES
  // ---------------------------------------------------------------

  void _openMessageScreen(Map<String, dynamic> request) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while your account is loaded.'),
        ),
      );
      return;
    }

    final rideId = _activeRide?['rideId']?.toString();
    final passengerId = request['passengerId']?.toString();
    final passengerName = request['passengerName']?.toString() ?? 'Passenger';

    if (rideId == null || passengerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the conversation.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageScreen(
          rideId: rideId,
          currentUserId: _currentUser!.userId.toString(),
          otherUserId: passengerId,
          otherUserName: passengerName,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // RIDE DATE
  // ---------------------------------------------------------------

  String _formatRideDate() {
    if (_activeRide == null || _activeRide!['scheduledFor'] == null) {
      return 'Unknown date';
    }

    try {
      final date = DateTime.parse(_activeRide!['scheduledFor'].toString())
          .toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    } catch (_) {
      return 'Unknown date';
    }
  }

  // ---------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------

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
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRideRequests,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(colorScheme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (_activeRide == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 70,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Ride',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Create a ride first. Passenger requests '
                'will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // MAP
        Positioned.fill(
          child: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.88, 18.63),
              zoom: 11,
            ),
            styleString: 'https://tiles.openfreemap.org/styles/bright',

            // Keep attribution away from the message buttons.
            attributionButtonPosition: AttributionButtonPosition.topRight,
            attributionButtonMargins: const math.Point(8, 8),

            onMapCreated: (controller) {
              _mapController = controller;
            },
            onStyleLoadedCallback: () {
              _mapStyleLoaded = true;
              _drawActiveRideRoute();
            },
          ),
        ),

        // BOTTOM SHEET
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.25, 0.45, 0.85],
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
                  // DRAG HANDLE
                  Padding(
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

                  // RIDE INFORMATION
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Active Ride',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRideInfo(
                          icon: Icons.location_on_outlined,
                          title: 'Pickup',
                          value:
                              _activeRide!['pickupAddress']?.toString() ??
                              'Unknown',
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(height: 8),
                        _buildRideInfo(
                          icon: Icons.school_outlined,
                          title: 'Destination',
                          value:
                              _activeRide!['destinationAddress']?.toString() ??
                              'Unknown',
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(height: 8),
                        _buildRideInfo(
                          icon: Icons.access_time_outlined,
                          title: 'Scheduled',
                          value: _formatRideDate(),
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 25),

                  // REQUEST HEADING
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Passenger Requests',
                          style: TextStyle(
                            fontSize: 19,
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
                            '${_requests.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // REQUEST LIST
                  if (_requests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 55,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No passenger requests yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Passenger requests will appear here '
                            'when someone wants to join your ride.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._requests.map(
                      (request) => _buildPassengerCard(context, request),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // RIDE INFORMATION ROW
  // ---------------------------------------------------------------

  Widget _buildRideInfo({
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // DRAW ACTIVE RIDE ROUTE
  // ---------------------------------------------------------------

  Future<void> _drawActiveRideRoute() async {
    final ride = _activeRide;
    final controller = _mapController;

    if (ride == null || controller == null || !_mapStyleLoaded) {
      return;
    }

    final pickupLat = double.tryParse(ride['pickupLatitude']?.toString() ?? '');
    final pickupLon = double.tryParse(
      ride['pickupLongitude']?.toString() ?? '',
    );
    final destinationLat = double.tryParse(
      ride['destinationLatitude']?.toString() ?? '',
    );
    final destinationLon = double.tryParse(
      ride['destinationLongitude']?.toString() ?? '',
    );

    if (pickupLat == null ||
        pickupLon == null ||
        destinationLat == null ||
        destinationLon == null) {
      debugPrint('Active ride is missing valid route coordinates.');
      return;
    }

    try {
      await controller.clearCircles();
      await controller.clearLines();

      final route = await _routeService.getRoute(
        startLat: pickupLat,
        startLon: pickupLon,
        endLat: destinationLat,
        endLon: destinationLon,
      );

      if (!mounted || _mapController != controller || !_mapStyleLoaded) {
        return;
      }

      final points = route.coordinates.map((coordinate) {
        return LatLng(coordinate[1], coordinate[0]);
      }).toList();

      if (points.isEmpty) {
        throw Exception('The route contains no coordinates.');
      }

      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(pickupLat, pickupLon),
          circleRadius: 9,
          circleColor: '#0000FF',
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(destinationLat, destinationLon),
          circleRadius: 9,
          circleColor: '#FF0000',
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#0F6E56',
          lineWidth: 5,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );

      debugPrint(
        'Active ride route loaded: '
        '${route.distanceKm.toStringAsFixed(1)} km, '
        '${route.durationMinutes.toStringAsFixed(0)} minutes.',
      );
    } catch (e) {
      debugPrint('Could not load active ride route: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load route: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------
  // PASSENGER CARD
  // ---------------------------------------------------------------

  Widget _buildPassengerCard(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final passengerName = request['passengerName']?.toString() ?? 'Passenger';

    final status = request['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';

    final passengerId = int.tryParse(request['passengerId']?.toString() ?? '');

    if (passengerId != null &&
        !_passengerImageUrls.containsKey(passengerId) &&
        !_loadingPassengerImages.contains(passengerId)) {
      _loadPassengerProfileImage(request);
    }

    final imageUrl = passengerId == null
        ? null
        : _passengerImageUrls[passengerId];

    return Card(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // PASSENGER INFORMATION
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colorScheme.primaryContainer,
                  child: ClipOval(
                    child: imageUrl == null
                        ? Icon(
                            Icons.person,
                            color: colorScheme.onPrimaryContainer,
                            size: 28,
                          )
                        : Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: colorScheme.primaryContainer,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.person,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 28,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isPending
                            ? 'Passenger wants to join your ride'
                            : 'Request status: ${_formatStatus(status)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status, colorScheme),
              ],
            ),

            const SizedBox(height: 14),

            // ACCEPT AND REJECT BUTTONS
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _rejectPassenger(request);
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _acceptPassenger(request);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              ),

            // MESSAGE BUTTON FOR ACCEPTED OR OTHER REQUESTS
            if (!isPending)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _openMessageScreen(request);
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Message Passenger'),
                ),
              ),

            // MESSAGE BUTTON FOR PENDING REQUESTS
            if (isPending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openMessageScreen(request);
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Message Passenger'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // REQUEST STATUS BADGE
  // ---------------------------------------------------------------

  Widget _buildStatusBadge(String status, ColorScheme colorScheme) {
    final displayStatus = _formatStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}

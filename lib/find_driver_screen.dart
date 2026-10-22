import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mova/config/app_config.dart';

import 'services/auth_service.dart';
import 'services/route_service.dart';

// Passenger-side screen: shows available rides on a map and in a draggable
// list, lets the passenger filter to rides near their GPS position, preview
// a ride's route and send a ride request.
class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  // Fetches the driving route between two points.
  final RouteService _routeService = RouteService();

  // Cache of driver profile details (name and image URL), keyed by driver ID.
  final Map<int, Map<String, dynamic>> _driverProfiles = {};

  // IDs of drivers whose profiles are currently being loaded
  // (prevents duplicate requests).
  final Set<int> _loadingDriverProfiles = {};

  // All available rides returned by the backend.
  List<Map<String, dynamic>> _rides = [];

  // The passenger's GPS position (null until "Use my location" succeeds).
  Position? _currentLocation;

  bool _isLoading = true;
  bool _isGettingLocation = false;

  // When true, show every ride instead of only rides near the passenger.
  bool _showAllRides = false;

  // Rides whose pickup is farther than this from the passenger are
  // hidden in "nearby" mode.
  static const double _nearbyRadiusKm = 5.0;

  // ID of the ride currently being requested (disables its button).
  int? _requestingRideId;

  // ID of the ride whose route is shown on the map.
  int? _selectedRideId;

  MapLibreMapController? _mapController;

  // True once the map style has finished loading (markers can be drawn).
  bool _mapStyleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableRides();
  }

  // ---------------------------------------------------------------
  // DRIVER PROFILE DETAILS
  // ---------------------------------------------------------------

  // Finds the driver's user ID in a ride, trying several field names
  // because the API may use different ones. Returns null if none is found.
  int? _getDriverId(Map<String, dynamic> ride) {
    // Check common driver ID fields returned by the API.
    for (final key in [
      'driverId',
      'driverUserId',
      'userId',
      'createdByUserId',
    ]) {
      final id = int.tryParse(ride[key]?.toString() ?? '');

      if (id != null) return id;
    }

    // Some APIs return the driver as a nested object.
    final driver = ride['driver'];

    if (driver is Map) {
      for (final key in ['userId', 'driverId', 'id']) {
        final id = int.tryParse(driver[key]?.toString() ?? '');

        if (id != null) return id;
      }
    }

    return null;
  }

  // Loads a driver's name and profile picture URL and caches them.
  Future<void> _loadDriverProfile(Map<String, dynamic> ride) async {
    final driverId = _getDriverId(ride);

    // Skip if there's no ID, or the profile is already cached/loading.
    if (driverId == null ||
        _driverProfiles.containsKey(driverId) ||
        _loadingDriverProfiles.contains(driverId)) {
      return;
    }

    _loadingDriverProfiles.add(driverId);

    try {
      final response = await _authService.getUserProfile(driverId);

      // Support responses that wrap the user inside a "user" object.
      final nestedUser = response['user'];

      final profile = nestedUser is Map
          ? Map<String, dynamic>.from(nestedUser)
          : response;

      // Returns the first non-empty value found under any of the [keys],
      // or null if none of them has a usable value.
      String? readText(List<String> keys) {
        for (final key in keys) {
          final value = profile[key]?.toString().trim();

          if (value != null && value.isNotEmpty && value != 'null') {
            return value;
          }
        }

        return null;
      }

      final firstName = readText(['firstName', 'firstname', 'name']);
      final surname = readText(['surname', 'lastName', 'lastname']);

      // Join whichever name parts exist into a full name.
      final fullName = [
        firstName,
        surname,
      ].where((part) => part != null && part.isNotEmpty).join(' ');

      // IMPORTANT: Use profileIconUrl before profileIcon.
      final rawImageUrl = readText([
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

      // Only accept complete http/https URLs.
      if (rawImageUrl != null) {
        final uri = Uri.tryParse(rawImageUrl);

        if (uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty) {
          imageUrl = rawImageUrl;
        }
      }

      if (!mounted) return;

      setState(() {
        _driverProfiles[driverId] = {
          'name': fullName.isNotEmpty ? fullName : null,
          'imageUrl': imageUrl,
        };
      });
    } catch (e) {
      debugPrint('Could not load driver profile $driverId: $e');

      if (!mounted) return;

      // Cache an empty profile so we don't keep retrying a failed lookup.
      setState(() {
        _driverProfiles[driverId] = {'name': null, 'imageUrl': null};
      });
    } finally {
      _loadingDriverProfiles.remove(driverId);
    }
  }

  // Returns the best available driver name for a ride:
  // 1) the loaded profile, 2) a name in the ride data, 3) a nested driver
  // object, otherwise the generic "Driver".
  String _getDriverName(Map<String, dynamic> ride) {
    final driverId = _getDriverId(ride);
    final profile = driverId == null ? null : _driverProfiles[driverId];

    final profileName = profile?['name']?.toString();

    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    // Use a name already supplied by the ride response if available.
    for (final key in ['driverName', 'fullName', 'name']) {
      final name = ride[key]?.toString().trim();

      if (name != null && name.isNotEmpty && name != 'null') {
        return name;
      }
    }

    // Also support a nested driver object in the ride response.
    final driver = ride['driver'];

    if (driver is Map) {
      final firstName = driver['firstName']?.toString().trim() ?? '';
      final surname =
          driver['surname']?.toString().trim() ??
          driver['lastName']?.toString().trim() ??
          '';

      final fullName = '$firstName $surname'.trim();

      if (fullName.isNotEmpty) {
        return fullName;
      }
    }

    return 'Driver';
  }

  // Returns the best available driver picture URL for a ride, or null.
  // Prefers the loaded profile, then image fields in the ride data.
  String? _getDriverImageUrl(Map<String, dynamic> ride) {
    final driverId = _getDriverId(ride);
    final profile = driverId == null ? null : _driverProfiles[driverId];

    final profileImage = profile?['imageUrl']?.toString();

    if (profileImage != null && profileImage.isNotEmpty) {
      return profileImage;
    }

    // Also support an image URL included directly in the ride response.
    final driver = ride['driver'];

    final possibleImages = [
      ride['profileIcon'],
      ride['profileicon'],
      ride['profileImageUrl'],
      ride['profilePictureUrl'],
      ride['avatarUrl'],
      if (driver is Map) driver['profileIcon'],
      if (driver is Map) driver['profileImageUrl'],
      if (driver is Map) driver['profilePictureUrl'],
      if (driver is Map) driver['avatarUrl'],
    ];

    for (final value in possibleImages) {
      final image = value?.toString().trim();

      if (image != null && image.isNotEmpty && image != 'null') {
        final uri = Uri.tryParse(image);

        // Complete URL: use it as is.
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          return image;
        }

        // Relative path: resolve it against the backend's base URL.
        return Uri.parse(AppConfig.backendBaseUrl)
            .resolve(image.startsWith('/') ? image : '/$image')
            .toString();
      }
    }

    return null;
  }

  // ---------------------------------------------------------------
  // DISTANCE AND NEARBY RIDES
  // ---------------------------------------------------------------

  // Distance in kilometres between two coordinates, using the haversine
  // formula (accounts for the curvature of the Earth).
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;

    final latDifference = _degreesToRadians(lat2 - lat1);
    final lonDifference = _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(latDifference / 2) * math.sin(latDifference / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(lonDifference / 2) *
            math.sin(lonDifference / 2);

    // Guard against tiny rounding errors pushing `a` outside 0..1.
    final boundedA = a.clamp(0.0, 1.0);

    final c = 2 * math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));

    return earthRadiusKm * c;
  }

  // Converts degrees to radians.
  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  // Distance from the passenger to a ride's pickup point, in km.
  // Returns null if the passenger's location or the pickup is unknown.
  double? _getRideDistance(Map<String, dynamic> ride) {
    final pickupLat = double.tryParse(ride['pickupLatitude']?.toString() ?? '');

    final pickupLon = double.tryParse(
      ride['pickupLongitude']?.toString() ?? '',
    );

    final location = _currentLocation;

    if (location == null || pickupLat == null || pickupLon == null) {
      return null;
    }

    return _distanceKm(
      location.latitude,
      location.longitude,
      pickupLat,
      pickupLon,
    );
  }

  // The rides to show: all of them without GPS, otherwise (unless "Show all"
  // is on) only rides within the nearby radius, sorted closest first.
  List<Map<String, dynamic>> get _visibleRides {
    final rides = List<Map<String, dynamic>>.from(_rides);

    // Without a location we can't filter or sort by distance.
    if (_currentLocation == null) {
      return rides;
    }

    // In "nearby" mode, drop rides that are too far or have no distance.
    if (!_showAllRides) {
      rides.removeWhere((ride) {
        final distance = _getRideDistance(ride);

        return distance == null || distance > _nearbyRadiusKm;
      });
    }

    // Closest rides first; rides with unknown distance go last.
    rides.sort((a, b) {
      final distanceA = _getRideDistance(a) ?? double.infinity;
      final distanceB = _getRideDistance(b) ?? double.infinity;

      return distanceA.compareTo(distanceB);
    });

    return rides;
  }

  // ---------------------------------------------------------------
  // LOCATION
  // ---------------------------------------------------------------

  // Gets the phone's GPS position (after checking that location services
  // are on and permission is granted), then re-filters rides and zooms the
  // map to the passenger.
  Future<void> _useMyLocation() async {
    // Ignore taps while a location request is already running.
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      // 1. Is GPS turned on?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Please enable Location Services on your phone.');
      }

      // 2. Do we have permission? Ask if we haven't yet.
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      // Permanently denied: the user must change it in phone settings.
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Enable it in your phone settings.',
        );
      }

      // 3. Get the current position at high accuracy.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      // Save the position and reset to "nearby" mode with nothing selected.
      setState(() {
        _currentLocation = position;
        _showAllRides = false;
        _selectedRideId = null;
      });

      // Redraw markers, then zoom the map to the passenger.
      await _addRideMarkers();

      if (_mapController != null && _mapStyleLoaded) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 13,
            ),
          ),
        );
      }

      if (!mounted) return;

      // Tell the user how many nearby rides were found.
      final nearbyCount = _visibleRides.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nearbyCount == 0
                ? 'No rides found within 5 km. Try showing all rides.'
                : 'Found $nearbyCount ride(s) within 5 km.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      // Re-enable the location button.
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------
  // LOAD RIDES
  // ---------------------------------------------------------------

  // Loads the available rides from the backend and redraws the map markers.
  Future<void> _loadAvailableRides() async {
    // Show the full-screen spinner only on the first load; refreshes after
    // that show a spinner in the app bar instead.
    if (!(_isLoading && _rides.isEmpty)) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final rides = await _authService.getAvailableRides();

      if (!mounted) return;

      setState(() {
        _rides = rides;
        _isLoading = false;
        _selectedRideId = null;
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

  // ---------------------------------------------------------------
  // MAP MARKERS AND ROUTE
  // ---------------------------------------------------------------

  // Redraws everything on the map: the passenger's marker, a marker for each
  // visible ride's pickup and, for the selected ride, its destination and
  // route.
  Future<void> _addRideMarkers() async {
    // Nothing to draw until the map is ready.
    if (_mapController == null || !_mapStyleLoaded) {
      return;
    }

    try {
      // Start from a clean map.
      await _mapController!.clearCircles();
      await _mapController!.clearLines();

      // Green marker: passenger's current location.
      final location = _currentLocation;

      if (location != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(location.latitude, location.longitude),
            circleRadius: 10,
            circleColor: '#0F6E56',
            circleOpacity: 1,
            circleStrokeWidth: 3,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }

      // Blue markers: pickup points in the current search results.
      for (final ride in _visibleRides) {
        final pickupLat = double.tryParse(
          ride['pickupLatitude']?.toString() ?? '',
        );

        final pickupLon = double.tryParse(
          ride['pickupLongitude']?.toString() ?? '',
        );

        // Skip rides without valid pickup coordinates.
        if (pickupLat == null || pickupLon == null) {
          continue;
        }

        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(pickupLat, pickupLon),
            circleRadius: 7,
            circleColor: '#0000FF',
            circleOpacity: 1,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }

      // Without a selected ride there is no destination or route to draw.
      if (_selectedRideId == null) {
        return;
      }

      // Find the selected ride among the visible rides.
      Map<String, dynamic>? selectedRide;

      for (final ride in _visibleRides) {
        final rideId = int.tryParse(ride['rideId']?.toString() ?? '');

        if (rideId == _selectedRideId) {
          selectedRide = ride;
          break;
        }
      }

      if (selectedRide == null) {
        return;
      }

      final pickupLat = double.tryParse(
        selectedRide['pickupLatitude']?.toString() ?? '',
      );

      final pickupLon = double.tryParse(
        selectedRide['pickupLongitude']?.toString() ?? '',
      );

      final destinationLat = double.tryParse(
        selectedRide['destinationLatitude']?.toString() ?? '',
      );

      final destinationLon = double.tryParse(
        selectedRide['destinationLongitude']?.toString() ?? '',
      );

      // Red marker: destination.
      if (destinationLat != null && destinationLon != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(destinationLat, destinationLon),
            circleRadius: 9,
            circleColor: '#FF0000',
            circleOpacity: 1,
            circleStrokeWidth: 3,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }

      // Draw the route only when all four coordinates are valid.
      if (pickupLat != null &&
          pickupLon != null &&
          destinationLat != null &&
          destinationLon != null) {
        await _drawRoute(
          pickupLatitude: pickupLat,
          pickupLongitude: pickupLon,
          destinationLatitude: destinationLat,
          destinationLongitude: destinationLon,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update map: $e')));
    }
  }

  // Selects a ride: highlights its card, draws its route and zooms the map
  // to its pickup point.
  Future<void> _selectRide(Map<String, dynamic> ride) async {
    final rideId = int.tryParse(ride['rideId']?.toString() ?? '');

    if (rideId == null) return;

    setState(() {
      _selectedRideId = rideId;
    });

    await _addRideMarkers();

    final pickupLat = double.tryParse(ride['pickupLatitude']?.toString() ?? '');

    final pickupLon = double.tryParse(
      ride['pickupLongitude']?.toString() ?? '',
    );

    // Zoom to the pickup point when it is valid and the map is ready.
    if (pickupLat != null &&
        pickupLon != null &&
        _mapController != null &&
        _mapStyleLoaded) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pickupLat, pickupLon), zoom: 13),
        ),
      );
    }
  }

  // Fetches the driving route between pickup and destination, draws it as
  // a green line and shows its distance and duration in a snack bar.
  Future<void> _drawRoute({
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (_mapController == null || !_mapStyleLoaded) return;

    try {
      final route = await _routeService.getRoute(
        startLat: pickupLatitude,
        startLon: pickupLongitude,
        endLat: destinationLatitude,
        endLon: destinationLongitude,
      );

      // The screen or map may have gone away while waiting for the route.
      if (!mounted || _mapController == null || !_mapStyleLoaded) {
        return;
      }

      final routePoints = route.coordinates.map((coordinate) {
        // OSRM returns [longitude, latitude].
        return LatLng(coordinate[1], coordinate[0]);
      }).toList();

      if (routePoints.isEmpty) {
        throw Exception('The route contains no coordinates.');
      }

      // Green line: the route itself.
      await _mapController!.addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: '#0F6E56',
          lineWidth: 5,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Route: ${route.distanceKm.toStringAsFixed(1)} km · '
            '${route.durationMinutes.toStringAsFixed(0)} min',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
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
  // REQUEST RIDE
  // ---------------------------------------------------------------

  // Sends a request to join the given ride, then reloads the list.
  Future<void> _requestRide(Map<String, dynamic> ride) async {
    final rideId = int.tryParse(ride['rideId']?.toString() ?? '');

    if (rideId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid ride ID.')));
      return;
    }

    // Mark this ride as busy so its button shows "Requesting...".
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
      // Always clear the busy state.
      if (mounted) {
        setState(() {
          _requestingRideId = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------

  // Formats a scheduled date as "dd/mm/yyyy at HH:mm" in local time.
  // Returns "Unknown time" if it is missing or can't be parsed.
  String _formatScheduledTime(dynamic scheduledFor) {
    if (scheduledFor == null) return 'Unknown time';

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

  // ---------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------

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
          // "Use my location" button (shows a spinner while locating).
          IconButton(
            onPressed: _isGettingLocation ? null : _useMyLocation,
            tooltip: 'Use my location',
            icon: _isGettingLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
          // Refresh button (disabled while loading).
          IconButton(
            onPressed: _isLoading ? null : _loadAvailableRides,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh rides',
          ),
        ],
      ),
      // Spinner while loading, an empty state if there are no rides,
      // otherwise the map with the list of rides.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildRideContent(colorScheme),
    );
  }

  // Builds the interactive map used behind both the empty state and the
  // ride list.
  Widget _buildMap() {
    return MapLibreMap(
      // Start centred on the Tyger Valley area.
      initialCameraPosition: const CameraPosition(
        target: LatLng(-33.88, 18.63),
        zoom: 11,
      ),
      // Free OpenFreeMap "bright" map style.
      styleString: 'https://tiles.openfreemap.org/styles/bright',
      // Keep a reference to the map controller.
      onMapCreated: (controller) {
        _mapController = controller;
      },
      // Once the style is loaded, draw the markers.
      onStyleLoadedCallback: () async {
        _mapStyleLoaded = true;

        await _addRideMarkers();

        // Centre the map on the passenger if GPS was obtained earlier.
        final location = _currentLocation;

        if (location != null && mounted) {
          await _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(location.latitude, location.longitude),
                zoom: 13,
              ),
            ),
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------

  // Shown when the backend returned no rides: the map with a bottom panel
  // offering to search again or use the passenger's location.
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
                // Reload the rides.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loadAvailableRides,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Search Again'),
                  ),
                ),
                const SizedBox(height: 8),
                // Get the passenger's GPS position.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _useMyLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use My Location'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // RIDE LIST
  // ---------------------------------------------------------------

  // The map with a draggable bottom sheet listing the visible rides.
  Widget _buildRideContent(ColorScheme colorScheme) {
    final visibleRides = _visibleRides;

    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),
        // Sheet snaps between 25%, 48% and 85% of the screen height.
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
                // The sheet's scroll controller lets the list and the sheet
                // drag together.
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle.
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
                  // Header: title, filter toggle and ride count.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _currentLocation != null && !_showAllRides
                                ? 'Nearby Rides'
                                : 'Available Rides',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Without GPS this button gets the location;
                        // with GPS it toggles between nearby and all rides.
                        TextButton(
                          onPressed: _currentLocation == null
                              ? _useMyLocation
                              : () async {
                                  setState(() {
                                    _showAllRides = !_showAllRides;
                                    _selectedRideId = null;
                                  });

                                  await _addRideMarkers();
                                },
                          child: Text(
                            _currentLocation == null
                                ? 'Use GPS'
                                : _showAllRides
                                ? 'Nearby only'
                                : 'Show all',
                          ),
                        ),
                        // Pill showing how many rides are visible.
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
                            '${visibleRides.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Reminder of the active nearby filter.
                  if (_currentLocation != null && !_showAllRides)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        'Showing rides within 5 km of your location.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // Either a "no rides" message or one card per ride.
                  if (visibleRides.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 42,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currentLocation == null
                                  ? 'No rides are currently available.'
                                  : 'No rides found within 5 km. '
                                        'Try "Show all" to see other rides.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            // Shortcut to widen the search to all rides.
                            if (_currentLocation != null && !_showAllRides) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () async {
                                  setState(() {
                                    _showAllRides = true;
                                  });

                                  await _addRideMarkers();
                                },
                                child: const Text('Show all rides'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    ...visibleRides.map(
                      (ride) => _buildRideCard(context, ride),
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
  // INDIVIDUAL RIDE CARD
  // ---------------------------------------------------------------

  // Builds the card for one ride: driver, pickup, destination, distance,
  // time, seats and the "Request Ride" button. Tapping the card selects the
  // ride and shows its route on the map.
  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final colorScheme = Theme.of(context).colorScheme;

    final rideId = int.tryParse(ride['rideId']?.toString() ?? '');

    // True while a request for this ride is in progress.
    final isRequesting = rideId != null && _requestingRideId == rideId;

    // True when this ride is the one shown on the map.
    final isSelected = rideId != null && _selectedRideId == rideId;

    final pickup = ride['pickupAddress']?.toString() ?? 'Unknown pickup';

    final destination =
        ride['destinationAddress']?.toString() ?? 'Unknown destination';

    final seats = ride['availableSeats']?.toString() ?? 'Unknown';

    final scheduled = _formatScheduledTime(ride['scheduledFor']);

    final driverId = _getDriverId(ride);

    // Fetch the profile when we have a driver ID.
    if (driverId != null &&
        !_driverProfiles.containsKey(driverId) &&
        !_loadingDriverProfiles.contains(driverId)) {
      _loadDriverProfile(ride);
    }

    final driverName = _getDriverName(ride);
    final driverImageUrl = _getDriverImageUrl(ride);
    final distance = _getRideDistance(ride);

    return Card(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      // The selected card is raised and outlined in the primary colour.
      elevation: isSelected ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectRide(ride),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver name and profile picture.
              // Estimated fare has been removed.
              Row(
                children: [
                  // Picture, or a person icon if none/failed to load.
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: colorScheme.primaryContainer,
                    child: driverImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              driverImageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 30,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: colorScheme.onPrimaryContainer,
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pickup address.
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

              // Destination address.
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

              // Distance from passenger to pickup.
              // Only shown once the passenger's location is known.
              if (distance != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${distance.toStringAsFixed(1)} km from your location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Ride time and available seats.
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

              // Hint that changes once this ride's route is on the map.
              Text(
                isSelected
                    ? 'Route currently shown on the map'
                    : 'Tap the ride to view its route',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 12),

              // Request ride button.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  // Disabled while this ride is being requested.
                  onPressed: isRequesting ? null : () => _requestRide(ride),
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

  // A small "icon + text" row used for the ride's time and seat details.
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

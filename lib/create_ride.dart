import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'config/app_config.dart';
import '../services/auth_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController _startLocationController =
      TextEditingController();

  // Eduvos Tygervalley
  static const LatLng _destinationLocation = LatLng(-33.8709, 18.6402);

  static const String _destination =
      'Eduvos Tygervalley, 9 Rogers St, Tyger Valley';

  final TextEditingController _destinationController = TextEditingController(
    text: _destination,
  );

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int _availableSeats = 1;

  LatLng? _pickupLocation;

  bool _isCreatingRide = false;
  bool _isGettingLocation = false;
  bool _mapStyleLoaded = false;

  MapLibreMapController? _mapController;
  Circle? _pickupCircle;

  @override
  void dispose() {
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  String _coordinatesLabel(LatLng coordinates) {
    return '${coordinates.latitude.toStringAsFixed(5)}, '
        '${coordinates.longitude.toStringAsFixed(5)}';
  }

  Future<void> _selectPickupLocation(
    LatLng coordinates, {
    bool fromGps = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _pickupLocation = coordinates;

      // This is a coordinate-based label, not a street address.
      // The backend still receives the precise pickup coordinates.
      _startLocationController.text = fromGps
          ? 'Current location (${_coordinatesLabel(coordinates)})'
          : 'Selected map location (${_coordinatesLabel(coordinates)})';
    });

    await _updatePickupMarker(coordinates);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fromGps
              ? 'Your current location has been selected as the pickup.'
              : 'Pickup location updated.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updatePickupMarker(LatLng coordinates) async {
    final controller = _mapController;

    if (controller == null || !_mapStyleLoaded) return;

    try {
      if (_pickupCircle != null) {
        await controller.removeCircle(_pickupCircle!);
        _pickupCircle = null;
      }

      _pickupCircle = await controller.addCircle(
        CircleOptions(
          geometry: coordinates,
          circleRadius: 9,
          circleColor: '#E53935',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    } catch (e) {
      debugPrint('Could not update pickup marker: $e');
    }
  }

  Future<void> _useMyLocation() async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. Please enable GPS on your phone.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Allow location access to use GPS.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in your '
          'phone settings to use GPS.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final coordinates = LatLng(position.latitude, position.longitude);

      await _selectPickupLocation(coordinates, fromGps: true);

      final controller = _mapController;

      if (controller != null && _mapStyleLoaded) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: coordinates, zoom: 15),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          action: e.toString().contains('permanently denied')
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: Geolocator.openAppSettings,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _createRide() async {
    if (_pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use GPS or select a pickup on the map.'),
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date for the ride.')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time for the ride.')),
      );
      return;
    }

    final scheduledFor = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (!scheduledFor.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future date and time for the ride.'),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingRide = true;
    });

    try {
      await _authService.createRide(
        pickupLatitude: _pickupLocation!.latitude,
        pickupLongitude: _pickupLocation!.longitude,
        pickupAddress: _startLocationController.text.trim(),
        destinationLatitude: _destinationLocation.latitude,
        destinationLongitude: _destinationLocation.longitude,
        destinationAddress: _destination,
        availableSeats: _availableSeats,
        scheduledFor: scheduledFor,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride created successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRide = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Ride',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a Ride',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Provide the details for your ride.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            // START LOCATION
            const Text(
              'Start Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _startLocationController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Use GPS or select a location on the map',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: _pickupLocation == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear pickup',
                        onPressed: () {
                          setState(() {
                            _pickupLocation = null;
                            _startLocationController.clear();
                          });

                          final controller = _mapController;
                          if (controller != null && _pickupCircle != null) {
                            controller.removeCircle(_pickupCircle!);
                            _pickupCircle = null;
                          }
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isGettingLocation ? null : _useMyLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isGettingLocation
                      ? 'Getting your location...'
                      : 'Use My Location',
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Use GPS to select your current location automatically, '
              'or tap anywhere on the map to choose a different pickup.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),

            const SizedBox(height: 12),

            // PICKUP MAP
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    MapLibreMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(-33.88, 18.63),
                        zoom: 11.5,
                      ),
                      styleString:
                          'https://tiles.openfreemap.org/styles/bright',
                      attributionButtonPosition:
                          AttributionButtonPosition.topRight,
                      attributionButtonMargins: const math.Point(8, 8),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onStyleLoadedCallback: () {
                        _mapStyleLoaded = true;

                        final pickup = _pickupLocation;
                        if (pickup != null) {
                          _updatePickupMarker(pickup);
                        }
                      },
                      onMapClick: (point, coordinates) {
                        _selectPickupLocation(coordinates);
                      },
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),

                    // Selected pickup details
                    if (_pickupLocation != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(blurRadius: 6, color: Colors.black26),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0F6E56),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pickup selected\n'
                                    '${_coordinatesLabel(_pickupLocation!)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // DESTINATION
            const Text(
              'Destination',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _destinationController,
              enabled: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.school_outlined),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // DATE
            const Text(
              'Date of Ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Select date'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null ? Colors.grey[600] : null,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // TIME
            const Text(
              'Time of Ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_outlined),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime == null
                          ? 'Select time'
                          : _selectedTime!.format(context),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedTime == null ? Colors.grey[600] : null,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // AVAILABLE SEATS
            const Text(
              'Available Passenger Seats',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Passenger seats',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: _availableSeats > 1
                        ? () {
                            setState(() {
                              _availableSeats--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    '$_availableSeats',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _availableSeats < 8
                        ? () {
                            setState(() {
                              _availableSeats++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // CREATE RIDE
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isCreatingRide ? null : _createRide,
                icon: _isCreatingRide
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_road),
                label: Text(
                  _isCreatingRide ? 'Creating Ride...' : 'Create Ride',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

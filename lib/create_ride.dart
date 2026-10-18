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
  static const Color _movaGreen = Color(0xFF0F6E56);

  final TextEditingController _startLocationController =
      TextEditingController();

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

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  Future<void> _selectPickupLocation(
    LatLng coordinates, {
    bool fromGps = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _pickupLocation = coordinates;
      _startLocationController.text = fromGps
          ? 'Current location (${_coordinatesLabel(coordinates)})'
          : 'Selected map location (${_coordinatesLabel(coordinates)})';
    });

    await _updatePickupMarker(coordinates);

    if (!mounted) return;

    _showMessage(
      fromGps
          ? 'Your current location has been selected as the pickup.'
          : 'Pickup location updated.',
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

  Future<void> _clearPickupLocation() async {
    setState(() {
      _pickupLocation = null;
      _startLocationController.clear();
    });

    final controller = _mapController;
    final circle = _pickupCircle;

    if (controller != null && circle != null) {
      try {
        await controller.removeCircle(circle);
      } catch (_) {
        // The map may have been disposed or reloaded.
      }
      _pickupCircle = null;
    }
  }

  Future<void> _useMyLocation() async {
    if (_isGettingLocation) return;

    setState(() => _isGettingLocation = true);

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

      final message = e.toString().replaceFirst('Exception: ', '');

      _showMessage(
        message,
        actionLabel: message.contains('permanently denied') ? 'Settings' : null,
        onAction: message.contains('permanently denied')
            ? Geolocator.openAppSettings
            : null,
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate != null &&
              !_selectedDate!.isBefore(
                DateTime(today.year, today.month, today.day),
              )
          ? _selectedDate!
          : today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
    );

    if (pickedDate != null && mounted) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() => _selectedTime = pickedTime);
    }
  }

  Future<void> _createRide() async {
    if (_isCreatingRide) return;

    if (_pickupLocation == null) {
      _showMessage('Please use GPS or select a pickup on the map.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Please select a date for the ride.');
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Please select a time for the ride.');
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
      _showMessage('Please choose a future date and time for the ride.');
      return;
    }

    setState(() => _isCreatingRide = true);

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

      _showMessage('Ride created successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isCreatingRide = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
    bool filled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _movaGreen),
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _movaGreen, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _movaGreen.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _movaGreen, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: _movaGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasValue ? value : 'Select $title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasValue
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 21),
        label: Text(
          loading ? 'Please wait...' : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _movaGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _movaGreen.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final dateLabel = _selectedDate == null
        ? ''
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
              '${_selectedDate!.month.toString().padLeft(2, '0')}/'
              '${_selectedDate!.year}';

    final timeLabel = _selectedTime?.format(context) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Ride',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_movaGreen, _movaGreen.withValues(alpha: 0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _movaGreen.withValues(alpha: 0.13),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan your ride',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Choose your pickup, schedule, and available seats.',
                          style: TextStyle(
                            color: Colors.white,
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.directions_car_filled_rounded,
                    size: 47,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pickup location
            _buildSection(
              title: 'Pickup Location',
              subtitle: 'Where should your passengers meet you?',
              icon: Icons.location_on_outlined,
              children: [
                TextField(
                  controller: _startLocationController,
                  readOnly: true,
                  decoration: _inputDecoration(
                    label: 'Selected pickup',
                    icon: Icons.place_outlined,
                    hint: 'Use GPS or choose a location on the map',
                    suffixIcon: _pickupLocation == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear pickup',
                            onPressed: _clearPickupLocation,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _useMyLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _isGettingLocation
                          ? 'Getting your location...'
                          : 'Use My Location',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _movaGreen,
                      side: BorderSide(
                        color: _movaGreen.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Or tap anywhere on the map to choose a different pickup.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 14),

                // Interactive map
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    height: 270,
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
                        if (_pickupLocation != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: _movaGreen,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pickup selected',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _coordinatesLabel(_pickupLocation!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: _movaGreen,
                                      size: 20,
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
              ],
            ),

            // Destination
            _buildSection(
              title: 'Destination',
              subtitle: 'Your ride ends at the campus',
              icon: Icons.school_outlined,
              children: [
                TextField(
                  controller: _destinationController,
                  enabled: false,
                  decoration: _inputDecoration(
                    label: 'Destination',
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _movaGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        color: _movaGreen,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Eduvos Tygervalley is the fixed destination.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Schedule
            _buildSection(
              title: 'Ride Schedule',
              subtitle: 'When are you leaving?',
              icon: Icons.calendar_month_outlined,
              children: [
                _buildSelectionTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Date of ride',
                  value: dateLabel,
                  onTap: _selectDate,
                ),
                const SizedBox(height: 13),
                _buildSelectionTile(
                  icon: Icons.access_time_rounded,
                  title: 'Departure time',
                  value: timeLabel,
                  onTap: _selectTime,
                ),
              ],
            ),

            // Available seats
            _buildSection(
              title: 'Passenger Seats',
              subtitle: 'Set how many passengers you can take',
              icon: Icons.groups_outlined,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: _movaGreen.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.event_seat_outlined,
                          color: _movaGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available seats',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$_availableSeats passenger'
                              '${_availableSeats == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove seat',
                        onPressed: _availableSeats > 1
                            ? () => setState(() => _availableSeats--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: _movaGreen,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 24),
                        alignment: Alignment.center,
                        child: Text(
                          '$_availableSeats',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add seat',
                        onPressed: _availableSeats < 8
                            ? () => setState(() => _availableSeats++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: _movaGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose between 1 and 8 passenger seats.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),

            // Submit
            const SizedBox(height: 2),
            _buildPrimaryButton(
              label: 'Create Ride',
              icon: Icons.add_road_rounded,
              loading: _isCreatingRide,
              onPressed: _isCreatingRide ? null : _createRide,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Check your pickup, date, and time before creating your ride.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

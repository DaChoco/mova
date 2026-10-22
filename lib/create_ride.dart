import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'config/app_config.dart';
import '../services/auth_service.dart';

// Screen where a driver creates a ride: pick a pickup point (GPS or map tap),
// choose a date, time and number of seats. The destination is always the
// Eduvos Tygervalley campus.
class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  // Mova brand colour.
  static const Color _movaGreen = Color(0xFF0F6E56);

  // Read-only text box showing the chosen pickup.
  final TextEditingController _startLocationController =
      TextEditingController();

  // Fixed destination coordinates (the campus).
  static const LatLng _destinationLocation = LatLng(-33.8709, 18.6402);

  // Fixed destination address text.
  static const String _destination =
      'Eduvos Tygervalley, 9 Rogers St, Tyger Valley';

  // Disabled text box that displays the fixed destination.
  final TextEditingController _destinationController = TextEditingController(
    text: _destination,
  );

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  // Chosen ride date and time (null until the user picks them).
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Number of passenger seats offered (1 to 8).
  int _availableSeats = 1;

  // Chosen pickup coordinates (null until selected).
  LatLng? _pickupLocation;

  // Loading flags used to disable buttons and show spinners.
  bool _isCreatingRide = false;
  bool _isGettingLocation = false;

  // True once the map style has finished loading (markers can be drawn).
  bool _mapStyleLoaded = false;

  MapLibreMapController? _mapController;

  // The red dot currently marking the pickup on the map.
  Circle? _pickupCircle;

  @override
  void dispose() {
    // Release the text controllers.
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // Formats coordinates as "lat, lng" with 5 decimal places.
  String _coordinatesLabel(LatLng coordinates) {
    return '${coordinates.latitude.toStringAsFixed(5)}, '
        '${coordinates.longitude.toStringAsFixed(5)}';
  }

  // Shows a floating snack bar, with an optional action button.
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
        // Only add the action button when both a label and callback exist.
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  // Saves the chosen pickup, updates the text box and map marker, and
  // tells the user. [fromGps] changes the wording used.
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

  // Moves the red pickup marker on the map to the given coordinates.
  Future<void> _updatePickupMarker(LatLng coordinates) async {
    final controller = _mapController;

    // Nothing to do until the map is ready.
    if (controller == null || !_mapStyleLoaded) return;

    try {
      // Remove the old marker first so only one is ever shown.
      if (_pickupCircle != null) {
        await controller.removeCircle(_pickupCircle!);
        _pickupCircle = null;
      }

      // Red circle with a white outline.
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

  // Clears the chosen pickup and removes its marker from the map.
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

  // Uses the phone's GPS as the pickup location, after checking that
  // location services are on and permission has been granted.
  Future<void> _useMyLocation() async {
    // Ignore taps while a location request is already running.
    if (_isGettingLocation) return;

    setState(() => _isGettingLocation = true);

    try {
      // 1. Is GPS turned on?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. Please enable GPS on your phone.',
        );
      }

      // 2. Do we have permission? Ask if we haven't yet.
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Allow location access to use GPS.',
        );
      }

      // Permanently denied: the user must change it in phone settings.
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in your '
          'phone settings to use GPS.',
        );
      }

      // 3. Get the current position at high accuracy.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final coordinates = LatLng(position.latitude, position.longitude);

      await _selectPickupLocation(coordinates, fromGps: true);

      final controller = _mapController;

      // Zoom the map in on the user's location.
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

      // For permanent denial, offer a "Settings" button that opens the
      // app's system settings page.
      _showMessage(
        message,
        actionLabel: message.contains('permanently denied') ? 'Settings' : null,
        onAction: message.contains('permanently denied')
            ? Geolocator.openAppSettings
            : null,
      );
    } finally {
      // Re-enable the button.
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  // Opens the date picker. Only today up to one year ahead can be chosen.
  Future<void> _selectDate() async {
    final today = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      // Start on the previously chosen date if it is still today or later;
      // otherwise start on today.
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

  // Opens the time picker, starting at the previous choice or the current time.
  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() => _selectedTime = pickedTime);
    }
  }

  // Validates the form and sends the new ride to the backend.
  Future<void> _createRide() async {
    // Ignore taps while a request is already running.
    if (_isCreatingRide) return;

    // Make sure a pickup, date and time have all been chosen.
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

    // Combine the chosen date and time into one DateTime.
    final scheduledFor = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // The ride must be in the future.
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

      // Close this screen and tell the previous one a ride was created.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      // Re-enable the create button.
      if (mounted) {
        setState(() => _isCreatingRide = false);
      }
    }
  }

  // Shared styling for text fields on this screen.
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
      // No outline by default...
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      // ...a faint outline when enabled...
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      // ...a green outline when focused...
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _movaGreen, width: 1.5),
      ),
      // ...and a fainter outline when the field is disabled.
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // Builds a rounded card with an icon, title and subtitle at the top and
  // the given [children] underneath. Used to group related inputs.
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
          // Card header: icon badge + title and subtitle.
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
          // The section's content.
          ...children,
        ],
      ),
    );
  }

  // A tappable row (used for date and time) that shows the chosen [value],
  // or "Select <title>" while nothing has been chosen yet.
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
                    // Small label above the value.
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Chosen value, or a dimmed placeholder.
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
              // Dropdown arrow hints that the row opens a picker.
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

  // Full-width green button. Shows a spinner and "Please wait..." while
  // [loading] is true. Passing a null [onPressed] disables it.
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

    // Chosen date as dd/mm/yyyy (empty until a date is picked).
    final dateLabel = _selectedDate == null
        ? ''
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
              '${_selectedDate!.month.toString().padLeft(2, '0')}/'
              '${_selectedDate!.year}';

    // Chosen time formatted for the device's 12/24-hour setting.
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
                // Read-only box showing the selected pickup, with a clear
                // button once one has been chosen.
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
                // "Use My Location" button (disabled while locating).
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
                          // Start centred on the Tyger Valley area.
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(-33.88, 18.63),
                            zoom: 11.5,
                          ),
                          // Free OpenFreeMap "bright" map style.
                          styleString:
                              'https://tiles.openfreemap.org/styles/bright',
                          attributionButtonPosition:
                              AttributionButtonPosition.topRight,
                          attributionButtonMargins: const math.Point(8, 8),
                          // Keep a reference to the map controller.
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          // Once the style is loaded, draw the pickup marker
                          // if a pickup was already chosen.
                          onStyleLoadedCallback: () {
                            _mapStyleLoaded = true;

                            final pickup = _pickupLocation;
                            if (pickup != null) {
                              _updatePickupMarker(pickup);
                            }
                          },
                          // Tapping the map selects that point as the pickup.
                          onMapClick: (point, coordinates) {
                            _selectPickupLocation(coordinates);
                          },
                          // Let the map take priority over the page scroll
                          // so dragging the map doesn't scroll the screen.
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                        ),
                        // Small info card at the bottom of the map showing
                        // the selected coordinates. IgnorePointer lets taps
                        // pass through to the map underneath.
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
                // Disabled field: the destination can't be edited.
                TextField(
                  controller: _destinationController,
                  enabled: false,
                  decoration: _inputDecoration(
                    label: 'Destination',
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                // Note explaining that the destination is fixed.
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
                // Date picker row.
                _buildSelectionTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Date of ride',
                  value: dateLabel,
                  onTap: _selectDate,
                ),
                const SizedBox(height: 13),
                // Time picker row.
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
                // Seat counter: [-] number [+]
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
                            // Singular/plural wording: "1 passenger",
                            // "2 passengers", etc.
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
                      // Minus button (disabled at the minimum of 1).
                      IconButton(
                        tooltip: 'Remove seat',
                        onPressed: _availableSeats > 1
                            ? () => setState(() => _availableSeats--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: _movaGreen,
                      ),
                      // Current seat count.
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
                      // Plus button (disabled at the maximum of 8).
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
            // Reminder shown under the submit button.
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

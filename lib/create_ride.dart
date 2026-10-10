import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  // Read-only destination field controller (created once, disposed below)
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

  // Map marker state
  MapLibreMapController? _mapController;
  Circle? _pickupCircle;

  @override
  void dispose() {
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime today = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay initialTime = TimeOfDay.now();

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _selectPickupLocation(LatLng coordinates) async {
    setState(() {
      _pickupLocation = coordinates;
    });

    final controller = _mapController;
    if (controller != null) {
      if (_pickupCircle != null) {
        await controller.removeCircle(_pickupCircle!);
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
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pickup location selected on the map.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createRide() async {
    if (_startLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your starting address.')),
      );
      return;
    }

    if (_pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to select your pickup location.'),
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

    final DateTime scheduledFor = DateTime(
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

            // ---------------------------------------------------------
            // START LOCATION
            // ---------------------------------------------------------
            const Text(
              'Start Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _startLocationController,
              decoration: InputDecoration(
                hintText: 'Enter your starting address',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Tap the map below to select your exact pickup location.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),

            const SizedBox(height: 12),

            // ---------------------------------------------------------
            // PICKUP MAP
            // ---------------------------------------------------------
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
                      onMapCreated: (controller) => _mapController = controller,
                      onMapClick: (point, coordinates) {
                        _selectPickupLocation(coordinates);
                      },
                      // Let the map win drag gestures inside the scroll view
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),

                    // Selected coordinates
                    if (_pickupLocation != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(blurRadius: 6, color: Colors.black26),
                            ],
                          ),
                          child: Text(
                            'Pickup selected: '
                            '${_pickupLocation!.latitude.toStringAsFixed(5)}, '
                            '${_pickupLocation!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ---------------------------------------------------------
            // DESTINATION
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // DATE
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // TIME
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // AVAILABLE SEATS
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // CREATE RIDE BUTTON
            // ---------------------------------------------------------
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

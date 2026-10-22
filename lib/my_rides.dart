import 'package:flutter/material.dart';
import 'package:mova/config/app_config.dart';

import 'services/auth_service.dart';

// Lists the rides created by the logged-in driver and lets them delete
// or finish each one.
class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  // Rides returned by the backend.
  List<Map<String, dynamic>> _rides = [];

  bool _isLoading = true;

  // ID of the ride currently being deleted/finished (null when idle).
  // Used to disable the buttons and show a spinner.
  int? _deletingRideId;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  // Shows an error (or any object's text) in a snack bar, removing the
  // "Exception: " prefix so the message reads cleanly.
  void _showMessage(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }

  // Loads the driver's rides from the backend.
  Future<void> _loadRides() async {
    try {
      final rides = await _authService.getMyRides();

      if (!mounted) return;

      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage(e);
    }
  }

  // Asks for confirmation, then permanently deletes the ride.
  Future<void> _deleteRide(Map<String, dynamic> ride) async {
    final rideId = int.parse(ride['rideId'].toString());

    // Confirmation dialog: returns true only if the user taps "Delete".
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ride?'),
        content: const Text(
          'This permanently deletes the ride for you and any passengers who joined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Ride'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Cancelled or dismissed.
    if (confirmed != true) return;

    // Mark this ride as busy so the buttons are disabled.
    setState(() => _deletingRideId = rideId);

    try {
      await _authService.deleteRide(rideId);

      if (!mounted) return;

      // Remove the ride from the list without reloading everything.
      setState(() {
        _rides.removeWhere((r) => r['rideId'].toString() == '$rideId');
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ride deleted')));
    } catch (e) {
      if (!mounted) return;

      _showMessage(e);
    } finally {
      // Always clear the busy state.
      if (mounted) setState(() => _deletingRideId = null);
    }
  }

  // Asks for confirmation, then marks the ride as completed.
  Future<void> _finishRide(Map<String, dynamic> ride) async {
    final rideId = int.parse(ride['rideId'].toString());

    // Confirmation dialog: returns true only if the user taps "Complete Ride".
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete ride?'),
        content: const Text(
          'Are you sure you want to complete this ride? '
          'The ride will be removed from your active rides '
          'and will no longer be available to passengers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Ride'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Ride'),
          ),
        ],
      ),
    );

    // Cancelled or dismissed.
    if (confirmed != true) return;

    // Mark this ride as busy so the buttons are disabled.
    setState(() => _deletingRideId = rideId);

    try {
      // Uses the same backend operation as the existing Delete Ride button.
      await _authService.deleteRide(rideId);

      if (!mounted) return;

      // Remove the ride from the list without reloading everything.
      setState(() {
        _rides.removeWhere((r) => r['rideId'].toString() == '$rideId');
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ride completed')));
    } catch (e) {
      if (!mounted) return;

      _showMessage(e);
    } finally {
      // Always clear the busy state.
      if (mounted) setState(() => _deletingRideId = null);
    }
  }

  // Formats a scheduled date as "dd/mm/yyyy at HH:mm" in local time.
  // Returns "Unknown time" if the value can't be parsed.
  String _formatScheduled(dynamic scheduledFor) {
    final date = DateTime.tryParse('$scheduledFor')?.toLocal();

    if (date == null) return 'Unknown time';

    // Pads a number to two digits (e.g. 5 -> "05").
    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'at ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Rides',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // Spinner while loading, otherwise a pull-to-refresh list of rides.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRides,
              child: ListView(
                // Always scrollable so pull-to-refresh works on an empty list.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: _rides.isEmpty
                    ? [_buildEmptyState(context)]
                    : _rides
                          .map((ride) => _buildRideCard(context, ride))
                          .toList(),
              ),
            ),
    );
  }

  // Builds the card for a single ride with its details and action buttons.
  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final colorScheme = Theme.of(context).colorScheme;

    // True when this specific ride is the one being deleted/finished.
    final isDeleting = _deletingRideId.toString() == ride['rideId'].toString();

    // Helper that builds one "icon + bold label + value" row.
    Widget line(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
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
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Ride',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          // Pickup address.
          line(
            Icons.location_on_outlined,
            'Pickup',
            ride['pickupAddress']?.toString() ?? 'Unknown',
          ),
          // Destination address.
          line(
            Icons.school_outlined,
            'Destination',
            ride['destinationAddress']?.toString() ?? 'Unknown',
          ),
          // Date and time of the ride.
          line(
            Icons.access_time_outlined,
            'Scheduled',
            _formatScheduled(ride['scheduledFor']),
          ),
          // Seats still available.
          line(
            Icons.people_outline,
            'Seats',
            '${ride['availableSeats'] ?? 'Unknown'} available',
          ),
          // Number of accepted and pending passenger requests.
          line(
            Icons.how_to_reg_outlined,
            'Passengers',
            '${ride['acceptedCount'] ?? 0} accepted, '
                '${ride['pendingCount'] ?? 0} pending',
          ),
          const SizedBox(height: 18),

          // Delete Ride + Finish Ride buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // Disabled while any ride is being deleted/finished.
                  onPressed: _deletingRideId != null
                      ? null
                      : () => _deleteRide(ride),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size(0, 46),
                  ),
                  // Show a spinner on this card while it is being deleted.
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Ride'),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  // Disabled while any ride is being deleted/finished.
                  onPressed: _deletingRideId != null
                      ? null
                      : () => _finishRide(ride),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finish Ride'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Placeholder shown when the driver hasn't created any rides yet.
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          // Circular icon badge.
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 45,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No rides yet',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your created rides will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

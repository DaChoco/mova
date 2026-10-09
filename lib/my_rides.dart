import 'package:flutter/material.dart';

import 'services/auth_service.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  List<Map<String, dynamic>> _rides = [];

  bool _isLoading = true;
  int? _deletingRideId;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  void _showMessage(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }

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

  Future<void> _deleteRide(Map<String, dynamic> ride) async {
    final rideId = int.parse(ride['rideId'].toString());

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

    if (confirmed != true) return;

    setState(() => _deletingRideId = rideId);

    try {
      await _authService.deleteRide(rideId);

      if (!mounted) return;

      setState(() {
        _rides.removeWhere((r) => r['rideId'].toString() == '$rideId');
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ride deleted')));
    } catch (e) {
      if (!mounted) return;

      _showMessage(e);
    } finally {
      if (mounted) setState(() => _deletingRideId = null);
    }
  }

  String _formatScheduled(dynamic scheduledFor) {
    final date = DateTime.tryParse('$scheduledFor')?.toLocal();

    if (date == null) return 'Unknown time';

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRides,
              child: ListView(
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

  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDeleting = _deletingRideId.toString() == ride['rideId'].toString();

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
          line(
            Icons.location_on_outlined,
            'Pickup',
            ride['pickupAddress']?.toString() ?? 'Unknown',
          ),
          line(
            Icons.school_outlined,
            'Destination',
            ride['destinationAddress']?.toString() ?? 'Unknown',
          ),
          line(
            Icons.access_time_outlined,
            'Scheduled',
            _formatScheduled(ride['scheduledFor']),
          ),
          line(
            Icons.people_outline,
            'Seats',
            '${ride['availableSeats'] ?? 'Unknown'} available',
          ),
          line(
            Icons.how_to_reg_outlined,
            'Passengers',
            '${ride['acceptedCount'] ?? 0} accepted, '
                '${ride['pendingCount'] ?? 0} pending',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _deletingRideId != null
                  ? null
                  : () => _deleteRide(ride),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'profile_screen.dart';
import 'main.dart';
import 'find_driver_screen.dart';
import 'find_passenger.dart';
import 'chat_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';
import 'create_ride.dart';
import 'my_rides.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late User _user;

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  Map<String, dynamic>? _upcomingRide;
  bool _isLoadingRide = true;
  Timer? _rideRefreshTimer;

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    // Load the profile picture as soon as the home screen starts,
    // so the drawer shows it without opening the profile screen first.
    if (_user.profileIcon != null && _user.profileIcon!.isNotEmpty) {
      String profileURL =
          '${AppConfig.supabaseBucketBaseUrl}/${_user.profileIcon}';
      print(profileURL);
      loadProfileImage(profileURL);
    } else {
      // The login response may not include profileIcon, so fetch the
      // full user from the backend to get it.
      _refreshUser();
    }

    _loadUpcomingRide();

    // The driver accepts requests on another device, so poll for changes.
    _rideRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUpcomingRide(),
    );
  }

  @override
  void dispose() {
    _rideRefreshTimer?.cancel();
    super.dispose();
  }

  // The next ride a driver has accepted this user on as a passenger.
  // Rides the user created themselves are not shown here.
  Future<void> _loadUpcomingRide() async {
    try {
      final ride = await _authService.getAcceptedRide();

      if (!mounted) return;

      setState(() {
        _upcomingRide = ride;
        _isLoadingRide = false;
      });
    } catch (_) {
      if (!mounted) return;

      // Keep the last known ride if a refresh fails.
      setState(() => _isLoadingRide = false);
    }
  }

  String _formatScheduled(dynamic scheduledFor) {
    final date = DateTime.tryParse('$scheduledFor')?.toLocal();

    if (date == null) return 'Unknown time';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'at ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _buildUpcomingRide(ColorScheme colorScheme) {
    if (_isLoadingRide) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final ride = _upcomingRide;

    if (ride == null) {
      return Center(
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_outlined,
                color: colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No upcoming rides',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              'Your next ride will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final pickup = ride['pickupAddress']?.toString() ?? 'Unknown pickup';
    final destination =
        ride['destinationAddress']?.toString() ?? 'Unknown destination';

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver accepted your request',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
        line(Icons.location_on_outlined, pickup),
        line(Icons.school_outlined, destination),
        line(
          Icons.access_time_outlined,
          _formatScheduled(ride['scheduledFor']),
        ),
        if (ride['driverName'] != null)
          line(Icons.person_outline, 'Driver: ${ride['driverName']}'),
      ],
    );
  }

  // Get the latest user information from the backend.
  Future<void> _refreshUser() async {
    try {
      final updatedUser = await _authService.getUser();

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
      });

      loadProfileImage(updatedUser.profileIcon);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Profile section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ValueListenableBuilder<Uint8List?>(
                      valueListenable: profileImageNotifier,
                      builder: (context, image, child) {
                        return CircleAvatar(
                          radius: 45,
                          backgroundImage: image != null
                              ? MemoryImage(image)
                              : null,
                          child: image == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '${_user.firstName} ${_user.surname}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _user.studentNumber,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Edit Profile
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 150));

                    if (!context.mounted) return;

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: _user),
                      ),
                    );

                    // ProfileScreen may have changed the user's role.
                    // Get the latest user data when we return.
                    await _refreshUser();
                  },
                  child: const ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Profile', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),

              // My Rides (drivers only)
              if (_user.isDriver)
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('My Rides', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyRidesScreen(),
                      ),
                    );
                  },
                ),

              // Dark Mode
              ValueListenableBuilder<bool>(
                valueListenable: themeModeNotifier,
                builder: (context, isDarkMode, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontSize: 16),
                    ),
                    value: isDarkMode,
                    onChanged: (value) {
                      themeModeNotifier.value = value;
                    },
                  );
                },
              ),

              // Logout
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout', style: TextStyle(fontSize: 16)),
                onTap: () async {
                  await _authService.logout();

                  // Clear the shared image so the next user to log in
                  // doesn't briefly see this user's picture.
                  profileImageNotifier.value = null;

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Mova',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ),

      // App Bar
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // Home Body
      body: RefreshIndicator(
        onRefresh: _loadUpcomingRide,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 5),

              Text(
                'What would you like to do today?',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 25),

              // Driver buttons
              if (_user.isDriver) ...[
                // Find a Driver
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindDriverScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions_car),
                    label: const Text(
                      'Find a Driver',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Find a Passenger
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindPassengerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_search),
                    label: const Text(
                      'Find a Passenger',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Create Rides
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateRideScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_road),
                    label: const Text(
                      'Create Rides',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Passenger - Find Rides
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindDriverScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text(
                      'Find Rides',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Messages
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatsScreen(
                            currentUserId: _user.userId.toString(),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          // Message icon
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Message text
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Messages',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Your ride conversations',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Arrow
                          const Icon(Icons.arrow_forward_ios_rounded, size: 17),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Upcoming Ride information
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section title
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            'Upcoming Ride',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Upcoming ride (or empty state)
                      _buildUpcomingRide(colorScheme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

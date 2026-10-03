import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'main.dart';
import 'find_driver_screen.dart';
import 'find_passenger.dart';
import 'chat_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

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
                      '${user.firstName} ${user.surname}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      user.studentNumber,
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

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: user),
                      ),
                    );
                  },
                  child: const ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Profile', style: TextStyle(fontSize: 16)),
                  ),
                ),
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
                  final authService = AuthService(
                    baseUrl: 'http://26.223.171.250:80',
                  );

                  await authService.logout();

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
                  'Carpool App',
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
      body: Padding(
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
            if (user.isDriver) ...[
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                    // Create Ride screen will be added here later.
                  },
                  icon: const Icon(Icons.add_road),
                  label: const Text(
                    'Create Rides',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                        builder: (context) =>
                            ChatsScreen(currentUserId: user.userId.toString()),
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
                            color: colorScheme.primary.withValues(alpha: 0.12),
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
                        Icon(Icons.arrow_forward_ios_rounded, size: 17),
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

                    // Empty ride state
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            'Your next ride will appear here',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

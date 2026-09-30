import 'dart:io';

import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'main.dart';
import 'message_screen.dart';
import 'find_driver_screen.dart';
import 'find_passenger.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Profile section
              ValueListenableBuilder<UserSession?>(
                valueListenable: currentUserNotifier,
                builder: (context, user, child) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ValueListenableBuilder<File?>(
                          valueListenable: profileImageNotifier,
                          builder: (context, image, child) {
                            return CircleAvatar(
                              radius: 45,
                              backgroundImage: image != null
                                  ? FileImage(image)
                                  : null,
                              child: image == null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        Text(
                          user != null ? '${user.name} ${user.surname}' : '-',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          user?.studentNumber ?? '-',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                        builder: (context) => const ProfileScreen(),
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
                onTap: () {
                  print('Logout pressed');
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

            const SizedBox(height: 30),

            const Text(
              'Recent Messages',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            // Recent Messages
            Expanded(
              child: ListView(
                children: [
                  // Message 1
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: const Text(
                          'John Doe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Hey, are you still looking for a ride?',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MessageScreen(
                                conversationId: 'test-conversation-id',
                                currentUserId: 'test-user-id',
                                otherUserName: 'John Doe',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Message 2
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: const Text(
                          'Jane Smith',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Thanks! I will let you know.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          print('Jane Smith message pressed');
                        },
                      ),
                    ),
                  ),

                  // Message 3
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: const Text(
                          'John Doe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('See you tomorrow!'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          print('John Doe message pressed');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

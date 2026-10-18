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
import 'services/chat_service.dart' as chat;
import 'login_screen.dart';
import 'create_ride.dart';
import 'my_rides.dart';
import 'terms_and_conditions.dart';

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

  final chat.ChatService _chatService = chat.ChatService();

  static const Color _movaGreen = Color(0xFF0F6E56);

  Map<String, dynamic>? _upcomingRide;
  bool _isLoadingRide = true;
  int _unreadMessages = 0;
  Timer? _rideRefreshTimer;

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    if (_user.profileIcon != null && _user.profileIcon!.isNotEmpty) {
      final profileURL =
          '${AppConfig.supabaseBucketBaseUrl}/${_user.profileIcon}';
      loadProfileImage(profileURL);
    } else {
      _refreshUser();
    }

    _loadUpcomingRide();
    _loadUnreadMessages();

    chat.chatsChanged.addListener(_loadUnreadMessages);

    _rideRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUpcomingRide();
      _loadUnreadMessages();
    });
  }

  @override
  void dispose() {
    _rideRefreshTimer?.cancel();
    chat.chatsChanged.removeListener(_loadUnreadMessages);
    super.dispose();
  }

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

      setState(() => _isLoadingRide = false);
    }
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final total = await _chatService.getUnreadTotal();

      if (!mounted) return;

      setState(() => _unreadMessages = total);
    } catch (_) {
      // Keep the last known unread count.
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No upcoming rides',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your next ride will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pickup = ride['pickupAddress']?.toString() ?? 'Unknown pickup';
    final destination =
        ride['destinationAddress']?.toString() ?? 'Unknown destination';

    Widget line(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Request accepted',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
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
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();

    profileImageNotifier.value = null;

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 62,
      child: primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 23),
              label: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _movaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
                backgroundColor: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_movaGreen, _movaGreen.withValues(alpha: 0.82)],
                  ),
                ),
                child: Column(
                  children: [
                    ValueListenableBuilder<Uint8List?>(
                      valueListenable: profileImageNotifier,
                      builder: (context, image, child) {
                        return Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD1FAEB),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage: image != null
                                ? MemoryImage(image)
                                : null,
                            child: image == null
                                ? const Icon(
                                    Icons.person_outline,
                                    size: 44,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${_user.firstName} ${_user.surname}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user.studentNumber,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: Color(0xFFD1FAEB),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text(
                  'Edit Profile',
                  style: TextStyle(fontFamily: 'Nunito'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  await Future.delayed(const Duration(milliseconds: 150));

                  if (!context.mounted) return;

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(user: _user),
                    ),
                  );

                  await _refreshUser();
                },
              ),

              if (_user.isDriver)
                ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: const Text(
                    'My Rides',
                    style: TextStyle(fontFamily: 'Nunito'),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyRidesScreen(),
                      ),
                    );
                  },
                ),

              ValueListenableBuilder<bool>(
                valueListenable: themeModeNotifier,
                builder: (context, isDarkMode, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontFamily: 'Nunito'),
                    ),
                    value: isDarkMode,
                    activeThumbColor: _movaGreen,
                    onChanged: (value) {
                      themeModeNotifier.value = value;
                    },
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text(
                  'Terms & Conditions',
                  style: TextStyle(fontFamily: 'Nunito'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsAndConditionsScreen(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text(
                  'Logout',
                  style: TextStyle(fontFamily: 'Nunito'),
                ),
                iconColor: colorScheme.error,
                textColor: colorScheme.error,
                onTap: _logout,
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: _movaGreen,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Mova',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      appBar: AppBar(
        title: const Text(
          'Mova',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ValueListenableBuilder<Uint8List?>(
              valueListenable: profileImageNotifier,
              builder: (context, image, child) {
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: image != null ? MemoryImage(image) : null,
                  child: image == null
                      ? Icon(
                          Icons.person_outline,
                          color: colorScheme.primary,
                          size: 21,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _movaGreen.withValues(alpha: isDark ? 0.10 : 0.035),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.38],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () =>
              Future.wait([_loadUpcomingRide(), _loadUnreadMessages()]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome banner.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F6E56), Color(0xFF084C3B)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: _movaGreen.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WELCOME TO MOVA',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: Color(0xFFD1FAEB),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Hey, ${_user.firstName}!',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Where are you heading today?',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: Color(0xFFE0F2EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          size: 36,
                          color: Color(0xFFD1FAEB),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Your next move',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _user.isDriver
                      ? 'Find passengers or organise your next ride.'
                      : 'Campus Rides, Shared.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 18),

                if (_user.isDriver) ...[
                  _buildActionButton(
                    context: context,
                    icon: Icons.search_rounded,
                    label: 'Find a Driver',
                    primary: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindDriverScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.person_search_rounded,
                    label: 'Find a Passenger',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindPassengerScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.add_road_rounded,
                    label: 'Create a Ride',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateRideScreen(),
                        ),
                      );
                    },
                  ),
                ] else
                  _buildActionButton(
                    context: context,
                    icon: Icons.search_rounded,
                    label: 'Find Rides',
                    primary: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindDriverScreen(),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 30),

                // Messages.
                _buildSectionCard(
                  context: context,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatsScreen(
                              currentUserId: _user.userId.toString(),
                            ),
                          ),
                        ).then((_) => _loadUnreadMessages());
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: colorScheme.primary,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Messages',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Your ride conversations',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_unreadMessages > 0) ...[
                            UnreadBadge(count: _unreadMessages),
                            const SizedBox(width: 10),
                          ],
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 17,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Upcoming ride.
                _buildSectionCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.calendar_month_outlined,
                              size: 22,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Upcoming Ride',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildUpcomingRide(colorScheme),
                    ],
                  ),
                ),

                // Driver reminder.
                if (_user.isDriver) ...[
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    context: context,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 23,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remember to finish your ride',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Once your ride is completed, open My Rides and tap Finish Ride.',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  height: 1.45,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Mova',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

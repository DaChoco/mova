import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/auth.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

// Shared so the profile screen and the drawer show the same picture
final ValueNotifier<File?> profileImageNotifier = ValueNotifier(null);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _carController = TextEditingController();
  final _colourController = TextEditingController();
  final _plateController = TextEditingController();
  final _seatsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  User? _user;
  bool _isLoadingUser = true;

  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  String _role = 'Passenger';
  bool _isDriverLocked = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getUser();

      if (!mounted) return;

      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingUser = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _carController.dispose();
    _colourController.dispose();
    _plateController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked != null) {
      profileImageNotifier.value = File(picked.path);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSave() async {
    // Password validation
    final changingPassword =
        _oldPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;

    if (changingPassword &&
        (_oldPasswordController.text.isEmpty ||
            _newPasswordController.text.isEmpty ||
            _newPasswordController.text != _confirmPasswordController.text)) {
      _showMessage('Enter your old password and make sure the new ones match');
      return;
    }

    // Driver validation + confirmation
    if (_role == 'Driver' && !_isDriverLocked) {
      if (_carController.text.trim().isEmpty ||
          _colourController.text.trim().isEmpty ||
          _plateController.text.trim().isEmpty ||
          _seatsController.text.trim().isEmpty) {
        _showMessage('Please fill in all driver details');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Become a driver?'),
          content: const Text(
            'Once you switch to driver you will not be able to switch back to passenger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() {
        _isDriverLocked = true;
      });
    }

    _showMessage('Profile saved — backend not wired yet');
  }

  Future<void> _handleLogOut() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoadingUser
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile picture
                    Center(child: _buildAvatarPicker()),

                    const SizedBox(height: 12),

                    const Center(
                      child: Text(
                        'Tap your picture to change it',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // User details
                    _buildInfoField(
                      'Name',
                      _user?.firstName ?? '-',
                      Icons.person_outline,
                    ),

                    const SizedBox(height: 20),

                    _buildInfoField(
                      'Surname',
                      _user?.surname ?? '-',
                      Icons.person_outline,
                    ),

                    const SizedBox(height: 20),

                    _buildInfoField(
                      'Student Number',
                      _user?.studentNumber ?? '-',
                      Icons.badge_outlined,
                    ),

                    const SizedBox(height: 20),

                    // Email is not currently returned by GET /api/user/{id}
                    _buildInfoField('Student Email', '-', Icons.email_outlined),

                    const SizedBox(height: 30),

                    // Change password
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildLabeledField(
                      label: 'Old Password',
                      controller: _oldPasswordController,
                      icon: Icons.lock_outline,
                      obscureText: _hideOld,
                      suffixIcon: _visibilityToggle(
                        _hideOld,
                        () => setState(() => _hideOld = !_hideOld),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildLabeledField(
                      label: 'New Password',
                      controller: _newPasswordController,
                      icon: Icons.lock_outline,
                      obscureText: _hideNew,
                      suffixIcon: _visibilityToggle(
                        _hideNew,
                        () => setState(() => _hideNew = !_hideNew),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildLabeledField(
                      label: 'Confirm New Password',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      obscureText: _hideConfirm,
                      suffixIcon: _visibilityToggle(
                        _hideConfirm,
                        () => setState(() => _hideConfirm = !_hideConfirm),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Role dropdown
                    const Text(
                      'I am a',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Passenger',
                          enabled: !_isDriverLocked,
                          child: const Text('Passenger'),
                        ),
                        const DropdownMenuItem(
                          value: 'Driver',
                          child: Text('Driver'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _role = value;
                          });
                        }
                      },
                    ),

                    // Driver details
                    if (_role == 'Driver') ...[
                      const SizedBox(height: 30),

                      const Text(
                        'Driver Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildLabeledField(
                        label: 'Car Make & Model',
                        controller: _carController,
                        icon: Icons.directions_car_outlined,
                      ),

                      const SizedBox(height: 20),

                      _buildLabeledField(
                        label: 'Car Colour',
                        controller: _colourController,
                        icon: Icons.palette_outlined,
                      ),

                      const SizedBox(height: 20),

                      _buildLabeledField(
                        label: 'Number Plate',
                        controller: _plateController,
                        icon: Icons.pin_outlined,
                      ),

                      const SizedBox(height: 20),

                      _buildLabeledField(
                        label: 'Available Seats',
                        controller: _seatsController,
                        icon: Icons.event_seat_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Save button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Log out button
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _handleLogOut,
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        children: [
          ValueListenableBuilder<File?>(
            valueListenable: profileImageNotifier,
            builder: (context, image, child) {
              return CircleAvatar(
                radius: 55,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                backgroundImage: image != null ? FileImage(image) : null,
                child: image == null
                    ? Icon(
                        Icons.person,
                        size: 55,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : null,
              );
            },
          ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                size: 17,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visibilityToggle(bool hidden, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
      onPressed: onPressed,
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.onSurfaceVariant),

              const SizedBox(width: 12),

              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
            hintText: 'Enter your $label',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

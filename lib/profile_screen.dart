import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Shared profile image notifier.
// HomeScreen can use this later as well.
final ValueNotifier<Uint8List?> profileImageNotifier =
    ValueNotifier<Uint8List?>(null);

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _user;

  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  bool _isUploadingImage = false;

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _carRegistrationController =
      TextEditingController();

  final TextEditingController _carModelController = TextEditingController();

  String _selectedRole = 'Passenger';

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _passwordError;

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    _loadProfilePicture();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _carRegistrationController.dispose();
    _carModelController.dispose();

    super.dispose();
  }

  Future<void> _loadProfilePicture() async {
    try {
      // No profile picture has been uploaded yet.
      if (_user.profileIcon == null || _user.profileIcon!.isEmpty) {
        return;
      }

      final response = await http.get(Uri.parse(_user.profileIcon!));

      if (response.statusCode != 200) {
        return;
      }

      if (!mounted) return;

      profileImageNotifier.value = response.bodyBytes;
    } catch (_) {
      // If the image cannot be loaded, keep the default person icon.
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Upload the XFile directly to the backend.
      final imageUrl = await _authService.uploadProfilePicture(image);

      // Read the image bytes so it can be displayed on
      // both Chrome and Android.
      final imageBytes = await image.readAsBytes();

      profileImageNotifier.value = imageBytes;

      // Update the local User object with the URL returned
      // by the backend.
      _user = User(
        userId: _user.userId,
        studentNumber: _user.studentNumber,
        firstName: _user.firstName,
        surname: _user.surname,
        carID: _user.carID,
        profileIcon: imageUrl,
      );

      if (!mounted) return;

      setState(() {
        _isUploadingImage = false;
      });

      _showMessage('Profile picture updated');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingImage = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validatePasswords() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _passwordError = 'Please fill in all password fields.';
      });

      return false;
    }

    if (newPassword.length < 6) {
      setState(() {
        _passwordError = 'New password must be at least 6 characters.';
      });

      return false;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _passwordError = 'Passwords do not match.';
      });

      return false;
    }

    setState(() {
      _passwordError = null;
    });

    return true;
  }

  Future<void> _changePassword() async {
    if (!_validatePasswords()) {
      return;
    }

    try {
      await _authService.changePassword(
        ChangePasswordRequest(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        ),
      );

      if (!mounted) return;

      _showMessage('Password changed successfully');

      await _authService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Greyed-out, read-only field for data the user cannot change.
  Widget _buildInfoField(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IgnorePointer(
        child: TextFormField(
          // Key on value so the field updates if the data changes.
          key: ValueKey('$label:$value'),
          initialValue: value,
          readOnly: true,
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              icon,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = _selectedRole == 'Driver';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------
            // PROFILE PICTURE
            // -------------------------------------------------
            ValueListenableBuilder<Uint8List?>(
              valueListenable: profileImageNotifier,
              builder: (context, image, child) {
                return Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: image != null
                            ? MemoryImage(image)
                            : null,
                        child: image == null
                            ? const Icon(Icons.person, size: 65)
                            : null,
                      ),

                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          child: _isUploadingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 20),
                                  onPressed: _pickProfileImage,
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // -------------------------------------------------
            // PERSONAL INFORMATION (greyed out, read-only)
            // -------------------------------------------------
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildInfoField(
              'First Name',
              _user.firstName,
              Icons.person_outline,
            ),

            _buildInfoField('Surname', _user.surname, Icons.person_outline),

            _buildInfoField(
              'Student Number',
              _user.studentNumber,
              Icons.badge_outlined,
            ),

            _buildInfoField(
              'Student Email',
              '${_user.studentNumber}@vossie.net',
              Icons.email_outlined,
            ),

            const SizedBox(height: 14),

            // -------------------------------------------------
            // CHANGE PASSWORD
            // -------------------------------------------------
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                errorText: _passwordError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.withValues(alpha: 0.15),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your new password must be at least 6 characters long. '
                      'Changing your password will sign you out.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changePassword,
                child: const Text('Change Password'),
              ),
            ),

            const SizedBox(height: 30),

            // -------------------------------------------------
            // ACCOUNT ROLE
            // -------------------------------------------------
            const Text(
              'Account Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.account_circle_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Driver', child: Text('Driver')),
                DropdownMenuItem(value: 'Passenger', child: Text('Passenger')),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedRole = value;
                });
              },
            ),

            // -------------------------------------------------
            // DRIVER DETAILS (only when role is Driver)
            // -------------------------------------------------
            if (isDriver) ...[
              const SizedBox(height: 28),

              const Text(
                'Driver Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _carRegistrationController,
                decoration: const InputDecoration(
                  labelText: 'Car Registration',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: _carModelController,
                decoration: const InputDecoration(
                  labelText: 'Car Model',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

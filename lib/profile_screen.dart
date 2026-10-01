import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/auth.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

final ValueNotifier<File?> profileImageNotifier = ValueNotifier(null);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService(
    baseUrl: 'http://26.223.171.250:80',
  );

  User? _user;
  bool _isLoadingUser = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _studentNumberController = TextEditingController();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirm = true;

  String _selectedRole = 'Passenger';

  final _carMakeController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carRegistrationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _newPasswordController.addListener(_passwordChanged);
    _confirmPasswordController.addListener(_passwordChanged);

    _loadUser();
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_passwordChanged);
    _confirmPasswordController.removeListener(_passwordChanged);

    _nameController.dispose();
    _surnameController.dispose();
    _studentNumberController.dispose();

    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _carMakeController.dispose();
    _carModelController.dispose();
    _carRegistrationController.dispose();

    super.dispose();
  }

  void _passwordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _passwordsDoNotMatch {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty && confirmPassword.isEmpty) {
      return false;
    }

    return newPassword != confirmPassword;
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getUser();

      if (!mounted) return;

      setState(() {
        _user = user;

        _nameController.text = user.firstName;
        _surnameController.text = user.surname;
        _studentNumberController.text = user.studentNumber;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    profileImageNotifier.value = File(image.path);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final changingPassword =
        _oldPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;

    // ---------------------------------------------------------
    // PASSWORD VALIDATION
    // ---------------------------------------------------------

    if (changingPassword) {
      if (_oldPasswordController.text.isEmpty) {
        _showMessage('Please enter your old password');
        return;
      }

      if (_newPasswordController.text.isEmpty) {
        _showMessage('Please enter a new password');
        return;
      }

      if (_confirmPasswordController.text.isEmpty) {
        _showMessage('Please confirm your new password');
        return;
      }

      if (_newPasswordController.text.length < 6) {
        _showMessage('New password must be at least 6 characters.');
        return;
      }

      if (_passwordsDoNotMatch) {
        return;
      }

      // -------------------------------------------------------
      // CHANGE PASSWORD THROUGH BACKEND
      // -------------------------------------------------------

      setState(() {
        _isSaving = true;
      });

      try {
        final request = ChangePasswordRequest(
          currentPassword: _oldPasswordController.text,
          newPassword: _newPasswordController.text,
        );

        await _authService.changePassword(request);

        // The backend revokes the user's active refresh tokens
        // after successfully changing the password.
        //
        // Clear the local JWT and refresh token as well.
        await _authService.logout();

        if (!mounted) return;

        // Return to login because the user must authenticate
        // again using the new password.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );

        return;
      } catch (e) {
        if (!mounted) return;

        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }

      return;
    }

    _showMessage('No profile changes were made.');
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

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          errorText: errorText,
          border: const OutlineInputBorder(),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
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
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -------------------------------------------------
              // PROFILE PICTURE
              // -------------------------------------------------

              ValueListenableBuilder<File?>(
                valueListenable: profileImageNotifier,
                builder: (context, image, child) {
                  return Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: image != null
                              ? FileImage(image)
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
                            child: IconButton(
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
              // PERSONAL INFORMATION
              // -------------------------------------------------
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              _buildInfoField(
                'First Name',
                _user?.firstName ?? '-',
                Icons.person_outline,
              ),

              _buildInfoField(
                'Surname',
                _user?.surname ?? '-',
                Icons.person_outline,
              ),

              _buildInfoField(
                'Student Number',
                _user?.studentNumber ?? '-',
                Icons.badge_outlined,
              ),

              _buildInfoField(
                'Student Email',
                _user?.studentNumber != null
                    ? '${_user!.studentNumber}@vossie.net'
                    : '-',
                Icons.email_outlined,
              ),

              const SizedBox(height: 18),

              // -------------------------------------------------
              // CHANGE PASSWORD
              // -------------------------------------------------
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Password warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline
                        .withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Changing your password will sign you out. '
                        'You will need to log in again with your new password.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'Old Password',
                controller: _oldPasswordController,
                icon: Icons.lock_outline,
                obscureText: _hideOldPassword,
                enabled: !_isSaving,
                suffixIcon: _visibilityToggle(_hideOldPassword, () {
                  setState(() {
                    _hideOldPassword = !_hideOldPassword;
                  });
                }),
              ),

              _buildLabeledField(
                label: 'New Password',
                controller: _newPasswordController,
                icon: Icons.lock_outline,
                obscureText: _hideNewPassword,
                enabled: !_isSaving,
                suffixIcon: _visibilityToggle(_hideNewPassword, () {
                  setState(() {
                    _hideNewPassword = !_hideNewPassword;
                  });
                }),
              ),

              _buildLabeledField(
                label: 'Confirm New Password',
                controller: _confirmPasswordController,
                icon: Icons.lock_outline,
                obscureText: _hideConfirm,
                enabled: !_isSaving,
                errorText: _passwordsDoNotMatch
                    ? 'Passwords do not match'
                    : null,
                suffixIcon: _visibilityToggle(_hideConfirm, () {
                  setState(() {
                    _hideConfirm = !_hideConfirm;
                  });
                }),
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------
              // ACCOUNT ROLE
              // -------------------------------------------------
              const Text(
                'Account Role',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.account_circle_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Driver', child: Text('Driver')),
                  DropdownMenuItem(
                    value: 'Passenger',
                    child: Text('Passenger'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedRole = value;
                        });
                      },
              ),

              // -------------------------------------------------
              // DRIVER DETAILS (only when role is Driver)
              // -------------------------------------------------
              if (_selectedRole == 'Driver') ...[
                const SizedBox(height: 28),

                const Text(
                  'Driver Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                _buildLabeledField(
                  label: 'Car Make',
                  controller: _carMakeController,
                  icon: Icons.directions_car_outlined,
                  enabled: !_isSaving,
                ),

                _buildLabeledField(
                  label: 'Car Model',
                  controller: _carModelController,
                  icon: Icons.directions_car_outlined,
                  enabled: !_isSaving,
                ),

                _buildLabeledField(
                  label: 'Car Registration',
                  controller: _carRegistrationController,
                  icon: Icons.confirmation_number_outlined,
                  enabled: !_isSaving,
                ),
              ],

              const SizedBox(height: 24),

              // -------------------------------------------------
              // SAVE CHANGES
              // -------------------------------------------------
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------
              // LOGOUT
              // -------------------------------------------------
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleLogOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

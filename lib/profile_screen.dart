import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mova/config/app_config.dart';

import '../models/auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Shared profile image notifier.
// HomeScreen listens to this for the drawer avatar.
final ValueNotifier<Uint8List?> profileImageNotifier =
    ValueNotifier<Uint8List?>(null);

// Downloads the profile picture from [url] and stores it in
// [profileImageNotifier].
Future<void> loadProfileImage(String? url) async {
  // No URL means no picture: clear the shared image.
  if (url == null || url.isEmpty) {
    profileImageNotifier.value = null;
    return;
  }

  try {
    final response = await http.get(Uri.parse(url));

    // Only update the image when the download succeeded.
    if (response.statusCode == 200) {
      profileImageNotifier.value = response.bodyBytes;
    }
  } catch (_) {
    // Keep the existing image if loading fails.
  }
}

// Profile page: shows the user's details, and lets them change their
// profile picture, password and account role (driver or passenger).
class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mova brand colour.
  static const Color _movaGreen = Color(0xFF0F6E56);

  // Local copy of the user so it can be updated on this screen.
  late User _user;

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  // Loading flags used to disable buttons and show spinners.
  bool _isUploadingImage = false;
  bool _isSavingRole = false;
  bool _isChangingPassword = false;

  // Controllers for the password fields.
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Controllers for the driver's car details.
  final TextEditingController _carRegistrationController =
      TextEditingController();
  final TextEditingController _carModelController = TextEditingController();

  // Role currently selected in the dropdown ('Driver' or 'Passenger').
  String _selectedRole = 'Passenger';

  // Whether each password field's text is hidden.
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Validation error shown under the confirm password field.
  String? _passwordError;

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    // Start the dropdown on the user's current role.
    _selectedRole = _user.isDriver ? 'Driver' : 'Passenger';

    // Load the profile picture if one hasn't been loaded already.
    if (profileImageNotifier.value == null) {
      final profileURL =
          '${AppConfig.supabaseBucketBaseUrl}/${_user.profileIcon}';
      loadProfileImage(profileURL);
    }
  }

  @override
  void dispose() {
    // Release all text controllers.
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _carRegistrationController.dispose();
    _carModelController.dispose();
    super.dispose();
  }

  // Shows a floating snack bar with the given message.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Saves the chosen account role. Choosing Driver requires both a car
  // registration and a car model.
  Future<void> _saveAccountRole() async {
    // Ignore taps while a save is already running.
    if (_isSavingRole) return;

    final carRegistration = _carRegistrationController.text.trim();
    final carModel = _carModelController.text.trim();

    // The user only counts as a driver if Driver is selected AND both car
    // fields are filled in.
    final bool isDriver =
        _selectedRole == 'Driver' &&
        carRegistration.isNotEmpty &&
        carModel.isNotEmpty;

    // Driver was chosen but the car details are missing.
    if (_selectedRole == 'Driver' && !isDriver) {
      _showMessage('Please enter your car registration and model.');
      return;
    }

    setState(() => _isSavingRole = true);

    try {
      await _authService.updateDriverStatus(
        userId: _user.userId,
        isDriver: isDriver,
      );

      if (!mounted) return;

      // Rebuild the local user with the new driver status.
      setState(() {
        _user = User(
          userId: _user.userId,
          studentNumber: _user.studentNumber,
          firstName: _user.firstName,
          surname: _user.surname,
          isDriver: isDriver,
          carID: _user.carID,
          profileIcon: _user.profileIcon,
        );
        _selectedRole = isDriver ? 'Driver' : 'Passenger';
        _isSavingRole = false;
      });

      _showMessage(
        isDriver ? 'Account updated to Driver' : 'Account updated to Passenger',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSavingRole = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Lets the user choose a photo from the gallery, uploads it and updates
  // the shared profile image.
  Future<void> _pickProfileImage() async {
    // Ignore taps while an upload is already running.
    if (_isUploadingImage) return;

    try {
      final picker = ImagePicker();

      // Open the gallery (compressed to 85% quality).
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      // User cancelled the picker.
      if (image == null || !mounted) return;

      setState(() => _isUploadingImage = true);

      // Upload to the backend, and read the bytes to show it immediately.
      final imageUrl = await _authService.uploadProfilePicture(image);
      final imageBytes = await image.readAsBytes();

      // Update every avatar in the app that listens to this notifier.
      profileImageNotifier.value = imageBytes;

      // Keep the local user in sync with the new picture.
      _user = User(
        userId: _user.userId,
        studentNumber: _user.studentNumber,
        firstName: _user.firstName,
        surname: _user.surname,
        carID: _user.carID,
        isDriver: _user.isDriver,
        profileIcon: imageUrl,
      );

      if (!mounted) return;

      setState(() => _isUploadingImage = false);
      _showMessage('Profile picture updated');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploadingImage = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Checks the password fields. Returns true when valid; otherwise stores
  // an error message to display and returns false.
  bool _validatePasswords() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? error;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      error = 'Please fill in all password fields.';
    } else if (newPassword.length < 6) {
      error = 'New password must be at least 6 characters.';
    } else if (newPassword != confirmPassword) {
      error = 'Passwords do not match.';
    }

    setState(() => _passwordError = error);
    return error == null;
  }

  // Changes the password, then logs the user out so they sign in again.
  Future<void> _changePassword() async {
    // Ignore taps while running, and stop if validation fails.
    if (_isChangingPassword || !_validatePasswords()) return;

    setState(() => _isChangingPassword = true);

    try {
      await _authService.changePassword(
        ChangePasswordRequest(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        ),
      );

      if (!mounted) return;

      _showMessage('Password changed successfully');

      // Sign out and clear the cached profile picture.
      await _authService.logout();

      profileImageNotifier.value = null;

      if (!mounted) return;

      // Go back to the login screen, removing all earlier screens.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isChangingPassword = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Shared styling for text fields on this screen.
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _movaGreen),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      // No outline by default...
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      // ...a faint outline when enabled...
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      // ...and a green outline when focused.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _movaGreen, width: 1.5),
      ),
    );
  }

  // A read-only, slightly dimmed field used to display a piece of the
  // user's information.
  Widget _buildInfoField(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        // The key changes with the value so the field refreshes when the
        // underlying data changes.
        key: ValueKey('$label:$value'),
        initialValue: value,
        readOnly: true,
        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72)),
        decoration: _inputDecoration(label: label, icon: icon).copyWith(
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // Builds a rounded card with an icon, title and subtitle at the top and
  // the given [children] underneath. Used to group related settings.
  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header: icon badge + title and subtitle.
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _movaGreen.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _movaGreen, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // The section's content.
          ...children,
        ],
      ),
    );
  }

  // A password text field with a show/hide eye button and optional error.
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      // Clear the old validation error as soon as the user edits a field.
      onChanged: (_) {
        if (_passwordError != null) {
          setState(() => _passwordError = null);
        }
      },
      decoration: _inputDecoration(
        label: label,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Show password' : 'Hide password',
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ).copyWith(errorText: errorText),
    );
  }

  // Full-width green button. Shows a spinner and "Please wait..." while
  // [isLoading] is true. Passing a null [onPressed] disables it.
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.check_rounded, size: 20),
        label: Text(
          isLoading ? 'Please wait...' : label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _movaGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _movaGreen.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Whether the Driver role is currently selected in the dropdown.
    final isDriver = _selectedRole == 'Driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_movaGreen, _movaGreen.withValues(alpha: 0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _movaGreen.withValues(alpha: 0.13),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar with a camera button in the bottom-right corner.
                  // Rebuilds whenever the shared profile image changes.
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: profileImageNotifier,
                    builder: (context, image, child) {
                      return Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 49,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              // Show the photo, or a person icon if none.
                              backgroundImage: image != null
                                  ? MemoryImage(image)
                                  : null,
                              child: image == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 55,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          // Camera button: opens the image picker, or shows
                          // a spinner while uploading.
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _isUploadingImage
                                  ? null
                                  : _pickProfileImage,
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: _isUploadingImage
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _movaGreen,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 18,
                                        color: _movaGreen,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '${_user.firstName} ${_user.surname}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _user.studentNumber,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Pill showing whether this is a driver or passenger account.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDriver
                              ? Icons.directions_car_rounded
                              : Icons.person_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isDriver ? 'Driver Account' : 'Passenger Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // Personal information
            _buildSection(
              title: 'Personal Information',
              subtitle: 'Your registered student details',
              icon: Icons.person_outline_rounded,
              children: [
                _buildInfoField(
                  'First Name',
                  _user.firstName,
                  Icons.badge_outlined,
                ),
                _buildInfoField(
                  'Surname',
                  _user.surname,
                  Icons.person_outline_rounded,
                ),
                _buildInfoField(
                  'Student Number',
                  _user.studentNumber,
                  Icons.school_outlined,
                ),
                // The student email is built from the student number.
                _buildInfoField(
                  'Student Email',
                  '${_user.studentNumber}@vossie.net',
                  Icons.email_outlined,
                ),
                const SizedBox(height: 2),
                // Note explaining that these fields can't be edited.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These details are read-only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Change password
            _buildSection(
              title: 'Security',
              subtitle: 'Keep your account secure',
              icon: Icons.shield_outlined,
              children: [
                _buildPasswordField(
                  label: 'Current Password',
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  onToggle: () => setState(
                    () => _obscureCurrentPassword = !_obscureCurrentPassword,
                  ),
                ),
                const SizedBox(height: 15),
                _buildPasswordField(
                  label: 'New Password',
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  onToggle: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                ),
                const SizedBox(height: 15),
                // The validation error is displayed on this last field.
                _buildPasswordField(
                  label: 'Confirm New Password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  onToggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  errorText: _passwordError,
                ),
                const SizedBox(height: 15),
                // Info box with the password rules.
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _movaGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _movaGreen,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your new password must be at least 6 characters. '
                          'You will be signed out after changing it.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildPrimaryButton(
                  label: 'Change Password',
                  icon: Icons.lock_reset_rounded,
                  isLoading: _isChangingPassword,
                  onPressed: _isChangingPassword ? null : _changePassword,
                ),
              ],
            ),

            // Account role and driver details
            _buildSection(
              title: 'Account Role',
              subtitle: 'Choose how you use Mova',
              icon: Icons.swap_horiz_rounded,
              children: [
                // Dropdown to choose between Driver and Passenger.
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: _inputDecoration(
                    label: 'Account Type',
                    icon: Icons.account_circle_outlined,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  items: const [
                    DropdownMenuItem(value: 'Driver', child: Text('Driver')),
                    DropdownMenuItem(
                      value: 'Passenger',
                      child: Text('Passenger'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() => _selectedRole = value);
                  },
                ),
                // Car details are only shown when Driver is selected.
                if (isDriver) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        color: _movaGreen,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Driver Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _carRegistrationController,
                    decoration: _inputDecoration(
                      label: 'Car Registration',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _carModelController,
                    decoration: _inputDecoration(
                      label: 'Car Model',
                      icon: Icons.directions_car_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Both fields are required to enable your driver account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _buildPrimaryButton(
                  label: 'Save Account Settings',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isSavingRole,
                  onPressed: _isSavingRole ? null : _saveAccountRole,
                ),
              ],
            ),

            // Footer tagline.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  'Mova • Campus Rides, Shared',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

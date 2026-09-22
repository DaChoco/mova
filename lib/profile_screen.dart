import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// "Profile Screen" — lets the user pick/replace a profile picture and
/// edit their Name, Surname, Student Email and Password.
///
/// NOTE: this is UI-only for now — Save/Log Out just show a TODO via
/// SnackBar. Nothing is persisted or sent anywhere until a backend
/// endpoint (or local storage) is wired into `_handleSave` /
/// `_handleLogOut`.
///
/// Setup required for the image picker to work:
///   1. Run: flutter pub add image_picker
///   2. iOS: add NSPhotoLibraryUsageDescription (and
///      NSCameraUsageDescription if you also want camera capture) to
///      ios/Runner/Info.plist.
///   3. Android: no manifest entry needed for gallery-only picking on
///      modern Android versions; image_picker's own setup docs cover
///      edge cases for older SDKs.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  void _handleSave() {
    // TODO: send the updated fields (and image) to your backend.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save tapped — backend not wired yet')),
    );
  }

  void _handleLogOut() {
    // TODO: clear session/auth state and navigate to the login screen.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log Out tapped — backend not wired yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Screen'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildAvatarPicker()),
              const SizedBox(height: 32),
              _buildLabeledField(label: 'Name', controller: _nameController),
              const SizedBox(height: 20),
              _buildLabeledField(
                label: 'Surname',
                controller: _surnameController,
              ),
              const SizedBox(height: 20),
              _buildLabeledField(
                label: 'Student Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildLabeledField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 32),
              _buildPillButton(label: 'Save', onPressed: _handleSave),
              const SizedBox(height: 16),
              _buildPillButton(label: 'Log Out', onPressed: _handleLogOut),
              const SizedBox(height: 16),
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
          CircleAvatar(
            radius: 55,
            backgroundColor: const Color(0xFFF2F2F2),
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : null,
            child: _profileImage == null
                ? const Icon(Icons.person, size: 55, color: Colors.black45)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.edit, size: 18, color: Colors.black45),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black87),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}

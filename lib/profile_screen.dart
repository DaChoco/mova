import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  bool _hidePassword = true;

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
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  void _handleSave() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved — backend not wired yet')),
    );
  }

  void _handleLogOut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log Out pressed — backend not wired yet')),
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
        child: SingleChildScrollView(
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

              // Name
              _buildLabeledField(
                label: 'Name',
                controller: _nameController,
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 20),

              // Surname
              _buildLabeledField(
                label: 'Surname',
                controller: _surnameController,
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 20),

              // Email
              _buildLabeledField(
                label: 'Student Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 20),

              // Password
              _buildLabeledField(
                label: 'Password',
                controller: _passwordController,
                obscureText: _hidePassword,
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _hidePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _hidePassword = !_hidePassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 30),

              // Save button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          CircleAvatar(
            radius: 55,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : null,
            child: _profileImage == null
                ? Icon(
                    Icons.person,
                    size: 55,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
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

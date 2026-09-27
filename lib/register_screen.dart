import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'models/auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final studentNameController = TextEditingController();
  final studentSurnameController = TextEditingController();
  final studentNumberController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    studentNameController.dispose();
    studentSurnameController.dispose();
    studentNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      final request = RegisterRequest(
        studentName: studentNameController.text,
        studentSurname: studentSurnameController.text,
        studentNumber: studentNumberController.text,
        password: passwordController.text,
      );

      // TESTING
      print(request.studentName);
      print(request.studentSurname);
      print(request.studentNumber);
      print(request.password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Student Registration',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 40),

                  // Student Name
                  TextFormField(
                    controller: studentNameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Student Name',
                      hintText: 'Enter your real name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final RegExp regularExpression = RegExp(
                        r"^[\p{L} '-]{2,60}$",
                      );

                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      } else if (!regularExpression.hasMatch(value)) {
                        return 'Please enter your real name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Student Surname
                  TextFormField(
                    controller: studentSurnameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Student Surname',
                      hintText: 'Enter your real surname',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final RegExp regularExpression = RegExp(
                        r"^[\p{L} '-]{2,60}$",
                      );

                      if (value == null || value.isEmpty) {
                        return 'Please enter your surname';
                      } else if (!regularExpression.hasMatch(value)) {
                        return 'Please enter your real surname';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Student Number
                  TextFormField(
                    controller: studentNumberController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Student Number',
                      hintText: 'Enter your student number',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your student number';
                      } else if (!RegExp(r'^EDUV\d{7}$', caseSensitive: false).hasMatch(value) && RegExp(r'^[A-Z0-9]{9}$', caseSensitive: false).hasMatch(value)) {
                        return 'Enter a valid student number';
                    }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Password
                  TextFormField(
                    controller: passwordController,
                    obscureText: _hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Confirm Password
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: _hideConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hideConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _hideConfirmPassword = !_hideConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }

                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  // Register button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: const Text(
                        'Register',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Login link
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Already have an account? Login',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'register_screen.dart';
import 'models/auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final studentNumberController = TextEditingController();
  final passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    studentNumberController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      final request = LoginRequest(
        studentNumber: studentNumberController.text,
        password: passwordController.text,
      );

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Student Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 40),

                // Student number
                TextFormField(
                  controller: studentNumberController,
                  keyboardType: TextInputType.name,
                  decoration: const InputDecoration(
                    labelText: 'Student Number',
                    hintText: 'Enter your student number',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your student number';
                    } else if (!value.contains("EDUV") || value.length != 11) {
                      return "ERROR: Please enter a valid student number. Eg EDUVxxxxxxx";
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
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
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

                const SizedBox(height: 30),

                // Login button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // TEMPORARY LOGIN
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Already have an account? Register',
                    style: TextStyle(fontSize: 16),
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

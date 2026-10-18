import 'package:flutter/material.dart';

import 'terms_and_conditions.dart';
import 'config/app_config.dart';
import 'register_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';
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
  bool _isLoggingIn = false;

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  static const Color _movaGreen = Color(0xFF0F6E56);

  @override
  void dispose() {
    studentNumberController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = LoginRequest(
      studentNumber: studentNumberController.text.trim(),
      password: passwordController.text,
    );

    setState(() {
      _isLoggingIn = true;
    });

    try {
      // Login and save the JWT.
      await _authService.login(request);

      // Get the logged-in user's details.
      final user = await _authService.getUser();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(16);

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withAlpha(isDark ? 150 : 100),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
      labelStyle: TextStyle(
        fontFamily: 'Nunito',
        color: colors.onSurfaceVariant,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Nunito',
        color: colors.onSurfaceVariant.withAlpha(180),
      ),
      prefixIconColor: colors.primary,
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colors.outlineVariant.withAlpha(130)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: _movaGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colors.error, width: 1.8),
      ),
    );

    return Scaffold(
      backgroundColor: colors.surface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _movaGreen.withAlpha(isDark ? 45 : 20),
              colors.surface,
              colors.surface,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mova branding.
                            Center(
                              child: Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: _movaGreen,
                                  borderRadius: BorderRadius.circular(27),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _movaGreen.withAlpha(65),
                                      blurRadius: 26,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  size: 43,
                                  color: Color(0xFFD1FAEB),
                                ),
                              ),
                            ),

                            const SizedBox(height: 25),

                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                                letterSpacing: -0.6,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Your journey starts here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                color: colors.onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Login form card.
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: colors.outlineVariant.withAlpha(90),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      isDark ? 35 : 10,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Student Login',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: colors.onSurface,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    'Sign in to continue to Mova.',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),

                                  const SizedBox(height: 25),

                                  // Student number.
                                  TextFormField(
                                    controller: studentNumberController,
                                    keyboardType: TextInputType.name,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Student Number',
                                      hintText: 'Enter your student number',
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your student number';
                                      } else if (!RegExp(
                                            r'^EDUV\d{7}$',
                                            caseSensitive: false,
                                          ).hasMatch(value) &&
                                          !RegExp(
                                            r'^[A-Z0-9]{9}$',
                                            caseSensitive: false,
                                          ).hasMatch(value)) {
                                        return 'Enter a valid student number';
                                      }

                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 18),

                                  // Password.
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: _hidePassword,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Password',
                                      hintText: 'Enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _hidePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
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

                                  const SizedBox(height: 26),

                                  // Login button.
                                  SizedBox(
                                    height: 56,
                                    child: FilledButton(
                                      onPressed: _isLoggingIn ? null : _login,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _movaGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: _movaGreen
                                            .withAlpha(130),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _isLoggingIn
                                          ? const SizedBox(
                                              width: 23,
                                              height: 23,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Login',
                                                  style: TextStyle(
                                                    fontFamily: 'Nunito',
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 9),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Terms and Conditions notice.
                                  Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'By signing in, you agree to our ',
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const TermsAndConditionsScreen(),
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: colors.primary,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Terms & Conditions',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Registration link.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isLoggingIn
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const RegisterScreen(),
                                            ),
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'A simpler way to get where you need to go.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                color: colors.onSurfaceVariant.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

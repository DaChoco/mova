import 'package:flutter/material.dart';
import 'package:mova/config/app_config.dart';

import 'terms_and_conditions.dart';

import 'login_screen.dart';
import 'models/auth.dart';
import 'services/auth_service.dart';

// Registration page where new students create a Mova account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Key used to validate all form fields at once.
  final _formKey = GlobalKey<FormState>();

  // Controllers that hold the text typed into each field.
  final studentNameController = TextEditingController();
  final studentSurnameController = TextEditingController();
  final studentNumberController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Whether each password field's text is hidden.
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  // True while the registration request is running (disables the button).
  bool _isRegistering = false;

  // Mova brand colour.
  static const Color _movaGreen = Color(0xFF0F6E56);

  final AuthService _authService = AuthService(
    baseUrl: AppConfig.backendBaseUrl,
  );

  @override
  void dispose() {
    // Release all text controllers.
    studentNameController.dispose();
    studentSurnameController.dispose();
    studentNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Validates the form, sends the registration to the backend, then
  // takes the user to the login screen.
  Future<void> _register() async {
    // Stop if any field fails validation.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    final request = RegisterRequest(
      studentName: studentNameController.text.trim(),
      studentSurname: studentSurnameController.text.trim(),
      studentNumber: studentNumberController.text.trim(),
      password: passwordController.text,
    );

    try {
      await _authService.register(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Replace this page with the login page.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      // Show the error without the "Exception: " prefix.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Re-enable the register button.
      if (mounted) {
        setState(() {
          _isRegistering = false;
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

    // Shared text field styling; each field customises it with copyWith.
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withAlpha(isDark ? 150 : 100),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: TextStyle(
        fontFamily: 'Nunito',
        color: colors.onSurfaceVariant,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Nunito',
        color: colors.onSurfaceVariant.withAlpha(180),
      ),
      prefixIconColor: colors.primary,
      // No outline by default...
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      // ...a faint outline when enabled...
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colors.outlineVariant.withAlpha(130)),
      ),
      // ...a green outline when focused...
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: _movaGreen, width: 1.8),
      ),
      // ...and red outlines when the field has a validation error.
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
        // Soft green tint fading out towards the bottom of the screen.
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
          // LayoutBuilder gives the available height so the content can be
          // vertically centred but still scroll on small screens.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  // Minimum height = screen height minus the vertical padding.
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Center(
                    // Limit the width on large screens (tablets, web).
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
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: _movaGreen,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _movaGreen.withAlpha(60),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  size: 38,
                                  color: Color(0xFFD1FAEB),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              'Join Mova',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 31,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colors.onSurface,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Create your account and get moving.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                color: colors.onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Registration form card.
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
                                    'Student Registration',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: colors.onSurface,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    'Enter your details to get started.',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Student name.
                                  TextFormField(
                                    controller: studentNameController,
                                    keyboardType: TextInputType.text,
                                    // Capitalise the first letter of each word.
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Student Name',
                                      hintText: 'Enter your real name',
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    // Allows 2-60 letters (including accented
                                    // letters), spaces, apostrophes and hyphens.
                                    // Note: the error messages below say
                                    // "surname" even though this is the name
                                    // field (left unchanged).
                                    validator: (value) {
                                      final regularExpression = RegExp(
                                        r"^[a-zA-ZÀ-ÿ' -]{2,60}$",
                                      );

                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your surname';
                                      } else if (!regularExpression.hasMatch(
                                        value.trim(),
                                      )) {
                                        return 'Please enter a valid surname';
                                      }

                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 17),

                                  // Student surname.
                                  TextFormField(
                                    controller: studentSurnameController,
                                    keyboardType: TextInputType.text,
                                    // Capitalise the first letter of each word.
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Student Surname',
                                      hintText: 'Enter your real surname',
                                      prefixIcon: const Icon(
                                        Icons.badge_outlined,
                                      ),
                                    ),
                                    // Same rules as the name field: 2-60 letters,
                                    // spaces, apostrophes and hyphens.
                                    validator: (value) {
                                      final regularExpression = RegExp(
                                        r"^[a-zA-ZÀ-ÿ' -]{2,60}$",
                                      );

                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your surname';
                                      } else if (!regularExpression.hasMatch(
                                        value.trim(),
                                      )) {
                                        return 'Please enter a valid surname';
                                      }

                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 17),

                                  // Student number.
                                  TextFormField(
                                    controller: studentNumberController,
                                    keyboardType: TextInputType.text,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Student Number',
                                      hintText: 'Enter your student number',
                                      prefixIcon: const Icon(
                                        Icons.school_outlined,
                                      ),
                                    ),
                                    // Accepts "EDUV" followed by 7 digits, or
                                    // any 9 letters/digits (case-insensitive).
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

                                  const SizedBox(height: 17),

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
                                      hintText: 'Create a password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      // Eye icon toggles password visibility.
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
                                    // Only checks that something was entered.
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }

                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 17),

                                  // Confirm password.
                                  TextFormField(
                                    controller: confirmPasswordController,
                                    obscureText: _hideConfirmPassword,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: colors.onSurface,
                                    ),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Confirm Password',
                                      hintText: 'Re-enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_reset_rounded,
                                      ),
                                      // Eye icon toggles visibility of this field.
                                      suffixIcon: IconButton(
                                        tooltip: _hideConfirmPassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        icon: Icon(
                                          _hideConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _hideConfirmPassword =
                                                !_hideConfirmPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    // Must be filled in and match the password.
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

                                  const SizedBox(height: 26),

                                  // Register button.
                                  SizedBox(
                                    height: 56,
                                    child: FilledButton(
                                      // Disabled while registration is running.
                                      onPressed: _isRegistering
                                          ? null
                                          : _register,
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
                                      // Spinner while registering, otherwise
                                      // the "Create Account" label with an arrow.
                                      child: _isRegistering
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
                                                  'Create Account',
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
                                          'By registering, you agree to our ',
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        // Opens the Terms & Conditions page.
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

                            const SizedBox(height: 22),

                            // Login link.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                // Disabled while registering; otherwise opens
                                // the login page.
                                TextButton(
                                  onPressed: _isRegistering
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
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
                                    'Login',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
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

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'mova_logo_painter.dart';

// Animated intro screen: a green glow fades in, the logo fades and scales in,
// then the "Mova" text appears before moving on to the login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Single controller that drives every animation on this screen.
  late final AnimationController _c;

  // Total length of the animation timeline in milliseconds.
  static const int _totalMs = 2100;

  // Creates an animation that only plays between [start] and [end]
  // (in milliseconds) of the overall timeline.
  Animation<double> _iv(int start, int end, [Curve curve = Curves.easeOut]) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start / _totalMs, end / _totalMs, curve: curve),
    );
  }

  // Glow fades in first, then partly settles back down.
  late final Animation<double> _glowIn = _iv(0, 900);
  late final Animation<double> _glowSettle = _iv(1000, 1500, Curves.easeInOut);

  // Logo fades in and grows slightly.
  late final Animation<double> _logoFade = _iv(300, 1050);
  late final Animation<double> _logoScale = _iv(300, 1600, Curves.easeOutCubic);

  // "Mova" text fades in last.
  late final Animation<double> _text = _iv(1650, 2050);

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    // Start the animation and go to the login screen once it finishes.
    _c.forward().whenComplete(_navigateToLogin);
  }

  // Pauses briefly after the animation, then replaces this screen
  // with the login screen (so Back won't return to the splash).
  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => LoginScreen()));
  }

  @override
  void dispose() {
    // Release the animation controller.
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _c,
          // The glow itself never changes, only its opacity does, so it is
          // built once here and reused on every animation frame.
          child: RepaintBoundary(
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                // Radial gradient fading from solid green to transparent.
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [
                    Color(0xFF0F6E56),
                    Color(0xCC0F6E56),
                    Color(0x000F6E56),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          builder: (context, glowChild) {
            // Glow brightens while fading in, then dims slightly as it settles.
            final glowOpacity =
                (0.30 * _glowIn.value - 0.12 * _glowSettle.value).clamp(
                  0.0,
                  1.0,
                );

            return Stack(
              alignment: Alignment.center,
              children: [
                // Background glow.
                Opacity(opacity: glowOpacity, child: glowChild),

                // Logo and text, centred on top of the glow.
                RepaintBoundary(
                  child: SizedBox(
                    width: 192,
                    height: 223,
                    child: Column(
                      children: [
                        // Logo: fades in and scales from 80% to 100%.
                        Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * _logoScale.value,
                            child: SizedBox(
                              width: 192,
                              height: 148,
                              // OverflowBox lets the logo's blur/glow extend
                              // slightly beyond the box without being clipped.
                              child: OverflowBox(
                                maxWidth: 200,
                                maxHeight: 161,
                                child: CustomPaint(
                                  size: const Size(200, 161),
                                  painter: MovaLogoPainter(),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // App name: fades in while sliding up 4 pixels.
                        Opacity(
                          opacity: _text.value,
                          child: Transform.translate(
                            offset: Offset(0, 4 * (1 - _text.value)),
                            child: const SizedBox(
                              width: 192,
                              height: 53,
                              child: Text(
                                'Mova',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

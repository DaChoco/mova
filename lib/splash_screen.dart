import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';
import 'mova_logo_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _totalMs = 2100;

  Animation<double> _iv(int s, int e, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(
        parent: _c,
        curve: Interval(s / _totalMs, e / _totalMs, curve: curve),
      );

  late final _glowIn = _iv(0, 900);
  late final _glowSettle = _iv(1000, 1500, Curves.easeInOut);
  late final _logoFade = _iv(300, 1050);
  late final _logoScale = _iv(300, 1600, Curves.easeOutCubic);
  late final _text = _iv(1650, 2050);

  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: _totalMs),
          )
          ..forward().whenComplete(() async {
            await Future.delayed(
              const Duration(milliseconds: 500),
            ); // brief hold
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          });
  }

  @override
  void dispose() {
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
          builder: (context, _) {
            // 0 -> 0.30 -> settles at 0.18
            final glowOpacity = 0.30 * _glowIn.value - 0.12 * _glowSettle.value;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Ambient light
                Opacity(
                  opacity: glowOpacity.clamp(0.0, 1.0),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 30,
                      sigmaY: 30,
                      tileMode: TileMode.decal,
                    ),
                    child: Container(
                      width: 420,
                      height: 420,
                      color: const Color(0xFF0F6E56),
                    ),
                  ),
                ),

                // Logo + app name
                SizedBox(
                  width: 192,
                  height: 223,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: 0.8 + 0.2 * _logoScale.value,
                          child: SizedBox(
                            width: 192,
                            height: 148,
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
                      Opacity(
                        opacity: _text.value,
                        child: Transform.translate(
                          offset: Offset(0, 4 * (1 - _text.value)),
                          child: SizedBox(
                            width: 192,
                            height: 53,
                            child: Text(
                              'Mova',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
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
              ],
            );
          },
        ),
      ),
    );
  }
}

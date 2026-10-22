import 'package:flutter/material.dart';

// Draws the Mova logo (an "M" shape with a dot at the base of each leg)
// directly on a canvas, including a drop shadow and a soft green glow.
class MovaLogoPainter extends CustomPainter {
  // Main logo colour (light mint).
  static const mint = Color(0xFFD1FAEB);

  // Colour used for the glow behind the logo (Mova green).
  static const glow = Color(0xFF0F6E56);

  @override
  void paint(Canvas canvas, Size size) {
    // The "M" outline: up the left leg, diagonal down to the centre,
    // diagonal up to the right leg, then down the right leg.
    final m = Path()
      ..moveTo(34, 119)
      ..lineTo(34, 29)
      ..lineTo(100, 89)
      ..lineTo(166, 29)
      ..lineTo(166, 119);

    // Draws the whole logo (the M stroke plus both dots) in one colour.
    // An optional blur is used for the shadow and glow layers.
    void shapes(Color color, MaskFilter? blur) {
      // Thick rounded stroke for the "M".
      final stroke = Paint()
        ..color = color
        ..maskFilter = blur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      // Solid fill for the two dots.
      final fill = Paint()
        ..color = color
        ..maskFilter = blur;
      canvas.drawPath(m, stroke);
      // Dots sitting under the left and right legs of the "M".
      canvas.drawCircle(const Offset(34, 127), 14, fill);
      canvas.drawCircle(const Offset(166, 127), 14, fill);
    }

    // Drop shadow: y 6, blur 5, black 50%
    canvas.save();
    // Shift the shadow layer down before drawing it.
    canvas.translate(0, 6);
    shapes(
      Colors.black.withOpacity(0.5),
      const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();

    // Glow: blur 10, #0F6E56 at 32%
    shapes(glow.withOpacity(0.32), const MaskFilter.blur(BlurStyle.normal, 10));

    // The logo itself
    shapes(mint, null);
  }

  // The logo never changes, so there is no need to repaint it.
  @override
  bool shouldRepaint(MovaLogoPainter old) => false;
}

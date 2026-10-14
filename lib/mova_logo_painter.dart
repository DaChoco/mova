import 'package:flutter/material.dart';

class MovaLogoPainter extends CustomPainter {
  static const mint = Color(0xFFD1FAEB);
  static const glow = Color(0xFF0F6E56);

  @override
  void paint(Canvas canvas, Size size) {
    final m = Path()
      ..moveTo(34, 119)
      ..lineTo(34, 29)
      ..lineTo(100, 89)
      ..lineTo(166, 29)
      ..lineTo(166, 119);

    void shapes(Color color, MaskFilter? blur) {
      final stroke = Paint()
        ..color = color
        ..maskFilter = blur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fill = Paint()
        ..color = color
        ..maskFilter = blur;
      canvas.drawPath(m, stroke);
      canvas.drawCircle(const Offset(34, 127), 14, fill);
      canvas.drawCircle(const Offset(166, 127), 14, fill);
    }

    // Drop shadow: y 6, blur 5, black 50%
    canvas.save();
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

  @override
  bool shouldRepaint(MovaLogoPainter old) => false;
}

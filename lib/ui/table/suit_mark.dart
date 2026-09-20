import 'package:flutter/material.dart';

import '../../model/card.dart';

/// Pips drawn as paths rather than typed as glyphs. A card game should not
/// depend on whichever symbol font the device happens to ship, and drawing
/// them keeps the shapes part of the deck's design instead of the system's.
class SuitMark extends StatelessWidget {
  const SuitMark({
    required this.suit,
    required this.size,
    required this.colour,
    super.key,
  });

  final Suit suit;

  /// Width of the mark. Height follows the shape's own proportion.
  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.06,
      child: CustomPaint(painter: _SuitPainter(suit, colour)),
    );
  }
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.colour);

  final Suit suit;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    final path = Path();
    switch (suit) {
      case Suit.diamonds:
        path
          ..moveTo(w * 0.5, 0)
          ..quadraticBezierTo(w * 0.72, h * 0.30, w, h * 0.5)
          ..quadraticBezierTo(w * 0.72, h * 0.70, w * 0.5, h)
          ..quadraticBezierTo(w * 0.28, h * 0.70, 0, h * 0.5)
          ..quadraticBezierTo(w * 0.28, h * 0.30, w * 0.5, 0)
          ..close();

      case Suit.hearts:
        path
          ..moveTo(w * 0.5, h)
          ..cubicTo(p(-0.06, 0.60).dx, p(0, 0.60).dy, w * 0.06, h * 0.04, w * 0.5, h * 0.30)
          ..cubicTo(w * 0.94, h * 0.04, w * 1.06, h * 0.60, w * 0.5, h)
          ..close();

      case Suit.spades:
        path
          ..moveTo(w * 0.5, 0)
          ..cubicTo(w * 1.08, h * 0.40, w * 0.96, h * 0.86, w * 0.62, h * 0.72)
          ..cubicTo(w * 0.56, h * 0.70, w * 0.53, h * 0.74, w * 0.56, h * 0.80)
          ..lineTo(w * 0.66, h)
          ..lineTo(w * 0.34, h)
          ..lineTo(w * 0.44, h * 0.80)
          ..cubicTo(w * 0.47, h * 0.74, w * 0.44, h * 0.70, w * 0.38, h * 0.72)
          ..cubicTo(w * 0.04, h * 0.86, w * -0.08, h * 0.40, w * 0.5, 0)
          ..close();

      case Suit.clubs:
        final r = w * 0.27;
        path
          ..addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.26), radius: r))
          ..addOval(Rect.fromCircle(center: Offset(w * 0.24, h * 0.62), radius: r))
          ..addOval(Rect.fromCircle(center: Offset(w * 0.76, h * 0.62), radius: r));
        final stem = Path()
          ..moveTo(w * 0.44, h * 0.58)
          ..cubicTo(w * 0.47, h * 0.76, w * 0.42, h * 0.90, w * 0.32, h)
          ..lineTo(w * 0.68, h)
          ..cubicTo(w * 0.58, h * 0.90, w * 0.53, h * 0.76, w * 0.56, h * 0.58)
          ..close();
        path.addPath(stem, Offset.zero);
    }

    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.colour != colour;
}

import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The layout itself: indigo cloth under a warm overhead light, with the
/// table's conditions screen-printed along the arc the way a real felt carries
/// them. Everything else on the table screen sits on top of this.
class TableFelt extends StatelessWidget {
  const TableFelt({
    required this.legend,
    required this.arcY,
    required this.betSpot,
    this.showBetSpot = true,
    super.key,
  });

  /// Rules text printed on the arc.
  final String legend;

  /// Where the arc crosses the centre line, in logical pixels.
  final double arcY;

  /// Centre of the betting circle.
  final Offset betSpot;

  /// Hidden once the hand is split, when chips no longer rest on one spot.
  final bool showBetSpot;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FeltPainter(
          legend: legend,
          arcY: arcY,
          betSpot: betSpot,
          showBetSpot: showBetSpot,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _FeltPainter extends CustomPainter {
  _FeltPainter({
    required this.legend,
    required this.arcY,
    required this.betSpot,
    required this.showBetSpot,
  });

  final String legend;
  final double arcY;
  final Offset betSpot;
  final bool showBetSpot;

  /// Cloth speckle, generated once and reused for every repaint.
  static final List<Offset> _grain = List.generate(
    1500,
    (i) {
      final r = math.Random(i * 7919 + 13);
      return Offset(r.nextDouble(), r.nextDouble());
    },
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.42),
          radius: 1.05,
          colors: [AppColor.feltHi, AppColor.feltMid, AppColor.feltLo],
          stops: [0.0, 0.52, 1.0],
        ).createShader(rect),
    );

    // Overhead pit light, hanging above the dealer.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.92),
          radius: 0.78,
          colors: [AppColor.amber.withValues(alpha: 0.13), AppColor.amber.withValues(alpha: 0)],
        ).createShader(rect),
    );

    _paintGrain(canvas, size);
    _paintArc(canvas, size);
    if (showBetSpot) _paintBetSpot(canvas);

    // Edge vignette keeps the cloth from glowing at the rail.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.95,
          colors: [AppColor.feltLo.withValues(alpha: 0), AppColor.feltLo.withValues(alpha: 0.55)],
          stops: const [0.6, 1.0],
        ).createShader(rect),
    );
  }

  void _paintGrain(Canvas canvas, Size size) {
    final points = _grain.map((o) => Offset(o.dx * size.width, o.dy * size.height)).toList();
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = AppColor.bone.withValues(alpha: 0.035)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintArc(Canvas canvas, Size size) {
    final radius = size.width * 1.62;
    final centre = Offset(size.width / 2, arcY - radius);

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColor.bone.withValues(alpha: 0.16)
      ..strokeWidth = 1.1;

    void arcAt(double r, double alpha, double width) {
      hairline
        ..color = AppColor.bone.withValues(alpha: alpha)
        ..strokeWidth = width;
      final box = Rect.fromCircle(center: centre, radius: r);
      // Sweep centred on straight-down from the arc's centre.
      const span = 1.05;
      canvas.drawArc(box, math.pi / 2 - span / 2, span, false, hairline);
    }

    arcAt(radius, 0.20, 1.4);
    arcAt(radius - size.width * 0.155, 0.10, 1.0);

    _drawTextOnArc(
      canvas,
      legend,
      centre,
      radius - size.width * 0.075,
      AppText.eyebrow(8.5, color: AppColor.bone.withValues(alpha: 0.44), weight: 600),
    );
  }

  void _drawTextOnArc(Canvas canvas, String text, Offset centre, double radius, TextStyle style) {
    final painters = <TextPainter>[];
    var totalWidth = 0.0;
    for (final ch in text.split('')) {
      final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
      totalWidth += tp.width;
    }

    var angle = -(totalWidth / radius) / 2;
    for (final tp in painters) {
      final step = tp.width / radius;
      final mid = angle + step / 2;
      canvas.save();
      canvas.translate(
        centre.dx + radius * math.sin(mid),
        centre.dy + radius * math.cos(mid),
      );
      canvas.rotate(-mid);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      angle += step;
    }
  }

  void _paintBetSpot(Canvas canvas) {
    final r = 30.0;
    canvas.drawCircle(
      betSpot,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColor.bone.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      betSpot,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColor.bone.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) =>
      old.legend != legend ||
      old.arcY != arcY ||
      old.betSpot != betSpot ||
      old.showBetSpot != showBetSpot;
}

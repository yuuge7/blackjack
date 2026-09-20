import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';

/// A clay chip. Edge spots and denomination follow a real rack, which is where
/// the accent colours in this app come from.
class ChipView extends StatelessWidget {
  const ChipView({required this.denom, this.size = 44, this.faded = false, super.key});

  final int denom;
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final colour = AppColor.chipColor(denom);
    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ChipPainter(colour),
          child: Center(
            child: Text(
              chipFace(denom),
              style: AppText.mono(
                size * 0.28,
                weight: FontWeight.w600,
                color: AppColor.chipInk(denom),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(
      c.translate(0, r * 0.10),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawCircle(c, r, Paint()..color = colour);

    // Edge spots.
    final spot = Paint()..color = AppColor.bone.withValues(alpha: 0.85);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 12;
      canvas.save();
      canvas.translate(c.dx + math.cos(a) * r * 0.80, c.dy + math.sin(a) * r * 0.80);
      canvas.rotate(a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 0.34, height: r * 0.44),
          Radius.circular(r * 0.08),
        ),
        spot,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      c,
      r * 0.70,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = AppColor.bone.withValues(alpha: 0.22),
    );
    canvas.drawCircle(c, r * 0.62, Paint()..color = colour);
    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.colour != colour;
}

/// Breaks an amount into a leaning stack, largest denomination on top.
class ChipStack extends StatelessWidget {
  const ChipStack({required this.amount, this.chipSize = 34, super.key});

  final int amount;
  final double chipSize;

  static List<int> breakdown(int amount) {
    final out = <int>[];
    var left = amount;
    for (final d in [25000, 5000, 1000, 500, 100, 25, 5, 1]) {
      while (left >= d && out.length < 6) {
        out.add(d);
        left -= d;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final chips = breakdown(amount);
    final overlap = chipSize * 0.22;
    return SizedBox(
      width: chipSize,
      height: chipSize + overlap * (chips.length - 1),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (var i = chips.length - 1; i >= 0; i--)
            Positioned(
              bottom: i * overlap,
              child: ChipView(denom: chips[i], size: chipSize),
            ),
        ],
      ),
    );
  }
}

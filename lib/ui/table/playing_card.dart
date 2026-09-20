import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../model/card.dart';
import 'suit_mark.dart';

/// A card as a typographic object: one oversized condensed index top left and
/// a single bleeding pip bottom right. Pip grids do not survive being 60 px
/// wide, and a centred rank disappears the moment a hand fans.
class CardView extends StatefulWidget {
  const CardView({
    required this.card,
    required this.width,
    this.faceDown = false,
    this.dimmed = false,
    super.key,
  });

  final PlayingCard? card;
  final double width;
  final bool faceDown;

  /// Hands that are not the one you are playing sit back a step.
  final bool dimmed;

  @override
  State<CardView> createState() => _CardViewState();
}

class _CardViewState extends State<CardView> with TickerProviderStateMixin {
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();

  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 330),
    value: 1,
  );

  late bool _wasFaceDown = widget.faceDown;

  @override
  void didUpdateWidget(CardView old) {
    super.didUpdateWidget(old);
    if (old.faceDown != widget.faceDown) {
      _wasFaceDown = old.faceDown;
      _flip.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _deal.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w / kCardAspect;

    return AnimatedBuilder(
      animation: Listenable.merge([_deal, _flip]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_deal.value);
        final f = Curves.easeInOut.transform(_flip.value);
        final showBack = (f < 0.5 ? _wasFaceDown : widget.faceDown) || widget.card == null;
        // Swap the face at the halfway point so the artwork is never mirrored.
        final angle = f < 0.5 ? f * math.pi : f * math.pi - math.pi;

        return Opacity(
          opacity: t * (widget.dimmed ? 0.55 : 1),
          child: Transform.translate(
            offset: Offset(w * 0.9 * (1 - t), -h * 0.55 * (1 - t)),
            child: Transform.rotate(
              angle: 0.22 * (1 - t),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY(angle),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(w * 0.085),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: w * 0.22,
                          offset: Offset(0, w * 0.07),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(w * 0.085),
                      child: showBack
                          ? _CardBack(width: w)
                          : _CardFace(card: widget.card!, width: w),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width});

  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final colour = card.suit.isRed ? AppColor.clay : AppColor.ink;

    // Hands fan, so only the left strip of a covered card is ever visible.
    // The index carries the read; the pip only shows on the exposed card.
    final index = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          card.rank.label,
          style: AppText.display(w * 0.36, weight: 700, color: colour, height: 0.80),
        ),
        SizedBox(height: w * 0.025),
        SuitMark(suit: card.suit, size: w * 0.16, colour: colour),
      ],
    );

    return Container(
      color: AppColor.bone,
      child: Stack(
        children: [
          // Printed inner rule, the way a real face is bordered.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(w * 0.055),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.05),
                  border: Border.all(color: AppColor.ink.withValues(alpha: 0.10), width: 0.8),
                ),
              ),
            ),
          ),
          // A rotated index turns a nine into a six at this size, so the
          // opposite corner carries the pip instead.
          Positioned(
            right: -w * 0.04,
            bottom: -w * 0.05,
            child: SuitMark(
              suit: card.suit,
              size: w * 0.52,
              colour: colour.withValues(alpha: 0.13),
            ),
          ),
          Positioned(left: w * 0.09, top: w * 0.06, child: index),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackPainter(), size: Size(width, width / kCardAspect));
  }
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232B4D), Color(0xFF141931)],
        ).createShader(rect),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AppColor.bone.withValues(alpha: 0.10);

    final step = size.width * 0.17;
    canvas.save();
    canvas.clipRect(rect);
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();

    final inset = size.width * 0.10;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
        Radius.circular(size.width * 0.05),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = AppColor.amber.withValues(alpha: 0.32),
    );
  }

  @override
  bool shouldRepaint(_BackPainter oldDelegate) => false;
}

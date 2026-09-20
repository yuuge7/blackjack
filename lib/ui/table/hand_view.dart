import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../model/hand.dart';
import 'playing_card.dart';

enum BadgeTone { neutral, active, bust, good }

/// The running total, read the way a dealer calls it: the number, and whether
/// it is soft.
class TotalBadge extends StatelessWidget {
  const TotalBadge({
    required this.total,
    this.soft = false,
    this.tone = BadgeTone.neutral,
    this.scale = 1,
    super.key,
  });

  final int total;
  final bool soft;
  final BadgeTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = switch (tone) {
      BadgeTone.neutral => (AppColor.bone, AppColor.rail.withValues(alpha: 0.82), AppColor.line),
      BadgeTone.active => (AppColor.amber, const Color(0xE6221B10), AppColor.amber.withValues(alpha: 0.55)),
      BadgeTone.bust => (AppColor.clay, const Color(0xE62A1113), AppColor.clay.withValues(alpha: 0.55)),
      BadgeTone.good => (AppColor.jade, const Color(0xE60E2620), AppColor.jade.withValues(alpha: 0.55)),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 3.5 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (soft) ...[
            Text('SOFT', style: AppText.eyebrow(7 * scale, color: fg.withValues(alpha: 0.7))),
            SizedBox(width: 5 * scale),
          ],
          Text(
            '$total',
            style: AppText.mono(14 * scale, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// A fanned hand. Cards keep their identity across rebuilds so each one deals
/// in exactly once.
class HandView extends StatelessWidget {
  const HandView({
    required this.hand,
    required this.cardWidth,
    this.hideHole = false,
    super.key,
  });

  final Hand hand;
  final double cardWidth;

  /// Keeps the dealer's second card down until the hand is played out.
  final bool hideHole;

  @override
  Widget build(BuildContext context) {
    final cards = hand.cards;
    final spacing = cardWidth * (cards.length > 4 ? 0.36 : 0.52);
    final width = cards.isEmpty ? 0.0 : cardWidth + spacing * (cards.length - 1);

    return SizedBox(
      width: width,
      height: cardWidth / kCardAspect,
      child: Stack(
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: i * spacing,
              child: CardView(
                key: ValueKey(cards[i].id),
                card: cards[i],
                width: cardWidth,
                faceDown: hideHole && i == 1,
              ),
            ),
        ],
      ),
    );
  }
}

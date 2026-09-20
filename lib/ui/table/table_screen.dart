import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/hand.dart';
import '../../state/game_controller.dart';
import '../../state/settings_store.dart';
import '../settings/tables_panel.dart';
import 'chip.dart';
import 'dock.dart';
import 'hand_view.dart';
import 'table_felt.dart';
import 'top_bar.dart';

const double _chipSize = 32;
const double _chipBlock = 46;
const double _labelBlock = 26;
const double _cardToChips = 24;

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    return Column(
      children: [
        TableTopBar(
          bankroll: game.bankroll,
          shoe: game.shoe,
          showCount: game.settings.showCount,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              final bandH = h < 520 ? 44.0 : 56.0;

              // Size the cards so the whole composition, plus room to breathe,
              // fits the screen we were actually given.
              final baseCard = ((h - 296 - bandH) / 2 * kCardAspect).clamp(46.0, 88.0);
              final dealerCardH = baseCard / kCardAspect;

              final handCount = game.hands.isEmpty ? 1 : game.hands.length;
              final playerCard = handCount >= 3
                  ? baseCard * 0.62
                  : handCount == 2
                      ? baseCard * 0.82
                      : baseCard;
              final playerCardH = playerCard / kCardAspect;

              // Fixed clearances keep the printed arc clear of the dealer's
              // cards; whatever is left over is shared out around them.
              final fixed = 20 +
                  dealerCardH +
                  12 +
                  44 +
                  bandH +
                  24 +
                  playerCardH +
                  _cardToChips +
                  _chipBlock +
                  _labelBlock;
              final slack = (h - fixed).clamp(0.0, double.infinity);

              final dealerTop = slack * 0.12;
              final dealerBottom = dealerTop + 20 + dealerCardH + 12;
              final bandTop = dealerBottom + 44 + slack * 0.28;
              final playerTop = bandTop + bandH + 24 + slack * 0.34;
              final arcY = bandTop - 18;

              final betSpot = Offset(
                w / 2,
                playerTop + playerCardH + _cardToChips + _chipBlock - _chipSize / 2,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: game.phase == Phase.settled ? game.nextRound : null,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TableFelt(
                        legend: game.rules.legend,
                        arcY: arcY,
                        betSpot: betSpot,
                        showBetSpot: game.hands.length <= 1,
                      ),
                    ),
                    Positioned(
                      top: dealerTop,
                      left: 0,
                      right: 0,
                      child: _DealerBlock(game: game, cardWidth: baseCard),
                    ),
                    Positioned(
                      top: bandTop,
                      left: 16,
                      right: 16,
                      child: _Band(game: game, height: bandH),
                    ),
                    Positioned(
                      top: playerTop,
                      left: 0,
                      right: 0,
                      child: _PlayerBlock(
                        game: game,
                        cardWidth: playerCard,
                        cardHeight: playerCardH,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        TableDock(game: game),
      ],
    );
  }
}

class _DealerBlock extends StatelessWidget {
  const _DealerBlock({required this.game, required this.cardWidth});

  final GameController game;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final dealer = game.dealer;
    final hidden = game.holeDown && dealer.cards.length > 1;

    // While the hole card is down, the dealer's call is just the upcard.
    final shown = hidden ? dealer.cards.first.value : dealer.total;
    final soft = hidden ? dealer.cards.first.isAce : dealer.isSoft;

    final tone = !hidden && dealer.total > 21
        ? BadgeTone.bust
        : !hidden && dealer.isBlackjack
            ? BadgeTone.good
            : BadgeTone.neutral;

    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Text(
            'DEALER',
            style: AppText.eyebrow(9, color: AppColor.bone.withValues(alpha: 0.45)),
          ),
        ),
        SizedBox(
          height: cardWidth / kCardAspect + 12,
          child: dealer.cards.isEmpty
              ? Center(child: _LimitPlaque(game: game))
              : Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    HandView(hand: dealer, cardWidth: cardWidth, hideHole: game.holeDown),
                    Positioned(
                      bottom: 0,
                      child: TotalBadge(total: shown, soft: soft, tone: tone),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The sign every table carries. It stands in the dealer's place while the
/// felt is empty, and tapping it moves you to another table.
class _LimitPlaque extends StatelessWidget {
  const _LimitPlaque({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final tier = game.tier;
    final accent = AppColor.chipColor(tier.accentChip);

    return GestureDetector(
      onTap: () => showTablePicker(
        context,
        bankroll: game.bankroll,
        currentId: tier.id,
        customRules: context.read<SettingsStore>().customRules,
        onPick: context.read<SettingsStore>().setTier,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColor.feltLo.withValues(alpha: 0.24),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tier.name.toUpperCase(),
              style: AppText.eyebrow(7.5, color: AppColor.boneMid),
            ),
            const SizedBox(height: 5),
            Text(
              '${chips(tier.min)} – ${chips(tier.max)}',
              style: AppText.mono(15, weight: FontWeight.w600, color: AppColor.amber),
            ),
            const SizedBox(height: 6),
            Text('TAP TO CHANGE TABLES', style: AppText.eyebrow(6.5, color: AppColor.slate)),
          ],
        ),
      ),
    );
  }
}

class _PlayerBlock extends StatelessWidget {
  const _PlayerBlock({
    required this.game,
    required this.cardWidth,
    required this.cardHeight,
  });

  final GameController game;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    if (game.hands.isEmpty) {
      return _Spot(
        cardHeight: cardHeight,
        cards: const SizedBox.shrink(),
        chips: ChipStack(amount: game.bet, chipSize: _chipSize),
        label: game.bet > 0
            ? Text(
                'YOUR BET  ${chips(game.bet)}',
                style: AppText.eyebrow(8.5, color: AppColor.boneMid),
              )
            : Text('TAP A CHIP TO BET', style: AppText.eyebrow(8.5, color: AppColor.slate)),
      );
    }

    // Split hands scroll when they outgrow the felt, but stay centred until
    // they do — a shrink-wrapped row inside a scroll view will not centre.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < game.hands.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  _PlayerHand(
                    hand: game.hands[i],
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    active: game.phase == Phase.playerTurn && game.active == i,
                    dim: game.phase == Phase.playerTurn && game.active != i,
                    badgeScale: game.hands.length > 1 ? 0.84 : 1.0,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One betting position: cards, then the chips resting on the spot, then a
/// single line saying how it went.
class _Spot extends StatelessWidget {
  const _Spot({
    required this.cardHeight,
    required this.cards,
    required this.chips,
    required this.label,
  });

  final double cardHeight;
  final Widget cards;
  final Widget chips;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: cardHeight, child: cards),
        const SizedBox(height: _cardToChips),
        SizedBox(
          height: _chipBlock,
          child: Align(alignment: Alignment.bottomCenter, child: chips),
        ),
        SizedBox(
          height: _labelBlock,
          child: Align(alignment: Alignment.bottomCenter, child: label),
        ),
      ],
    );
  }
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({
    required this.hand,
    required this.cardWidth,
    required this.cardHeight,
    required this.active,
    required this.dim,
    this.badgeScale = 1.0,
  });

  final Hand hand;
  final double cardWidth;
  final double cardHeight;
  final bool active;
  final bool dim;

  /// Split hands sit closer together, so their badges shrink to match.
  final double badgeScale;

  @override
  Widget build(BuildContext context) {
    final outcome = hand.outcome;
    final tone = hand.isBust
        ? BadgeTone.bust
        : outcome != null && outcome.isWin
            ? BadgeTone.good
            : active
                ? BadgeTone.active
                : BadgeTone.neutral;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dim ? 0.5 : 1,
      child: _Spot(
        cardHeight: cardHeight,
        cards: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            HandView(hand: hand, cardWidth: cardWidth),
            Positioned(
              bottom: -11,
              child: TotalBadge(
                total: hand.total,
                soft: hand.isSoft,
                tone: tone,
                scale: badgeScale,
              ),
            ),
          ],
        ),
        chips: ChipStack(amount: hand.bet, chipSize: _chipSize),
        label: outcome == null
            ? (hand.doubled
                ? Text('DOUBLED', style: AppText.eyebrow(8, color: AppColor.amber))
                : const SizedBox.shrink())
            : Text(
                outcome.label.toUpperCase(),
                style: AppText.eyebrow(
                  8,
                  color: outcome.isWin
                      ? AppColor.jade
                      : outcome == Outcome.push
                          ? AppColor.boneMid
                          : AppColor.clay,
                ),
              ),
      ),
    );
  }
}

/// The call-out, printed where the table's arc runs. Results get the display
/// face; everything else stays quiet so a result always reads as a result.
class _Band extends StatelessWidget {
  const _Band({required this.game, required this.height});

  final GameController game;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = game.message;
    if (text.isEmpty) return SizedBox(height: height);

    final loud = game.phase == Phase.settled || game.phase == Phase.insurance;
    final colour = switch (game.phase) {
      Phase.settled when game.roundNet > 0 => AppColor.jade,
      Phase.settled when game.roundNet < 0 => AppColor.clay,
      Phase.insurance => AppColor.amber,
      _ => AppColor.boneMid,
    };

    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child),
        ),
        child: Column(
          key: ValueKey('$text|${game.detail}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loud)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: AppText.display(
                    height > 50 ? 32 : 26,
                    weight: 700,
                    color: colour,
                    letterSpacing: 1.6,
                    height: 1,
                  ),
                ),
              )
            else
              Text(
                text.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.eyebrow(9.5, color: AppColor.bone.withValues(alpha: 0.5)),
              ),
            if (game.detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                game.detail,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.mono(10.5, color: AppColor.slate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

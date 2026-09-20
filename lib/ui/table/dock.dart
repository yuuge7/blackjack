import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../engine/basic_strategy.dart';
import '../../state/game_controller.dart';
import '../common/table_button.dart';
import 'chip.dart';

/// Everything you can do right now, in one place at the bottom of the screen.
/// The dock keeps a fixed height so the table above it never jumps.
class TableDock extends StatelessWidget {
  const TableDock({required this.game, super.key});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      decoration: const BoxDecoration(
        color: AppColor.rail,
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          SizedBox(height: 18, child: _Ticker(game: game)),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey('${game.phase}-${game.isBroke}'),
                child: _body(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (game.isBroke) return _BuyIn(game: game);
    return switch (game.phase) {
      Phase.betting => _BetControls(game: game),
      Phase.insurance => _InsuranceControls(game: game),
      Phase.playerTurn => _PlayControls(game: game),
      Phase.settled => _SettledControls(game: game),
      Phase.dealing || Phase.dealerTurn => const _Waiting(),
    };
  }
}

/// One line of feedback: the coach's note, or what you just misplayed.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final unlocked = game.unlockedTable;
    if (unlocked != null) {
      return _Note(
        text: '$unlocked is open to you — change tables in Rules',
        colour: AppColor.amber,
      );
    }

    final demoted = game.demotedTo;
    if (demoted != null) {
      return _Note(text: 'Moved down to the $demoted table', colour: AppColor.slate);
    }

    final mistake = game.lastMistake;
    if (mistake != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColor.clay, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              mistake,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(11, color: AppColor.clay, weight: 500),
            ),
          ),
        ],
      );
    }

    if (game.phase == Phase.playerTurn && game.settings.coach) {
      final hint = game.hint;
      if (hint != null) {
        return Text(
          'Basic strategy: ${hint.move.label.toLowerCase()}  ·  ${hint.key}',
          style: AppText.ui(11, color: AppColor.boneMid),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(11, color: colour, weight: 500),
          ),
        ),
      ],
    );
  }
}

class _BetControls extends StatelessWidget {
  const _BetControls({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final denom in game.chips)
              _ChipButton(
                denom: denom,
                enabled: game.bet + denom <= game.bankroll &&
                    game.bet + denom <= game.tier.max,
                onTap: () => game.addChip(denom),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TableButton(
                label: 'Clear',
                tone: ButtonTone.quiet,
                height: 44,
                fontSize: 12,
                enabled: game.bet > 0,
                onTap: game.clearBet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: TableButton(
                label: 'DEAL',
                tone: ButtonTone.primary,
                height: 44,
                fontSize: 14,
                enabled: game.canDeal,
                onTap: game.deal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TableButton(
                label: 'Rebet',
                tone: ButtonTone.quiet,
                height: 44,
                fontSize: 12,
                onTap: game.rebet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipButton extends StatefulWidget {
  const _ChipButton({required this.denom, required this.enabled, required this.onTap});

  final int denom;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: Semantics(
          button: true,
          label: 'Bet ${widget.denom}',
          child: ChipView(denom: widget.denom, size: 46, faded: !widget.enabled),
        ),
      ),
    );
  }
}

class _PlayControls extends StatelessWidget {
  const _PlayControls({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final hint = game.settings.coach ? game.hint?.move : null;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TableButton(
                  label: 'HIT',
                  height: 52,
                  fontSize: 15,
                  enabled: game.canHit,
                  recommended: hint == Move.hit,
                  onTap: game.hit,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TableButton(
                  label: 'STAND',
                  height: 52,
                  fontSize: 15,
                  enabled: game.canStand,
                  recommended: hint == Move.stand,
                  onTap: game.stand,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TableButton(
                label: 'DOUBLE',
                height: 36,
                fontSize: 11,
                enabled: game.canDouble,
                recommended: hint == Move.double,
                onTap: game.doubleDown,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TableButton(
                label: 'SPLIT',
                height: 36,
                fontSize: 11,
                enabled: game.canSplit,
                recommended: hint == Move.split,
                onTap: game.split,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TableButton(
                label: 'SURRENDER',
                height: 36,
                fontSize: 11,
                enabled: game.canSurrender,
                recommended: hint == Move.surrender,
                onTap: game.surrender,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsuranceControls extends StatelessWidget {
  const _InsuranceControls({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final even = game.isEvenMoneyOffer;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: TableButton(
                label: even ? 'TAKE EVEN MONEY' : 'INSURE ${chips(game.bet ~/ 2)}',
                height: 52,
                fontSize: 13,
                onTap: () => game.answerInsurance(true),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TableButton(
                label: 'NO',
                height: 52,
                fontSize: 15,
                // Declining is the long-run play; the coach rings it.
                recommended: game.settings.coach,
                onTap: () => game.answerInsurance(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          even
              ? 'Even money gives up the 3 to 2 on your blackjack.'
              : 'Insurance loses money over time at this count.',
          style: AppText.ui(10.5, color: AppColor.boneMid),
        ),
      ],
    );
  }
}

class _SettledControls extends StatelessWidget {
  const _SettledControls({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TableButton(
          label: 'NEXT HAND',
          tone: ButtonTone.primary,
          height: 52,
          fontSize: 14,
          onTap: game.nextRound,
        ),
        const SizedBox(height: 10),
        Text(
          'Bet stays at ${chips(game.bet)}',
          style: AppText.mono(11, color: AppColor.boneMid),
        ),
      ],
    );
  }
}

class _BuyIn extends StatelessWidget {
  const _BuyIn({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Short of the ${chips(game.tier.min)} minimum.',
          style: AppText.ui(12.5, weight: 600),
        ),
        const SizedBox(height: 3),
        Text(
          'The house will always stake you again.',
          style: AppText.ui(11, color: AppColor.slate),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 240,
          child: TableButton(
            label: 'TAKE A ${chips(kMarkerAmount)} MARKER',
            tone: ButtonTone.primary,
            height: 46,
            fontSize: 12.5,
            onTap: game.takeMarker,
          ),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

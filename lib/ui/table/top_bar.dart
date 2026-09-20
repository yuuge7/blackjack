import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/shoe.dart';

/// Bankroll on the left, how much shoe is left in the middle, and the count on
/// the right when the trainer is showing it.
class TableTopBar extends StatelessWidget {
  const TableTopBar({
    required this.bankroll,
    required this.shoe,
    required this.showCount,
    super.key,
  });

  final int bankroll;
  final Shoe shoe;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final tc = shoe.trueCount;
    final tcColour = tc >= 2
        ? AppColor.jade
        : tc <= -2
            ? AppColor.clay
            : AppColor.boneMid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BANKROLL', style: AppText.eyebrow(8)),
              const SizedBox(height: 2),
              Text(
                chips(bankroll),
                style: AppText.mono(18, weight: FontWeight.w600, color: AppColor.bone),
              ),
            ],
          ),
          const Spacer(),
          _ShoeGauge(shoe: shoe),
          const Spacer(),
          SizedBox(
            width: 62,
            child: showCount
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TRUE COUNT', style: AppText.eyebrow(7)),
                      const SizedBox(height: 2),
                      Text(
                        '${tc >= 0 ? '+' : ''}${tc.toStringAsFixed(1)}',
                        style: AppText.mono(18, weight: FontWeight.w600, color: tcColour),
                      ),
                      Text(
                        'RC ${shoe.runningCount >= 0 ? '+' : ''}${shoe.runningCount}',
                        style: AppText.mono(9, color: AppColor.boneMid),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ShoeGauge extends StatelessWidget {
  const _ShoeGauge({required this.shoe});

  final Shoe shoe;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${shoe.decks}-DECK SHOE', style: AppText.eyebrow(8)),
        const SizedBox(height: 6),
        SizedBox(
          width: 104,
          height: 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColor.bone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: shoe.dealtFraction.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColor.bone.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              // The cut card sits at the end of the dealable portion.
              Positioned(
                right: 0,
                top: -2,
                bottom: -2,
                child: Container(width: 2.5, color: AppColor.clay),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${shoe.cardsToCut} TO CUT',
          style: AppText.mono(9, color: AppColor.boneMid),
        ),
      ],
    );
  }
}

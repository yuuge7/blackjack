import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../engine/basic_strategy.dart';
import '../../model/rules.dart';

/// The chart the trainer scores you against, rebuilt from the same code the
/// coach uses, so it always matches the table you have set up.
class StrategyChart extends StatefulWidget {
  const StrategyChart({required this.rules, super.key});

  final RuleSet rules;

  @override
  State<StrategyChart> createState() => _StrategyChartState();
}

class _StrategyChartState extends State<StrategyChart> {
  ChartRow _row = ChartRow.hard;

  static const _dealers = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

  List<int> get _players => switch (_row) {
        ChartRow.hard => [17, 16, 15, 14, 13, 12, 11, 10, 9, 8],
        ChartRow.soft => [20, 19, 18, 17, 16, 15, 14, 13],
        ChartRow.pairs => [11, 10, 9, 8, 7, 6, 5, 4, 3, 2],
      };

  String _rowLabel(int v) => switch (_row) {
        ChartRow.hard => '$v',
        ChartRow.soft => 'A${v - 11}',
        ChartRow.pairs => v == 11 ? 'A,A' : '$v,$v',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final r in ChartRow.values) ...[
              if (r != ChartRow.hard) const SizedBox(width: 6),
              _Tab(
                label: switch (r) {
                  ChartRow.hard => 'Hard',
                  ChartRow.soft => 'Soft',
                  ChartRow.pairs => 'Pairs',
                },
                on: _row == r,
                onTap: () => setState(() => _row = r),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final labelW = 40.0;
            final cell = ((c.maxWidth - labelW) / _dealers.length).clamp(20.0, 40.0);
            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Text('VS', style: AppText.eyebrow(7)),
                    ),
                    for (final d in _dealers)
                      SizedBox(
                        width: cell,
                        child: Center(
                          child: Text(
                            d == 11 ? 'A' : '$d',
                            style: AppText.mono(9.5, color: AppColor.slate),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final p in _players)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: labelW,
                          child: Text(
                            _rowLabel(p),
                            style: AppText.mono(10, weight: FontWeight.w600, color: AppColor.boneMid),
                          ),
                        ),
                        for (final d in _dealers)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: _Cell(
                              move: BasicStrategy.chartCell(
                                row: _row,
                                playerValue: p,
                                dealerValue: d,
                                rules: widget.rules,
                              ),
                              size: cell - 2,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final m in Move.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _colourFor(m),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${m.code}  ${m.label}',
                    style: AppText.ui(10.5, color: AppColor.boneMid),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _row == ChartRow.hard
              ? 'Hard 18 and up stands. Hard 7 and below hits. Double means double if you can, otherwise hit.'
              : _row == ChartRow.soft
                  ? 'Soft 21 stands. Double means double if you can, otherwise stand on soft 18 and up, hit below.'
                  : 'A pair you do not split is played as its total.',
          style: AppText.ui(10.5, color: AppColor.slate, height: 1.4),
        ),
      ],
    );
  }
}

Color _colourFor(Move m) => switch (m) {
      Move.hit => AppColor.slate,
      Move.stand => AppColor.jade,
      Move.double => AppColor.amber,
      Move.split => AppColor.violet,
      Move.surrender => AppColor.clay,
    };

class _Cell extends StatelessWidget {
  const _Cell({required this.move, required this.size});

  final Move move;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = _colourFor(move);
    return Container(
      width: size,
      height: size * 0.82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 0.7),
      ),
      child: Text(
        move.code,
        style: AppText.mono(10, weight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppColor.amber.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? AppColor.amber : AppColor.line),
        ),
        child: Text(
          label,
          style: AppText.ui(11.5, weight: 600, color: on ? AppColor.amber : AppColor.boneMid),
        ),
      ),
    );
  }
}

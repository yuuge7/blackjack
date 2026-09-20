import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Wins, pushes and losses as one bar. The scale runs good to bad, so it takes
/// two hues with a neutral in the middle rather than three arbitrary colours.
/// Every segment is labelled, so identity never rests on colour alone.
class OutcomeBar extends StatelessWidget {
  const OutcomeBar({
    required this.wins,
    required this.pushes,
    required this.losses,
    super.key,
  });

  final int wins;
  final int pushes;
  final int losses;

  @override
  Widget build(BuildContext context) {
    final total = wins + pushes + losses;
    final segments = [
      ('Won', wins, AppColor.jade),
      ('Pushed', pushes, AppColor.slate),
      ('Lost', losses, AppColor.clay),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HANDS SETTLED', style: AppText.eyebrow(8)),
        const SizedBox(height: 10),
        if (total == 0)
          Text('Nothing settled yet.', style: AppText.ui(12, color: AppColor.slate))
        else ...[
          SizedBox(
            height: 14,
            width: double.infinity,
            child: Row(
              // Stretch, so each segment is told its height. A childless
              // DecoratedBox under loose constraints collapses to nothing.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < segments.length; i++)
                  if (segments[i].$2 > 0) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segments[i].$2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: segments[i].$3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 7),
                    Text(s.$1, style: AppText.ui(11.5, color: AppColor.boneMid)),
                    const SizedBox(width: 6),
                    Text(
                      '${s.$2}',
                      style: AppText.mono(11.5, weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(s.$2 / total * 100).toStringAsFixed(0)}%',
                      style: AppText.mono(10, color: AppColor.slate),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

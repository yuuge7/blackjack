import 'package:flutter/material.dart';

import '../../design/tokens.dart';

class Panel extends StatelessWidget {
  const Panel({required this.child, this.padding = const EdgeInsets.all(14), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColor.rail,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.line),
      ),
      child: child,
    );
  }
}

/// One number with its label. No chart, because one number is not a chart.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.note,
    this.tone = AppColor.bone,
    this.big = false,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final Color tone;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.all(big ? 16 : 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow(8)),
          SizedBox(height: big ? 8 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.display(big ? 52 : 32, weight: 700, color: tone, height: 0.86),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(note!, style: AppText.mono(10, color: AppColor.slate)),
          ],
        ],
      ),
    );
  }
}

/// A labelled progress meter for rates that live between 0 and 1.
class RateMeter extends StatelessWidget {
  const RateMeter({
    required this.label,
    required this.value,
    required this.caption,
    this.colour = AppColor.amber,
    super.key,
  });

  final String label;
  final double value;
  final String caption;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label.toUpperCase(), style: AppText.eyebrow(8)),
              const Spacer(),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: AppText.display(26, weight: 700, color: colour, height: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Meter(value: value, colour: colour, height: 6),
          const SizedBox(height: 8),
          Text(caption, style: AppText.mono(10, color: AppColor.slate)),
        ],
      ),
    );
  }
}

/// A filled track. The fill is positioned, because an unconstrained
/// FractionallySizedBox inside a Stack collapses to nothing.
class Meter extends StatelessWidget {
  const Meter({
    required this.value,
    required this.colour,
    this.height = 6,
    this.track = 0.10,
    super.key,
  });

  final double value;
  final Color colour;
  final double height;
  final double track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: AppColor.bone.withValues(alpha: track)),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: colour),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label on the left, value on the right. Used for the long detail list.
class StatRow extends StatelessWidget {
  const StatRow(this.label, this.value, {this.tone = AppColor.bone, super.key});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      // The value is laid out at its natural width and the label takes what
      // is left, so a long label clips instead of pushing the number off a
      // narrow screen.
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(12.5, color: AppColor.boneMid),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(12.5, weight: FontWeight.w600, color: tone),
          ),
        ],
      ),
    );
  }
}

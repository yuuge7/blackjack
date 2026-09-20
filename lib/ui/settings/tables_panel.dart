import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/rules.dart';
import '../../model/table_tier.dart';
import '../stats/stat_tile.dart';
import '../table/chip.dart';

/// The ladder of tables. Bigger limits are the obvious draw; the reason to
/// climb is the house edge on the right, which drops every step up.
class TablesPanel extends StatelessWidget {
  const TablesPanel({
    required this.bankroll,
    required this.currentId,
    required this.customRules,
    required this.onPick,
    super.key,
  });

  final int bankroll;
  final String currentId;
  final RuleSet customRules;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final next = nextTierAbove(bankroll);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in kTiers) ...[
          _TableRow(
            tier: t,
            edge: (t.isCustom ? customRules : t.rules).houseEdge,
            seated: t.id == currentId,
            locked: bankroll < t.sitMin,
            shortBy: t.sitMin - bankroll,
            onTap: () => onPick(t.id),
          ),
          if (t != kTiers.last) const SizedBox(height: 8),
        ],
        if (next != null) ...[
          const SizedBox(height: 16),
          _NextUp(tier: next, bankroll: bankroll),
        ],
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.tier,
    required this.edge,
    required this.seated,
    required this.locked,
    required this.shortBy,
    required this.onTap,
  });

  final TableTier tier;
  final double edge;
  final bool seated;
  final bool locked;
  final int shortBy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColor.chipColor(tier.accentChip);

    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: GestureDetector(
        onTap: locked ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: seated ? AppColor.amber.withValues(alpha: 0.08) : AppColor.railHi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: seated ? AppColor.amber : AppColor.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ChipView(denom: tier.accentChip, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tier.name,
                            style: AppText.ui(13.5, weight: 600),
                          ),
                        ),
                        if (seated) ...[
                          const SizedBox(width: 8),
                          Text('SEATED', style: AppText.eyebrow(7.5, color: AppColor.amber)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${chips(tier.min)} – ${chips(tier.max)}',
                      style: AppText.mono(11.5, color: accent),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      locked
                          ? 'Sit down with ${chips(tier.sitMin)}. You need ${chips(shortBy)} more.'
                          : tier.blurb,
                      style: AppText.ui(10.5, color: AppColor.slate, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('EDGE', style: AppText.eyebrow(7)),
                  const SizedBox(height: 3),
                  Text(
                    '${edge.toStringAsFixed(2)}%',
                    style: AppText.mono(
                      13,
                      weight: FontWeight.w600,
                      color: edge <= 0.25
                          ? AppColor.jade
                          : edge <= 0.75
                              ? AppColor.amber
                              : AppColor.clay,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.tier, required this.bankroll});

  final TableTier tier;
  final int bankroll;

  @override
  Widget build(BuildContext context) {
    final previous = kTiers
        .where((t) => !t.isCustom && t.sitMin < tier.sitMin)
        .fold<int>(0, (a, t) => t.sitMin > a ? t.sitMin : a);
    final span = (tier.sitMin - previous).clamp(1, 1 << 30);
    final progress = ((bankroll - previous) / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('NEXT TABLE', style: AppText.eyebrow(8)),
            const Spacer(),
            Text(
              '${chips(tier.sitMin - bankroll)} to go',
              style: AppText.mono(10.5, color: AppColor.slate),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Meter(value: progress, colour: AppColor.amber, height: 6),
        const SizedBox(height: 8),
        Text(
          '${tier.name} takes ${chips(tier.min)} to ${chips(tier.max)} a hand, '
          'at ${tier.rules.houseEdge.toStringAsFixed(2)}% house edge.',
          style: AppText.ui(11, color: AppColor.boneMid, height: 1.4),
        ),
      ],
    );
  }
}

/// The same list as a sheet, so the felt's table sign can open it.
Future<void> showTablePicker(
  BuildContext context, {
  required int bankroll,
  required String currentId,
  required RuleSet customRules,
  required ValueChanged<String> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColor.rail,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Change tables', style: AppText.display(26, weight: 700, height: 0.95)),
              const SizedBox(height: 4),
              Text(
                'Your bankroll: ${chips(bankroll)}',
                style: AppText.mono(11.5, color: AppColor.slate),
              ),
              const SizedBox(height: 16),
              TablesPanel(
                bankroll: bankroll,
                currentId: currentId,
                customRules: customRules,
                onPick: (id) {
                  onPick(id);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

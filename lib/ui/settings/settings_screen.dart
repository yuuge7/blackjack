import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/rules.dart';
import '../../model/table_tier.dart';
import '../../state/game_controller.dart';
import '../../state/settings_store.dart';
import '../common/amount_sheet.dart';
import '../stats/stat_tile.dart';
import 'strategy_chart.dart';
import 'tables_panel.dart';
import 'transfer_panel.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final game = context.watch<GameController>();
    final r = settings.rules;
    final editable = settings.canEditRules;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text('Rules', style: AppText.display(34, weight: 700, height: 0.9)),
        const SizedBox(height: 14),
        _EdgePanel(rules: r, tier: settings.tier),
        const SizedBox(height: 18),
        const _Header('The tables'),
        Panel(
          child: TablesPanel(
            bankroll: game.bankroll,
            currentId: settings.tier.id,
            customTier: settings.customTier,
            onPick: settings.setTier,
          ),
        ),
        const SizedBox(height: 22),
        _Header(editable ? 'Your house rules' : 'Posted at the ${settings.tier.name} table'),
        if (!editable) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'The floor sets these. Sit at the house-rules table to change them.',
              style: AppText.ui(11, color: AppColor.slate, height: 1.4),
            ),
          ),
        ],
        _Locked(
          locked: !editable,
          child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stakes(settings: settings, editable: editable),
              const _Rule(),
              _Options<int>(
                label: 'Decks in the shoe',
                value: r.decks,
                options: const [1, 2, 4, 6, 8],
                labelOf: (v) => '$v',
                onChanged: (v) => settings.setRules(r.copyWith(decks: v)),
              ),
              const _Rule(),
              _Options<bool>(
                label: 'Dealer on soft 17',
                value: r.dealerHitsSoft17,
                options: const [false, true],
                labelOf: (v) => v ? 'Hits' : 'Stands',
                onChanged: (v) => settings.setRules(r.copyWith(dealerHitsSoft17: v)),
              ),
              const _Rule(),
              _Options<Payout>(
                label: 'Blackjack pays',
                value: r.payout,
                options: Payout.values,
                labelOf: (v) => v.label,
                onChanged: (v) => settings.setRules(r.copyWith(payout: v)),
              ),
              const _Rule(),
              _Options<DoubleRule>(
                label: 'You may double on',
                value: r.doubleRule,
                options: DoubleRule.values,
                labelOf: (v) => switch (v) {
                  DoubleRule.any => 'Any two',
                  DoubleRule.nineToEleven => '9–11',
                  DoubleRule.tenEleven => '10–11',
                },
                onChanged: (v) => settings.setRules(r.copyWith(doubleRule: v)),
              ),
              const _Rule(),
              _Options<int>(
                label: 'Hands you may split to',
                value: r.maxHands,
                options: const [2, 3, 4],
                labelOf: (v) => '$v',
                onChanged: (v) => settings.setRules(r.copyWith(maxHands: v)),
              ),
              const _Rule(),
              _Toggle(
                label: 'Double after split',
                on: r.doubleAfterSplit,
                onChanged: (v) => settings.setRules(r.copyWith(doubleAfterSplit: v)),
              ),
              _Toggle(
                label: 'Late surrender',
                note: 'Give up half your bet on the first two cards.',
                on: r.lateSurrender,
                onChanged: (v) => settings.setRules(r.copyWith(lateSurrender: v)),
              ),
              _Toggle(
                label: 'Resplit aces',
                on: r.resplitAces,
                onChanged: (v) => settings.setRules(r.copyWith(resplitAces: v)),
              ),
              _Toggle(
                label: 'Hit split aces',
                note: 'Off means each split ace draws one card and stands.',
                on: r.hitSplitAces,
                onChanged: (v) => settings.setRules(r.copyWith(hitSplitAces: v)),
              ),
              const _Rule(),
              _Slider(
                label: 'Deck penetration',
                value: r.penetration,
                min: 0.5,
                max: 0.9,
                readout: '${(r.penetration * 100).round()}%',
                note: 'How deep the cut card sits. Deeper shoes reward counting.',
                onChanged: (v) => settings.setRules(r.copyWith(penetration: v)),
              ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A change to the shoe takes effect on the next deal.',
          style: AppText.ui(11, color: AppColor.slate),
        ),
        const SizedBox(height: 22),
        const _Header('The trainer'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toggle(
                label: 'Ring the basic strategy play',
                note: 'Outlines the move the chart would make, before you act.',
                on: settings.coach,
                onChanged: settings.setCoach,
              ),
              _Toggle(
                label: 'Call out misplays',
                note: 'Tells you what the chart wanted after you deviate.',
                on: settings.flagMistakes,
                onChanged: settings.setFlagMistakes,
              ),
              _Toggle(
                label: 'Show the running count',
                note: 'Hi-Lo running and true count on the table.',
                on: settings.showCount,
                onChanged: settings.setShowCount,
              ),
              _Toggle(
                label: 'Haptics',
                on: settings.haptics,
                onChanged: settings.setHaptics,
              ),
              _Toggle(
                label: 'Fast deal',
                note: 'Halves the pause between cards.',
                on: settings.fastDeal,
                onChanged: settings.setFastDeal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _Header('Basic strategy'),
        Panel(child: StrategyChart(rules: r)),
        const SizedBox(height: 22),
        const _Header('Moving your save'),
        const TransferPanel(),
      ],
    );
  }
}

/// The stakes at your own table. Preset tables post limits the floor sets, so
/// this is the one table where the numbers are yours to type.
class _Stakes extends StatelessWidget {
  const _Stakes({required this.settings, required this.editable});

  final SettingsStore settings;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final tier = settings.tier;
    final min = settings.customMin;
    final max = settings.customMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AmountField(
                label: 'Table minimum',
                value: min,
                onTap: () async {
                  final picked = await askAmount(
                    context,
                    title: 'Table minimum',
                    initial: min,
                    min: kMinStake,
                    max: kMaxStake,
                    note: 'The smallest bet your table will take. Raising it above '
                        'the maximum pushes the maximum up with it.',
                    presets: const [
                      AmountPreset('1', 1),
                      AmountPreset('5', 5),
                      AmountPreset('25', 25),
                      AmountPreset('100', 100),
                      AmountPreset('1K', 1000),
                      AmountPreset('25K', 25000),
                    ],
                  );
                  if (picked != null) settings.setCustomLimits(min: picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AmountField(
                label: 'Table maximum',
                value: max,
                onTap: () async {
                  final picked = await askAmount(
                    context,
                    title: 'Table maximum',
                    initial: max,
                    min: min,
                    max: kMaxStake,
                    note: 'The biggest bet your table will take, up to '
                        '${chips(kMaxStake)}.',
                    presets: [
                      const AmountPreset('500', 500),
                      const AmountPreset('2.5K', 2500),
                      const AmountPreset('10K', 10000),
                      const AmountPreset('100K', 100000),
                      const AmountPreset('1M', 1000000),
                      AmountPreset('100×', min * 100),
                    ],
                  );
                  if (picked != null) settings.setCustomLimits(max: picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('RACK', style: AppText.eyebrow(7.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tier.chips.map(chipFace).join('  ·  '),
                style: AppText.mono(11, color: AppColor.amber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          editable
              ? 'The rack follows your limits. Any amount the chips will not '
                  'stack exactly, you can type at the table.'
              : 'These are the stakes at your own table. Sit there to change them.',
          style: AppText.ui(10.5, color: AppColor.slate, height: 1.35),
        ),
      ],
    );
  }
}

/// A tappable read-out that opens the number pad.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.label, required this.value, required this.onTap});

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, currently ${chips(value)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(
            color: AppColor.railHi,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColor.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(), style: AppText.eyebrow(7.5)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        chips(value),
                        style: AppText.display(24, weight: 700, height: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 13, color: AppColor.slate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims and disables a section that the current table does not let you touch.
class _Locked extends StatelessWidget {
  const _Locked({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
        absorbing: locked,
        child: Opacity(opacity: locked ? 0.55 : 1, child: child),
      );
}

class _EdgePanel extends StatelessWidget {
  const _EdgePanel({required this.rules, required this.tier});

  final RuleSet rules;
  final TableTier tier;

  @override
  Widget build(BuildContext context) {
    final edge = rules.houseEdge;
    final tone = edge <= 0.5
        ? AppColor.jade
        : edge <= 1.0
            ? AppColor.amber
            : AppColor.clay;

    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('HOUSE EDGE', style: AppText.eyebrow(8)),
              const SizedBox(height: 4),
              Text(
                '${edge.toStringAsFixed(2)}%',
                style: AppText.display(40, weight: 700, color: tone, height: 0.86),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tier.name}  ·  ${chips(tier.min)}–${chips(tier.max)}',
                  style: AppText.mono(11.5, color: AppColor.amber),
                ),
                const SizedBox(height: 5),
                Text(
                  'What this table costs you per chip wagered, if you play the '
                  'chart perfectly. Move up and it drops.',
                  style: AppText.ui(11.5, color: AppColor.boneMid, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text.toUpperCase(), style: AppText.eyebrow(9)),
      );
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, thickness: 1, color: AppColor.line),
      );
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.ui(12.5, weight: 500)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final o in options)
              GestureDetector(
                onTap: () => onChanged(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: o == value ? AppColor.amber.withValues(alpha: 0.16) : AppColor.railHi,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: o == value ? AppColor.amber : AppColor.line),
                  ),
                  child: Text(
                    labelOf(o),
                    style: AppText.mono(
                      11.5,
                      weight: FontWeight.w600,
                      color: o == value ? AppColor.amber : AppColor.boneMid,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.onChanged,
    this.note,
  });

  final String label;
  final String? note;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.ui(12.5, weight: 500)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: AppText.ui(10.5, color: AppColor.slate, height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.82,
            child: Switch(value: on, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.readout,
    required this.onChanged,
    this.note,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String readout;
  final String? note;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.ui(12.5, weight: 500)),
            const Spacer(),
            Text(readout, style: AppText.mono(12, weight: FontWeight.w600, color: AppColor.amber)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 8,
            onChanged: onChanged,
          ),
        ),
        if (note != null)
          Text(note!, style: AppText.ui(10.5, color: AppColor.slate, height: 1.35)),
      ],
    );
  }
}

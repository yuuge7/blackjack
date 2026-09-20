import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/stats.dart';
import '../../state/stats_store.dart';
import '../common/table_button.dart';
import 'bankroll_chart.dart';
import 'outcome_bar.dart';
import 'stat_tile.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsScope _scope = StatsScope.session;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StatsStore>();
    final s = store.of(_scope);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Stats', style: AppText.display(34, weight: 700, height: 0.9)),
            const Spacer(),
            _Segmented(
              scope: _scope,
              onChanged: (v) => setState(() => _scope = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (s.isEmpty)
          const _Empty()
        else ...[
          _Hero(stats: s),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Win rate',
                  value: '${(s.winRate * 100).toStringAsFixed(1)}%',
                  note: '${s.wins}W · ${s.losses}L · ${s.pushes}P',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Below a couple of dozen rounds this number is noise, so it
                // says so rather than pretending to be a measurement.
                child: s.rounds < 20
                    ? const StatTile(
                        label: 'Realized edge',
                        value: '—',
                        note: 'Needs 20 rounds',
                        tone: AppColor.slate,
                      )
                    : StatTile(
                        label: 'Realized edge',
                        value:
                            '${s.realizedEdge >= 0 ? '+' : ''}${s.realizedEdge.toStringAsFixed(2)}%',
                        note: 'House take per chip',
                        tone: s.realizedEdge > 0 ? AppColor.clay : AppColor.jade,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Panel(child: OutcomeBar(wins: s.wins, pushes: s.pushes, losses: s.losses)),
          const SizedBox(height: 12),
          RateMeter(
            label: 'Basic strategy accuracy',
            value: s.accuracy,
            colour: s.accuracy >= 0.95
                ? AppColor.jade
                : s.accuracy >= 0.85
                    ? AppColor.amber
                    : AppColor.clay,
            caption: '${s.correct} of ${s.decisions} decisions matched the chart',
          ),
          const SizedBox(height: 12),
          _Leaks(stats: s),
          const SizedBox(height: 12),
          _Ledger(stats: s),
          const SizedBox(height: 18),
          _ResetRow(scope: _scope, store: store),
        ],
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.scope, required this.onChanged});

  final StatsScope scope;
  final ValueChanged<StatsScope> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(StatsScope value, String label) {
      final on = scope == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: on ? AppColor.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppText.ui(11, weight: 600, color: on ? AppColor.ink : AppColor.boneMid),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColor.rail,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColor.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(StatsScope.session, 'Session'),
          item(StatsScope.lifetime, 'All time'),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final StatsData stats;

  @override
  Widget build(BuildContext context) {
    final net = stats.net;
    final tone = net > 0
        ? AppColor.jade
        : net < 0
            ? AppColor.clay
            : AppColor.bone;

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET RESULT', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                signedChips(net),
                style: AppText.display(58, weight: 700, color: tone, height: 0.82),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'over ${stats.rounds} round${stats.rounds == 1 ? '' : 's'}\n${stats.wagered} wagered',
                  style: AppText.mono(10.5, color: AppColor.slate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BankrollChart(values: stats.bankrollHistory),
        ],
      ),
    );
  }
}

class _Leaks extends StatelessWidget {
  const _Leaks({required this.stats});

  final StatsData stats;

  @override
  Widget build(BuildContext context) {
    final leaks = stats.topLeaks();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRACTISE THESE', style: AppText.eyebrow(8)),
          const SizedBox(height: 4),
          Text(
            leaks.isEmpty
                ? 'No misplays on record. Keep it that way.'
                : 'The spots you misplay most often.',
            style: AppText.ui(11.5, color: AppColor.slate),
          ),
          if (leaks.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in leaks) ...[
              _LeakRow(name: e.key, leak: e.value),
              if (e != leaks.last) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _LeakRow extends StatelessWidget {
  const _LeakRow({required this.name, required this.leak});

  final String name;
  final Leak leak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, style: AppText.ui(12.5, weight: 500)),
            ),
            Text(
              '${leak.wrong}/${leak.total}',
              style: AppText.mono(11, weight: FontWeight.w600, color: AppColor.clay),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Meter(
          value: leak.errorRate.clamp(0.03, 1.0),
          colour: AppColor.clay,
          height: 4,
          track: 0.08,
        ),
        if (leak.lastMistake.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Last played: ${leak.lastMistake.toLowerCase()}',
            style: AppText.mono(9.5, color: AppColor.slate),
          ),
        ],
      ],
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.stats});

  final StatsData stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE LEDGER', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          StatRow('Rounds dealt', chips(s.rounds)),
          StatRow('Hands played', chips(s.hands)),
          StatRow('Average bet', chips(s.avgBet.round())),
          StatRow('Total wagered', chips(s.wagered)),
          const _Rule(),
          StatRow('Blackjacks', '${s.blackjacks}', tone: AppColor.jade),
          StatRow('You busted', '${s.busts}', tone: AppColor.clay),
          StatRow('Dealer busted', '${s.dealerBusts}', tone: AppColor.jade),
          const _Rule(),
          StatRow('Doubles taken', '${s.doubles}'),
          StatRow('Hands split', '${s.splits}'),
          StatRow('Surrenders', '${s.surrenders}'),
          StatRow(
            'Insurance',
            s.insuranceTaken == 0 ? 'Never taken' : '${s.insuranceWon}/${s.insuranceTaken} paid',
          ),
          const _Rule(),
          StatRow(
            'Biggest win',
            s.biggestWin > 0 ? signedChips(s.biggestWin) : '—',
            tone: s.biggestWin > 0 ? AppColor.jade : AppColor.slate,
          ),
          StatRow(
            'Biggest loss',
            s.biggestLoss < 0 ? chips(s.biggestLoss) : '—',
            tone: s.biggestLoss < 0 ? AppColor.clay : AppColor.slate,
          ),
          StatRow('Best win streak', '${s.bestWinStreak}', tone: AppColor.jade),
          StatRow('Worst losing run', '${-s.worstLossStreak}', tone: AppColor.clay),
          const _Rule(),
          StatRow(
            'Markers taken',
            s.markers == 0 ? 'None' : '${s.markers}  (${chips(s.marked)})',
            tone: s.markers == 0 ? AppColor.jade : AppColor.slate,
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(height: 1, thickness: 1, color: AppColor.line),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing to show yet', style: AppText.display(26, weight: 700, height: 0.95)),
          const SizedBox(height: 8),
          Text(
            'Deal a hand on the table. Every decision you make is scored against '
            'basic strategy, and the result lands here.',
            style: AppText.ui(13, color: AppColor.boneMid, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  const _ResetRow({required this.scope, required this.store});

  final StatsScope scope;
  final StatsStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TableButton(
            label: 'Reset session',
            tone: ButtonTone.neutral,
            height: 42,
            fontSize: 12,
            onTap: store.resetSession,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TableButton(
            label: 'Clear all stats',
            tone: ButtonTone.danger,
            height: 42,
            fontSize: 12,
            onTap: () => _confirm(context),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.rail,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear all stats?', style: AppText.ui(16, weight: 600)),
        content: Text(
          'This erases your lifetime record, the bankroll curve and every '
          'decision scored so far. It cannot be undone.',
          style: AppText.ui(13, color: AppColor.boneMid, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep them', style: AppText.ui(13, color: AppColor.boneMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: AppText.ui(13, weight: 600, color: AppColor.clay)),
          ),
        ],
      ),
    );
    if (ok ?? false) store.resetLifetime();
  }
}

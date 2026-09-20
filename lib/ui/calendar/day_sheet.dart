import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/day_stats.dart';
import '../../state/day_stats_store.dart';
import '../stats/outcome_bar.dart';
import '../stats/stat_tile.dart';

/// One day, opened from the grid: what was played, and what was played on the
/// same date in every earlier year on record.
class DaySheet extends StatelessWidget {
  const DaySheet({required this.date, required this.store, super.key});

  final DateTime date;
  final DayStatsStore store;

  static Future<void> show(BuildContext context, DateTime date, DayStatsStore store) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColor.rail,
      barrierColor: AppColor.feltLo.withValues(alpha: 0.72),
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DaySheet(date: date, store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = store.day(date);
    final history = store.onThisDay(date.month, date.day, excludeYear: date.year);
    final weekday = _weekdayName(date.weekday);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      maxChildSize: 0.94,
      minChildSize: 0.42,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 30),
        children: [
          Text(
            '$weekday ${date.day} ${kMonthNames[date.month - 1]} ${date.year}',
            style: AppText.display(30, weight: 700, height: 0.95),
          ),
          const SizedBox(height: 14),
          if (day == null)
            const _NotPlayed()
          else ...[
            _DayHero(day: day),
            const SizedBox(height: 12),
            Panel(
              child: OutcomeBar(wins: day.wins, pushes: day.pushes, losses: day.losses),
            ),
            const SizedBox(height: 12),
            _DayLedger(day: day),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('ON THIS DAY', style: AppText.eyebrow(8)),
            const SizedBox(height: 4),
            Text(
              'The ${_ordinal(date.day)} of ${kMonthNames[date.month - 1]}, in every '
              'other year you have played it.',
              style: AppText.ui(11.5, color: AppColor.slate, height: 1.4),
            ),
            const SizedBox(height: 10),
            for (final e in history) ...[
              _PastYearRow(year: e.key, day: e.value),
              const SizedBox(height: 8),
            ],
          ] else if (day != null) ...[
            const SizedBox(height: 18),
            Text(
              'First time you have played this date. Next year it will have '
              'something to sit next to.',
              style: AppText.ui(11.5, color: AppColor.slate, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  static String _weekdayName(int weekday) => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ][weekday - 1];

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

class _DayHero extends StatelessWidget {
  const _DayHero({required this.day});

  final DayStats day;

  @override
  Widget build(BuildContext context) {
    final tone = day.net > 0
        ? AppColor.jade
        : day.net < 0
            ? AppColor.clay
            : AppColor.bone;

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET ON THE DAY', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    signedChips(day.net),
                    style: AppText.display(52, weight: 700, color: tone, height: 0.84),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${day.rounds} round${day.rounds == 1 ? '' : 's'}\n'
                  '${chips(day.wagered)} wagered',
                  style: AppText.mono(10, color: AppColor.slate, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Mini(
                  label: 'Win rate',
                  value: '${(day.winRate * 100).toStringAsFixed(0)}%',
                ),
              ),
              Expanded(
                child: _Mini(
                  label: 'Accuracy',
                  value: day.decisions == 0
                      ? '—'
                      : '${(day.accuracy * 100).toStringAsFixed(0)}%',
                  tone: day.decisions == 0
                      ? AppColor.slate
                      : day.accuracy >= 0.95
                          ? AppColor.jade
                          : day.accuracy >= 0.85
                              ? AppColor.amber
                              : AppColor.clay,
                ),
              ),
              Expanded(
                child: _Mini(
                  label: 'Sessions',
                  value: '${day.sessions == 0 ? 1 : day.sessions}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.tone = AppColor.bone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.eyebrow(7.5)),
        const SizedBox(height: 4),
        Text(value, style: AppText.display(22, weight: 700, color: tone, height: 0.9)),
      ],
    );
  }
}

class _DayLedger extends StatelessWidget {
  const _DayLedger({required this.day});

  final DayStats day;

  @override
  Widget build(BuildContext context) {
    final d = day;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE DAY IN FULL', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          StatRow('Hands played', chips(d.hands)),
          StatRow('Average bet', chips(d.avgBet.round())),
          if (d.rounds >= 20)
            StatRow(
              'Realized edge',
              '${d.realizedEdge >= 0 ? '+' : ''}${d.realizedEdge.toStringAsFixed(2)}%',
              tone: d.realizedEdge > 0 ? AppColor.clay : AppColor.jade,
            ),
          const _Rule(),
          StatRow('Blackjacks', '${d.blackjacks}', tone: AppColor.jade),
          StatRow('You busted', '${d.busts}', tone: AppColor.clay),
          StatRow('Dealer busted', '${d.dealerBusts}', tone: AppColor.jade),
          const _Rule(),
          StatRow('Doubles taken', '${d.doubles}'),
          StatRow('Hands split', '${d.splits}'),
          StatRow('Surrenders', '${d.surrenders}'),
          if (d.insuranceTaken > 0)
            StatRow('Insurance', '${d.insuranceWon}/${d.insuranceTaken} paid'),
          const _Rule(),
          StatRow(
            'Best round',
            d.biggestWin > 0 ? signedChips(d.biggestWin) : '—',
            tone: d.biggestWin > 0 ? AppColor.jade : AppColor.slate,
          ),
          StatRow(
            'Worst round',
            d.biggestLoss < 0 ? chips(d.biggestLoss) : '—',
            tone: d.biggestLoss < 0 ? AppColor.clay : AppColor.slate,
          ),
          StatRow('Best win streak', '${d.bestWinStreak}', tone: AppColor.jade),
          StatRow('Worst losing run', '${-d.worstLossStreak}', tone: AppColor.clay),
          if (d.markers > 0)
            StatRow('Markers taken', '${d.markers}  (${chips(d.marked)})', tone: AppColor.slate),
        ],
      ),
    );
  }
}

/// The same date, a year or more ago.
class _PastYearRow extends StatelessWidget {
  const _PastYearRow({required this.year, required this.day});

  final int year;
  final DayStats day;

  @override
  Widget build(BuildContext context) {
    final tone = day.net > 0
        ? AppColor.jade
        : day.net < 0
            ? AppColor.clay
            : AppColor.boneMid;

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Text('$year', style: AppText.display(26, weight: 700, height: 0.9)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.rounds} rounds · ${day.wins}W ${day.losses}L ${day.pushes}P',
                  style: AppText.mono(10.5, color: AppColor.boneMid),
                ),
                const SizedBox(height: 3),
                Text(
                  day.decisions == 0
                      ? '${chips(day.wagered)} wagered'
                      : '${(day.accuracy * 100).toStringAsFixed(0)}% accurate · '
                          '${chips(day.wagered)} wagered',
                  style: AppText.mono(9.5, color: AppColor.slate),
                ),
              ],
            ),
          ),
          Text(
            signedChips(day.net),
            style: AppText.mono(14, weight: FontWeight.w600, color: tone),
          ),
        ],
      ),
    );
  }
}

class _NotPlayed extends StatelessWidget {
  const _NotPlayed();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Text(
        'Nothing was dealt on this date.',
        style: AppText.ui(13, color: AppColor.boneMid, height: 1.4),
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

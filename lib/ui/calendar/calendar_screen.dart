import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/day_stats.dart';
import '../../state/day_stats_store.dart';
import '../stats/stat_tile.dart';
import 'day_sheet.dart';
import 'day_tone.dart';
import 'month_grid.dart';
import 'year_heatmap.dart';

enum CalendarView { month, year }

/// Every day you have ever played, as a calendar.
///
/// Month view is the grid you scroll back through; year view is the whole year
/// at a glance with month-by-month totals under it. Both open the same day
/// sheet, which is where the year-over-year comparison lives.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarView _view = CalendarView.month;
  late DateTime _cursor = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DayStatsStore>();
    final today = dayOf(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Calendar', style: AppText.display(34, weight: 700, height: 0.9)),
              ),
            ),
            const SizedBox(width: 10),
            _ViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
          ],
        ),
        const SizedBox(height: 14),
        if (store.isEmpty)
          const _Empty()
        else if (_view == CalendarView.month)
          _MonthView(
            store: store,
            cursor: _cursor,
            today: today,
            onCursor: (d) => setState(() => _cursor = d),
            onOpenYear: () => setState(() => _view = CalendarView.year),
          )
        else
          _YearView(
            store: store,
            year: _cursor.year,
            today: today,
            onYear: (y) => setState(() => _cursor = DateTime(y, _cursor.month)),
            onOpenMonth: (m) => setState(() {
              _cursor = DateTime(_cursor.year, m);
              _view = CalendarView.month;
            }),
          ),
      ],
    );
  }
}

// --- month ------------------------------------------------------------------

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.store,
    required this.cursor,
    required this.today,
    required this.onCursor,
    required this.onOpenYear,
  });

  final DayStatsStore store;
  final DateTime cursor;
  final DateTime today;
  final ValueChanged<DateTime> onCursor;
  final VoidCallback onOpenYear;

  @override
  Widget build(BuildContext context) {
    final days = store.month(cursor.year, cursor.month);
    final period = store.monthTotals(cursor.year, cursor.month);
    final tone = DayTone.forDays(days.values);

    // The same month, last year and the year before: the month-level answer to
    // the question the day sheet answers per day.
    final priorYears = <int, PeriodStats>{};
    for (final y in store.years) {
      if (y >= cursor.year) continue;
      final p = store.monthTotals(y, cursor.month);
      if (!p.isEmpty) priorYears[y] = p;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stepper(
          label: '${kMonthNames[cursor.month - 1]} ${cursor.year}',
          onPrev: () => onCursor(DateTime(cursor.year, cursor.month - 1)),
          onNext: _isCurrentMonth ? null : () => onCursor(DateTime(cursor.year, cursor.month + 1)),
          onLabelTap: onOpenYear,
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              MonthGrid(
                year: cursor.year,
                month: cursor.month,
                days: days,
                tone: tone,
                today: today,
                onPick: (d) => DaySheet.show(context, d, store),
              ),
              const SizedBox(height: 12),
              ToneLegend(peak: tone.peak == 1 && days.isEmpty ? 0 : tone.peak),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PeriodPanel(
          eyebrow: 'THIS MONTH',
          period: period,
          totalDays: daysInMonth(cursor.year, cursor.month),
        ),
        if (priorYears.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kMonthNames[cursor.month - 1].toUpperCase()} IN OTHER YEARS',
                  style: AppText.eyebrow(8),
                ),
                const SizedBox(height: 10),
                for (final y in priorYears.keys.toList().reversed) ...[
                  _YearCompareRow(year: y, period: priorYears[y]!),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return cursor.year == now.year && cursor.month == now.month;
  }
}

// --- year -------------------------------------------------------------------

class _YearView extends StatelessWidget {
  const _YearView({
    required this.store,
    required this.year,
    required this.today,
    required this.onYear,
    required this.onOpenMonth,
  });

  final DayStatsStore store;
  final int year;
  final DateTime today;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final days = store.year(year);
    final period = store.yearTotals(year);
    final tone = DayTone.forDays(days.values);

    final byMonth = <int, PeriodStats>{};
    for (var m = 1; m <= 12; m++) {
      final p = store.monthTotals(year, m);
      if (!p.isEmpty) byMonth[m] = p;
    }

    final known = store.years;
    final hasEarlier = known.any((y) => y < year);
    final hasLater = known.any((y) => y > year) || year < DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stepper(
          label: '$year',
          onPrev: hasEarlier || year > (known.isEmpty ? year : known.first)
              ? () => onYear(year - 1)
              : null,
          onNext: hasLater ? () => onYear(year + 1) : null,
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YearHeatmap(
                year: year,
                days: days,
                tone: tone,
                today: today,
                onPick: (d) => DaySheet.show(context, d, store),
              ),
              const SizedBox(height: 12),
              ToneLegend(peak: days.isEmpty ? 0 : tone.peak),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PeriodPanel(eyebrow: 'THIS YEAR', period: period, totalDays: _daysInYear(year)),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MONTH BY MONTH', style: AppText.eyebrow(8)),
              const SizedBox(height: 12),
              MonthBars(year: year, byMonth: byMonth, onPick: onOpenMonth),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AllTimePanel(store: store),
      ],
    );
  }

  static int _daysInYear(int y) => DateTime(y, 12, 31).difference(DateTime(y, 1, 1)).inDays + 1;
}

// --- shared pieces ----------------------------------------------------------

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, this.onPrev, this.onNext, this.onLabelTap});

  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, VoidCallback? tap, String hint) => Semantics(
          button: true,
          enabled: tap != null,
          label: hint,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColor.railHi,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColor.line),
              ),
              child: Icon(
                icon,
                size: 17,
                color: tap == null ? AppColor.slate.withValues(alpha: 0.4) : AppColor.bone,
              ),
            ),
          ),
        );

    return Row(
      children: [
        arrow(Icons.chevron_left_rounded, onPrev, 'Previous'),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLabelTap,
            child: Center(
              child: Text(label, style: AppText.display(24, weight: 700, height: 1)),
            ),
          ),
        ),
        arrow(Icons.chevron_right_rounded, onNext, 'Next'),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final CalendarView view;
  final ValueChanged<CalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(CalendarView value, String label) {
      final on = view == value;
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
          item(CalendarView.month, 'Month'),
          item(CalendarView.year, 'Year'),
        ],
      ),
    );
  }
}

/// The totals block shared by the month and year views.
class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel({
    required this.eyebrow,
    required this.period,
    required this.totalDays,
  });

  final String eyebrow;
  final PeriodStats period;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final t = period.totals;
    final tone = t.net > 0
        ? AppColor.jade
        : t.net < 0
            ? AppColor.clay
            : AppColor.bone;

    if (period.isEmpty) {
      return Panel(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow, style: AppText.eyebrow(8)),
            const SizedBox(height: 8),
            Text(
              'Nothing dealt here yet.',
              style: AppText.ui(13, color: AppColor.boneMid),
            ),
          ],
        ),
      );
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    signedChips(t.net),
                    style: AppText.display(48, weight: 700, color: tone, height: 0.84),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${period.daysPlayed} of $totalDays days\n${t.rounds} rounds',
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
                  value: '${(t.winRate * 100).toStringAsFixed(1)}%',
                ),
              ),
              Expanded(
                child: _Mini(
                  label: 'Accuracy',
                  value: t.decisions == 0 ? '—' : '${(t.accuracy * 100).toStringAsFixed(0)}%',
                ),
              ),
              Expanded(
                child: _Mini(label: 'Wagered', value: chips(t.wagered)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColor.line),
          const SizedBox(height: 6),
          if (period.bestDay != null)
            StatRow('Best day', _dayLabel(period.bestDay!), tone: AppColor.jade),
          if (period.worstDay != null)
            StatRow('Worst day', _dayLabel(period.worstDay!), tone: AppColor.clay),
          if (period.busiestDay != null)
            StatRow('Most rounds', _dayLabel(period.busiestDay!)),
          StatRow('Sessions', '${t.sessions}'),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime d) => '${d.day} ${kMonthShort[d.month - 1]} ${d.year}';
}

class _YearCompareRow extends StatelessWidget {
  const _YearCompareRow({required this.year, required this.period});

  final int year;
  final PeriodStats period;

  @override
  Widget build(BuildContext context) {
    final net = period.totals.net;
    final tone = net > 0
        ? AppColor.jade
        : net < 0
            ? AppColor.clay
            : AppColor.boneMid;

    return Row(
      children: [
        SizedBox(width: 42, child: Text('$year', style: AppText.mono(12, weight: FontWeight.w600))),
        Expanded(
          child: Text(
            '${period.daysPlayed} day${period.daysPlayed == 1 ? '' : 's'} · '
            '${period.totals.rounds} rounds',
            style: AppText.mono(10.5, color: AppColor.slate),
          ),
        ),
        Text(
          signedChips(net),
          style: AppText.mono(12, weight: FontWeight.w600, color: tone),
        ),
      ],
    );
  }
}

class _AllTimePanel extends StatefulWidget {
  const _AllTimePanel({required this.store});

  final DayStatsStore store;

  @override
  State<_AllTimePanel> createState() => _AllTimePanelState();
}

class _AllTimePanelState extends State<_AllTimePanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    // Walking every year is the one genuinely expensive read in here, so it
    // only happens once the user asks for it.
    final period = _open ? widget.store.allTimeTotals() : null;
    final streak = _open ? widget.store.streakEndingAt(DateTime.now()) : 0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Text('ALL TIME', style: AppText.eyebrow(8)),
                const Spacer(),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColor.boneMid,
                ),
              ],
            ),
          ),
          if (period != null) ...[
            const SizedBox(height: 10),
            StatRow('Days played', '${period.daysPlayed}'),
            StatRow('Current streak', '$streak day${streak == 1 ? '' : 's'}',
                tone: streak > 0 ? AppColor.amber : AppColor.slate),
            StatRow('Rounds dealt', chips(period.totals.rounds)),
            StatRow('Total wagered', chips(period.totals.wagered)),
            StatRow(
              'Net result',
              signedChips(period.totals.net),
              tone: period.totals.net > 0
                  ? AppColor.jade
                  : period.totals.net < 0
                      ? AppColor.clay
                      : AppColor.bone,
            ),
            if (period.bestDay != null)
              StatRow('Best day ever', _PeriodPanel._dayLabel(period.bestDay!),
                  tone: AppColor.jade),
            if (period.worstDay != null)
              StatRow('Worst day ever', _PeriodPanel._dayLabel(period.worstDay!),
                  tone: AppColor.clay),
          ],
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.eyebrow(7.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.display(22, weight: 700, height: 0.9)),
        ),
      ],
    );
  }
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
          Text('No days on record', style: AppText.display(26, weight: 700, height: 0.95)),
          const SizedBox(height: 8),
          Text(
            'Play a round and today gets its square. From then on the calendar '
            'keeps every day separately, so you can come back and see how a '
            'given day — or the same date last year — actually went.',
            style: AppText.ui(13, color: AppColor.boneMid, height: 1.45),
          ),
        ],
      ),
    );
  }
}

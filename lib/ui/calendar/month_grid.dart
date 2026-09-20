import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../model/day_stats.dart';
import 'day_tone.dart';

/// One month, Monday-first, as a seven-column grid of tinted day cells.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.year,
    required this.month,
    required this.days,
    required this.tone,
    required this.today,
    required this.onPick,
    super.key,
  });

  final int year;
  final int month;

  /// Day of month to what was played on it.
  final Map<int, DayStats> days;
  final DayTone tone;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final total = daysInMonth(year, month);

    // DateTime.weekday is 1..7 from Monday, which is already the order the
    // header is printed in, so the lead-in is just weekday - 1.
    final lead = DateTime(year, month, 1).weekday - 1;
    final cells = lead + total;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final d in kWeekdayShort)
              Expanded(
                child: Center(
                  child: Text(d, style: AppText.eyebrow(8.5, color: AppColor.slate)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rows; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: _cell(row * 7 + col - lead + 1, total),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(int dayOfMonth, int total) {
    if (dayOfMonth < 1 || dayOfMonth > total) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final date = DateTime(year, month, dayOfMonth);
    final stats = days[dayOfMonth];
    final isToday = date == today;
    final ahead = date.isAfter(today);

    return AspectRatio(
      aspectRatio: 1,
      child: Semantics(
        button: stats != null,
        label: stats == null
            ? '${isoDay(date)}, not played'
            : '${isoDay(date)}, ${stats.rounds} rounds, net ${stats.net}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ahead && stats == null ? null : () => onPick(date),
          child: Container(
            decoration: BoxDecoration(
              color: ahead && stats == null
                  ? Colors.transparent
                  : tone.fill(stats),
              borderRadius: BorderRadius.circular(7),
              border: isToday
                  ? Border.all(color: AppColor.amber, width: 1.6)
                  : stats == null
                      ? Border.all(color: AppColor.line.withValues(alpha: 0.6))
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayOfMonth',
                  style: AppText.mono(
                    11,
                    weight: stats == null ? FontWeight.w400 : FontWeight.w600,
                    color: ahead && stats == null
                        ? AppColor.slate.withValues(alpha: 0.45)
                        : tone.label(stats),
                  ),
                ),
                // A day with play but no swing would otherwise look empty.
                if (stats != null && stats.net == 0)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColor.bone,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The jade-to-clay key, so the grid's colours mean something on their own.
class ToneLegend extends StatelessWidget {
  const ToneLegend({required this.peak, super.key});

  final int peak;

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, double alpha) => Container(
          width: 13,
          height: 13,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(3.5),
          ),
        );

    return Row(
      children: [
        Text('DOWN', style: AppText.eyebrow(7, color: AppColor.slate)),
        const SizedBox(width: 6),
        swatch(AppColor.clay, 0.80),
        swatch(AppColor.clay, 0.45),
        swatch(AppColor.clay, 0.22),
        swatch(AppColor.railHi, 0.55),
        swatch(AppColor.jade, 0.22),
        swatch(AppColor.jade, 0.45),
        swatch(AppColor.jade, 0.80),
        const SizedBox(width: 6),
        Text('UP', style: AppText.eyebrow(7, color: AppColor.slate)),
        const Spacer(),
        Text(
          peak > 0 ? 'peak ±$peak' : '',
          style: AppText.mono(9, color: AppColor.slate),
        ),
      ],
    );
  }
}

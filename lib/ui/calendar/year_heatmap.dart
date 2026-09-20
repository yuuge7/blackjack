import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/day_stats.dart';
import 'day_tone.dart';

/// A whole year at once: 53 week-columns of seven days, scrolled sideways.
///
/// Small enough that a year fits on a phone without pinching, and dense enough
/// that the shape of a year — the streaks, the months off — is visible in one
/// look. Tapping a square opens the same day sheet the month grid does.
class YearHeatmap extends StatelessWidget {
  const YearHeatmap({
    required this.year,
    required this.days,
    required this.tone,
    required this.today,
    required this.onPick,
    super.key,
  });

  final int year;
  final Map<DateTime, DayStats> days;
  final DayTone tone;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  static const double _cell = 13;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    // Columns start on the Monday on or before 1 January, so every column is a
    // full week and the rows line up with the weekday labels.
    final jan1 = DateTime(year, 1, 1);
    final start = jan1.subtract(Duration(days: jan1.weekday - 1));
    final dec31 = DateTime(year, 12, 31);
    final weeks = (dec31.difference(start).inDays / 7).ceil() + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthRuler(year: year, start: start, weeks: weeks),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < weeks; w++)
                    Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _gap),
                              child: _square(start.add(Duration(days: w * 7 + d))),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _square(DateTime date) {
    // Columns overhang both ends of the year; those days belong to a
    // neighbouring year's map and are left blank here.
    if (date.year != year) {
      return const SizedBox(width: _cell, height: _cell);
    }

    final stats = days[date];
    final ahead = date.isAfter(today);
    final isToday = date == today;

    return Semantics(
      button: stats != null,
      label: stats == null
          ? '${isoDay(date)}, not played'
          : '${isoDay(date)}, net ${stats.net}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: stats == null && ahead ? null : () => onPick(date),
        child: Container(
          width: _cell,
          height: _cell,
          decoration: BoxDecoration(
            color: ahead && stats == null ? Colors.transparent : tone.fill(stats),
            borderRadius: BorderRadius.circular(3),
            border: isToday
                ? Border.all(color: AppColor.amber, width: 1.4)
                : ahead && stats == null
                    ? Border.all(color: AppColor.line.withValues(alpha: 0.5))
                    : null,
          ),
        ),
      ),
    );
  }
}

/// Month initials above the columns they start in.
class _MonthRuler extends StatelessWidget {
  const _MonthRuler({required this.year, required this.start, required this.weeks});

  final int year;
  final DateTime start;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    const step = YearHeatmap._cell + YearHeatmap._gap;
    final marks = <int, String>{};
    for (var m = 1; m <= 12; m++) {
      final first = DateTime(year, m, 1);
      final week = first.difference(start).inDays ~/ 7;
      if (week >= 0 && week < weeks) marks[week] = kMonthShort[m - 1];
    }

    return SizedBox(
      height: 12,
      width: weeks * step,
      child: Stack(
        children: [
          for (final e in marks.entries)
            Positioned(
              left: e.key * step,
              top: 0,
              child: Text(e.value, style: AppText.eyebrow(7.5, color: AppColor.slate)),
            ),
        ],
      ),
    );
  }
}

/// Twelve bars, one per month, so a year's shape is readable as numbers and
/// not only as colour.
class MonthBars extends StatelessWidget {
  const MonthBars({
    required this.year,
    required this.byMonth,
    required this.onPick,
    super.key,
  });

  final int year;

  /// Month number to that month's totals. Months not played are absent.
  final Map<int, PeriodStats> byMonth;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final p in byMonth.values) {
      final swing = p.totals.net.abs();
      if (swing > peak) peak = swing;
    }

    return Column(
      children: [
        for (var m = 1; m <= 12; m++) ...[
          _Bar(
            label: kMonthShort[m - 1],
            period: byMonth[m],
            peak: peak,
            onTap: byMonth[m] == null ? null : () => onPick(m),
          ),
          if (m < 12) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.period, required this.peak, this.onTap});

  final String label;
  final PeriodStats? period;
  final int peak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = period;
    final net = p?.totals.net ?? 0;
    final tone = net > 0
        ? AppColor.jade
        : net < 0
            ? AppColor.clay
            : AppColor.slate;
    final extent = (net.abs() / peak).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: AppText.eyebrow(8, color: p == null ? AppColor.slate : AppColor.boneMid),
            ),
          ),
          // A centre line with the bar growing left for a losing month and
          // right for a winning one.
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final half = c.maxWidth / 2;
                return SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      Positioned(
                        left: half - 0.5,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: AppColor.line),
                      ),
                      if (p != null && net != 0)
                        Positioned(
                          left: net > 0 ? half : half - half * extent,
                          top: 3,
                          bottom: 3,
                          width: (half * extent).clamp(2.0, half),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tone,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 74,
            child: Text(
              p == null ? '—' : signedChips(net),
              textAlign: TextAlign.right,
              style: AppText.mono(
                10.5,
                weight: FontWeight.w600,
                color: p == null ? AppColor.slate : tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

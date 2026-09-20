import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../model/day_stats.dart';

/// How a day is coloured across the whole calendar: jade for a day up, clay
/// for a day down, and bone for a day that came out level.
///
/// The intensity is scaled against the biggest swing on screen rather than an
/// absolute number of chips, because a player betting 5 a hand and one betting
/// 5,000 both want the same thing out of the grid — which days were their
/// good ones. The scale is square-rooted so a single huge day does not flatten
/// every other day into the background.
class DayTone {
  const DayTone(this.peak);

  /// The largest absolute net on screen. Never zero, so the maths is safe.
  final int peak;

  static DayTone forDays(Iterable<DayStats> days) {
    var peak = 0;
    for (final d in days) {
      final swing = d.net.abs();
      if (swing > peak) peak = swing;
    }
    return DayTone(peak == 0 ? 1 : peak);
  }

  /// 0 for a level day, 1 for the biggest day on screen. Square-rooted, so the
  /// middle of the range stays legible next to one outsized day.
  double weight(DayStats day) {
    final t = (day.net.abs() / peak).clamp(0.0, 1.0);
    return math.sqrt(t);
  }

  Color ink(DayStats day) {
    if (day.net > 0) return AppColor.jade;
    if (day.net < 0) return AppColor.clay;
    return AppColor.boneMid;
  }

  /// The cell fill. Played days always keep a floor of visibility, so a day
  /// that happened to break even still reads as played.
  Color fill(DayStats? day) {
    if (day == null || day.isEmpty) return AppColor.railHi.withValues(alpha: 0.55);
    final w = weight(day);
    return ink(day).withValues(alpha: 0.18 + w * 0.62);
  }

  Color label(DayStats? day) {
    if (day == null || day.isEmpty) return AppColor.slate;
    return weight(day) > 0.55 ? AppColor.ink : AppColor.bone;
  }
}

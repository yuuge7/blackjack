import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/day_stats.dart';
import '../model/hand.dart';

/// The calendar's ledger: one [DayStats] per day played, forever.
///
/// Days are stored a year at a time under `days.<year>`, and a year is only
/// parsed when something asks for it. A player with ten years of history pays
/// for the month they are looking at, not the decade behind it, and a day's
/// worth of play only ever rewrites one year's blob.
class DayStatsStore extends ChangeNotifier {
  DayStatsStore(this._prefs) {
    final index = _prefs.getStringList(_indexKey) ?? const [];
    for (final y in index) {
      final n = int.tryParse(y);
      if (n != null) _years.add(n);
    }
  }

  static const String _indexKey = 'days.index';

  static String _yearKey(int year) => 'days.$year';

  final SharedPreferences _prefs;

  final Set<int> _years = <int>{};
  final Map<int, Map<int, DayStats>> _cache = <int, Map<int, DayStats>>{};
  final Set<int> _dirty = <int>{};

  Timer? _saveTimer;

  /// The day this run of the app has already been counted against, so a long
  /// evening is one session and not one per round.
  DateTime? _countedSession;

  /// Overridable so tests do not have to wait for midnight.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  /// Every year with something in it, oldest first.
  List<int> get years => _years.toList()..sort();

  bool get isEmpty => _years.isEmpty;

  // --- reading -------------------------------------------------------------

  Map<int, DayStats> _yearMap(int year) {
    final cached = _cache[year];
    if (cached != null) return cached;

    final map = <int, DayStats>{};
    final raw = _prefs.getString(_yearKey(year));
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            final key = int.tryParse(k as String);
            if (key != null && v is List) map[key] = DayStats.fromList(v);
          });
        }
      } catch (_) {
        // A corrupt year loses that year, not the whole calendar.
      }
    }
    _cache[year] = map;
    return map;
  }

  /// What was played on one date, or null if nothing was.
  DayStats? day(DateTime date) {
    if (!_years.contains(date.year)) return null;
    final d = _yearMap(date.year)[dayKey(date.month, date.day)];
    return d == null || d.isEmpty ? null : d;
  }

  /// Every played day in one month, keyed by day of month.
  Map<int, DayStats> month(int year, int month) {
    if (!_years.contains(year)) return const {};
    final out = <int, DayStats>{};
    _yearMap(year).forEach((key, value) {
      if (monthOfKey(key) == month && value.isNotEmpty) out[dayOfKey(key)] = value;
    });
    return out;
  }

  /// Every played day in one year, keyed by date.
  Map<DateTime, DayStats> year(int year) {
    if (!_years.contains(year)) return const {};
    final out = <DateTime, DayStats>{};
    _yearMap(year).forEach((key, value) {
      if (value.isNotEmpty) {
        out[DateTime(year, monthOfKey(key), dayOfKey(key))] = value;
      }
    });
    return out;
  }

  PeriodStats monthTotals(int y, int m) => PeriodStats.of({
        for (final e in month(y, m).entries) DateTime(y, m, e.key): e.value,
      });

  PeriodStats yearTotals(int y) => PeriodStats.of(year(y));

  /// Everything ever played. Walks each year, so callers should hold the
  /// result rather than rebuilding it inside a widget build.
  PeriodStats allTimeTotals() {
    final all = <DateTime, DayStats>{};
    for (final y in years) {
      all.addAll(year(y));
    }
    return PeriodStats.of(all);
  }

  /// The same calendar date in earlier years, newest first. This is the
  /// "what was I doing a year ago today" view.
  List<MapEntry<int, DayStats>> onThisDay(int month, int day, {int? excludeYear}) {
    final out = <MapEntry<int, DayStats>>[];
    for (final y in years) {
      if (y == excludeYear) continue;
      final d = _yearMap(y)[dayKey(month, day)];
      if (d != null && d.isNotEmpty) out.add(MapEntry(y, d));
    }
    return out.reversed.toList();
  }

  /// How many days in a row have been played up to and including [from].
  /// Counting stops at the first gap, so today being unplayed ends the run.
  int streakEndingAt(DateTime from) {
    var count = 0;
    var cursor = dayOf(from);
    while (day(cursor) != null) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
      // A decade of unbroken play is already implausible; this only guards
      // against a corrupt clock walking backwards forever.
      if (count > 4000) break;
    }
    return count;
  }

  // --- recording -----------------------------------------------------------

  DayStats _today() {
    final today = dayOf(now());
    final map = _yearMap(today.year);
    final entry = map.putIfAbsent(dayKey(today.month, today.day), DayStats.new);
    if (_years.add(today.year)) _writeIndex();
    if (_countedSession != today) {
      _countedSession = today;
      entry.sessions++;
    }
    _dirty.add(today.year);
    return entry;
  }

  void recordHand(Hand h) {
    _today().recordHand(h);
    _schedule();
  }

  void recordRound({required int net, required int wagered}) {
    _today().recordRound(roundNet: net, roundWagered: wagered);
    _schedule();
    notifyListeners();
  }

  void recordDecision({required bool correct}) {
    _today().recordDecision(wasCorrect: correct);
    _schedule();
  }

  void recordMarker(int amount) {
    _today().recordMarker(amount);
    _schedule();
    notifyListeners();
  }

  void recordInsurance({required bool won}) {
    _today().recordInsurance(won: won);
    _schedule();
  }

  // --- transfer ------------------------------------------------------------

  /// One year as the wire format used by save files: `{"MMDD": [counters]}`.
  Map<String, List<int>> exportYear(int y) {
    final out = <String, List<int>>{};
    _yearMap(y).forEach((key, value) {
      if (value.isNotEmpty) out[key.toString().padLeft(4, '0')] = value.toList();
    });
    return out;
  }

  /// Merges one year out of a save file. [replace] drops whatever was there
  /// first; otherwise the imported days are folded into the existing ones, so
  /// two devices can be reconciled without either losing a day.
  void importYear(int y, Map<String, dynamic> days, {required bool replace}) {
    final map = _yearMap(y);
    if (replace) map.clear();

    days.forEach((k, v) {
      final key = int.tryParse(k);
      if (key == null || v is! List) return;
      final incoming = DayStats.fromList(v);
      if (incoming.isEmpty) return;
      final existing = map[key];
      if (existing == null || replace) {
        map[key] = incoming;
      } else {
        final merged = existing.copy()..absorb(incoming);
        // Two records of the same day are two devices, not two sessions on
        // one, so the session count is the larger of the two rather than
        // the sum.
        merged.sessions =
            existing.sessions > incoming.sessions ? existing.sessions : incoming.sessions;
        merged.streak = incoming.streak;
        map[key] = merged;
      }
    });

    if (map.isNotEmpty) _years.add(y);
    _dirty.add(y);
    _writeIndex();
    _schedule();
  }

  /// Wipes every year. Used by "clear all stats" and by a replacing import.
  void clear() {
    for (final y in _years) {
      _prefs.remove(_yearKey(y));
    }
    _years.clear();
    _cache.clear();
    _dirty.clear();
    _countedSession = null;
    _prefs.remove(_indexKey);
    notifyListeners();
  }

  /// Called once an import has finished so the calendar redraws.
  void importFinished() {
    flush();
    notifyListeners();
  }

  // --- persistence ---------------------------------------------------------

  void _writeIndex() {
    _prefs.setStringList(_indexKey, _years.map((y) => y.toString()).toList()..sort());
  }

  void _schedule() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), flush);
  }

  void flush() {
    _saveTimer?.cancel();
    if (_dirty.isEmpty) return;
    for (final y in _dirty) {
      final map = _cache[y];
      if (map == null) continue;
      final payload = <String, List<int>>{};
      map.forEach((key, value) {
        if (value.isNotEmpty) payload[key.toString().padLeft(4, '0')] = value.toList();
      });
      if (payload.isEmpty) {
        _prefs.remove(_yearKey(y));
      } else {
        _prefs.setString(_yearKey(y), jsonEncode(payload));
      }
    }
    _dirty.clear();
  }

  @override
  void dispose() {
    flush();
    _saveTimer?.cancel();
    super.dispose();
  }
}

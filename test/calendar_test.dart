import 'package:blackjack/model/day_stats.dart';
import 'package:blackjack/state/day_stats_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  /// A store whose idea of "today" can be moved around.
  Future<(DayStatsStore, void Function(DateTime))> storeOnDate(DateTime start) async {
    final prefs = await freshPrefs();
    final store = DayStatsStore(prefs);
    var clock = start;
    store.now = () => clock;
    return (store, (DateTime d) => clock = d);
  }

  group('DayStats', () {
    test('survives a list round trip, trimmed tail and all', () {
      final d = DayStats()
        ..recordRound(roundNet: 50, roundWagered: 25)
        ..recordRound(roundNet: -25, roundWagered: 25)
        ..recordDecision(wasCorrect: true)
        ..recordDecision(wasCorrect: false);

      final back = DayStats.fromList(d.toList());

      expect(back.rounds, 2);
      expect(back.net, 25);
      expect(back.wagered, 50);
      expect(back.biggestWin, 50);
      expect(back.biggestLoss, -25);
      expect(back.decisions, 2);
      expect(back.correct, 1);
      expect(back.accuracy, 0.5);
    });

    test('a short list from an older build reads as zeros, not a crash', () {
      final back = DayStats.fromList(const [3, 4, 2]);
      expect(back.rounds, 3);
      expect(back.hands, 4);
      expect(back.wins, 2);
      expect(back.markers, 0);
      expect(back.sessions, 0);
    });

    test('a longer list from a newer build is tolerated', () {
      final forward = DayStats().toList() + List.filled(8, 99);
      expect(() => DayStats.fromList(forward), returnsNormally);
    });

    test('absorb sums counters and keeps the extremes', () {
      final a = DayStats()
        ..recordRound(roundNet: 100, roundWagered: 50)
        ..recordRound(roundNet: 80, roundWagered: 50);
      final b = DayStats()..recordRound(roundNet: -300, roundWagered: 200);

      final total = a.copy()..absorb(b);

      expect(total.rounds, 3);
      expect(total.net, -120);
      expect(total.wagered, 300);
      expect(total.biggestWin, 100);
      expect(total.biggestLoss, -300);
      expect(total.bestWinStreak, 2);
      // A streak cannot run across two separate days.
      expect(total.streak, 0);
    });
  });

  group('DayStatsStore', () {
    test('records against today and persists across a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DayStatsStore(prefs);
      final today = DateTime(2026, 9, 20, 21, 30);
      store.now = () => today;

      store.recordRound(net: 75, wagered: 25);
      store.recordRound(net: -25, wagered: 25);
      store.flush();

      final reloaded = DayStatsStore(prefs);
      final day = reloaded.day(DateTime(2026, 9, 20));

      expect(day, isNotNull);
      expect(day!.rounds, 2);
      expect(day.net, 50);
      expect(reloaded.years, [2026]);
    });

    test('a day only counts as one session however many rounds it holds', () async {
      final (store, setDay) = await storeOnDate(DateTime(2026, 3, 4));
      for (var i = 0; i < 20; i++) {
        store.recordRound(net: 5, wagered: 10);
      }
      expect(store.day(DateTime(2026, 3, 4))!.sessions, 1);

      setDay(DateTime(2026, 3, 5));
      store.recordRound(net: 5, wagered: 10);
      expect(store.day(DateTime(2026, 3, 5))!.sessions, 1);
      expect(store.day(DateTime(2026, 3, 4))!.sessions, 1);
    });

    test('month and year totals only count days that were played', () async {
      final (store, setDay) = await storeOnDate(DateTime(2026, 5, 2));
      store.recordRound(net: 100, wagered: 50);
      setDay(DateTime(2026, 5, 9));
      store.recordRound(net: -40, wagered: 50);
      setDay(DateTime(2026, 7, 1));
      store.recordRound(net: 10, wagered: 10);

      final may = store.monthTotals(2026, 5);
      expect(may.daysPlayed, 2);
      expect(may.totals.net, 60);
      expect(may.bestDay, DateTime(2026, 5, 2));
      expect(may.worstDay, DateTime(2026, 5, 9));

      final year = store.yearTotals(2026);
      expect(year.daysPlayed, 3);
      expect(year.totals.net, 70);

      expect(store.monthTotals(2026, 6).isEmpty, isTrue);
    });

    test('onThisDay finds the same date in earlier years', () async {
      final (store, setDay) = await storeOnDate(DateTime(2024, 2, 29));
      store.recordRound(net: 60, wagered: 20);
      setDay(DateTime(2025, 2, 28));
      store.recordRound(net: -10, wagered: 20);
      setDay(DateTime(2026, 2, 28));
      store.recordRound(net: 20, wagered: 20);

      final leapDay = store.onThisDay(2, 29, excludeYear: 2026);
      expect(leapDay.map((e) => e.key), [2024]);

      final feb28 = store.onThisDay(2, 28, excludeYear: 2026);
      expect(feb28.map((e) => e.key), [2025]);
      expect(feb28.single.value.net, -10);
    });

    test('a consecutive run of days counts as a streak and a gap ends it', () async {
      final (store, setDay) = await storeOnDate(DateTime(2026, 9, 15));
      for (final d in [15, 16, 17, 19, 20]) {
        setDay(DateTime(2026, 9, d));
        store.recordRound(net: 1, wagered: 1);
      }

      expect(store.streakEndingAt(DateTime(2026, 9, 20)), 2);
      expect(store.streakEndingAt(DateTime(2026, 9, 17)), 3);
      // The 18th was never played, so the run there is zero.
      expect(store.streakEndingAt(DateTime(2026, 9, 18)), 0);
    });

    test('importing a year merges by default and replaces on request', () async {
      final (store, _) = await storeOnDate(DateTime(2026, 1, 5));
      store.recordRound(net: 100, wagered: 50);

      final incoming = DayStats()..recordRound(roundNet: 40, roundWagered: 20);
      store.importYear(2026, {'0105': incoming.toList()}, replace: false);

      final merged = store.day(DateTime(2026, 1, 5))!;
      expect(merged.rounds, 2);
      expect(merged.net, 140);

      store.importYear(2026, {'0105': incoming.toList()}, replace: true);
      final replaced = store.day(DateTime(2026, 1, 5))!;
      expect(replaced.rounds, 1);
      expect(replaced.net, 40);
    });

    test('clearing drops every year', () async {
      final (store, setDay) = await storeOnDate(DateTime(2025, 6, 1));
      store.recordRound(net: 10, wagered: 10);
      setDay(DateTime(2026, 6, 1));
      store.recordRound(net: 10, wagered: 10);
      store.flush();

      store.clear();

      expect(store.isEmpty, isTrue);
      expect(store.years, isEmpty);
      expect(store.day(DateTime(2026, 6, 1)), isNull);
    });
  });

  group('StatsStore fan-out', () {
    test('a round reaches the session, the lifetime record and the day', () async {
      final prefs = await freshPrefs();
      final days = DayStatsStore(prefs);
      days.now = () => DateTime(2026, 9, 20);
      final stats = StatsStore(prefs, days: days);

      stats.recordRound(net: 50, wagered: 25, bankroll: 550);
      stats.recordDecision('16 v 10', false, 'Stand');

      expect(stats.session.rounds, 1);
      expect(stats.lifetime.rounds, 1);

      final day = days.day(DateTime(2026, 9, 20))!;
      expect(day.rounds, 1);
      expect(day.net, 50);
      expect(day.decisions, 1);
      expect(day.correct, 0);
    });

    test('clearing the lifetime record leaves the calendar alone by default',
        () async {
      final prefs = await freshPrefs();
      final days = DayStatsStore(prefs);
      days.now = () => DateTime(2026, 9, 20);
      final stats = StatsStore(prefs, days: days);
      stats.recordRound(net: 50, wagered: 25, bankroll: 550);

      stats.resetLifetime();
      expect(stats.lifetime.rounds, 0);
      expect(days.day(DateTime(2026, 9, 20)), isNotNull);

      stats.resetLifetime(includeCalendar: true);
      expect(days.day(DateTime(2026, 9, 20)), isNull);
    });
  });

  group('calendar date helpers', () {
    test('daysInMonth handles leap years', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2025, 2), 28);
      expect(daysInMonth(2026, 9), 30);
      expect(daysInMonth(2026, 12), 31);
    });

    test('day keys round trip', () {
      final key = dayKey(12, 31);
      expect(monthOfKey(key), 12);
      expect(dayOfKey(key), 31);
      expect(key.toString().padLeft(4, '0'), '1231');

      final early = dayKey(1, 1);
      expect(early.toString().padLeft(4, '0'), '0101');
      expect(monthOfKey(early), 1);
      expect(dayOfKey(early), 1);
    });

    test('isoDay pads', () {
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}

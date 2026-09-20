import 'package:blackjack/model/profile.dart';
import 'package:blackjack/model/stats.dart';
import 'package:blackjack/state/day_stats_store.dart';
import 'package:blackjack/state/profile_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

StatsData record({
  int rounds = 0,
  int correct = 0,
  int decisions = 0,
  int net = 0,
  int blackjacks = 0,
  int markers = 0,
  int bestWinStreak = 0,
  int dealerBusts = 0,
}) {
  return StatsData()
    ..rounds = rounds
    ..correct = correct
    ..decisions = decisions
    ..net = net
    ..blackjacks = blackjacks
    ..markers = markers
    ..bestWinStreak = bestWinStreak
    ..dealerBusts = dealerBusts;
}

Profile build({
  StatsData? lifetime,
  int peakBankroll = 0,
  int daysPlayed = 0,
  int dayStreak = 0,
  String name = 'Player',
}) =>
    Profile.of(
      name: name,
      lifetime: lifetime ?? StatsData(),
      peakBankroll: peakBankroll,
      daysPlayed: daysPlayed,
      dayStreak: dayStreak,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('levels', () {
    test('the curve and its inverse agree at every boundary', () {
      for (var level = 1; level <= 80; level++) {
        final at = xpForLevel(level);
        expect(levelForXp(at), level, reason: 'exactly at level $level');
        if (level > 1) {
          expect(levelForXp(at - 1), level - 1, reason: 'one short of level $level');
        }
        expect(levelForXp(at + 1), level, reason: 'just past level $level');
      }
    });

    test('level one starts at zero and nothing goes below it', () {
      expect(xpForLevel(1), 0);
      expect(xpForLevel(0), 0);
      expect(levelForXp(0), 1);
      expect(levelForXp(-500), 1);
    });

    test('each level costs more than the one before it', () {
      var previous = 0;
      for (var level = 2; level <= 60; level++) {
        final span = xpForLevel(level) - xpForLevel(level - 1);
        expect(span, greaterThan(previous));
        previous = span;
      }
    });
  });

  group('ranks', () {
    test('every level maps to a rank, and the top one sticks', () {
      expect(rankForLevel(1).name, 'Walk-in');
      expect(rankForLevel(2).name, 'Walk-in');
      expect(rankForLevel(3).name, 'Tourist');
      expect(rankForLevel(59).name, 'Table Captain');
      expect(rankForLevel(60).name, 'Floor Legend');
      expect(rankForLevel(400).name, 'Floor Legend');
    });

    test('the next rank runs out at the top', () {
      expect(nextRankAfter(1)!.name, 'Tourist');
      expect(nextRankAfter(59)!.name, 'Floor Legend');
      expect(nextRankAfter(60), isNull);
    });

    test('rank thresholds climb', () {
      for (var i = 1; i < kRanks.length; i++) {
        expect(kRanks[i].level, greaterThan(kRanks[i - 1].level));
      }
    });
  });

  group('experience', () {
    test('a fresh profile is level one with nothing earned', () {
      final p = build();
      expect(p.xp, 0);
      expect(p.level, 1);
      expect(p.isNew, isTrue);
      expect(p.earned, isEmpty);
    });

    test('each source contributes what it says it does', () {
      final p = build(
        lifetime: record(rounds: 10, correct: 25, decisions: 30, net: 500),
        daysPlayed: 3,
        peakBankroll: 600,
      );

      expect(p.breakdown.rounds, 10 * Xp.perRound);
      expect(p.breakdown.accuracy, 25 * Xp.perCorrectDecision);
      expect(p.breakdown.days, 3 * Xp.perDayPlayed);
      expect(p.breakdown.winnings, 500 ~/ Xp.chipsPerPoint);
      // 600 clears Nickel (seats at 0) and Quarter (seats at 500).
      expect(p.breakdown.tables, 2 * Xp.perTableReached);
      expect(p.xp, p.breakdown.total);
    });

    test('losing money earns nothing rather than taking XP away', () {
      final down = build(lifetime: record(rounds: 10, net: -5000));
      final level = build(lifetime: record(rounds: 10));
      expect(down.breakdown.winnings, 0);
      expect(down.xp, level.xp);
    });

    test('skill outruns luck', () {
      // One player grinds the chart; the other gets lucky over a quarter of
      // the rounds. The careful one should still be further along.
      final careful = build(
        lifetime: record(rounds: 400, decisions: 1000, correct: 980, net: 0),
        daysPlayed: 20,
      );
      final lucky = build(
        lifetime: record(rounds: 100, decisions: 250, correct: 150, net: 20000),
        daysPlayed: 5,
      );

      expect(careful.xp, greaterThan(lucky.xp));
      expect(careful.level, greaterThan(lucky.level));
    });

    test('tables reached counts the preset ladder, not your own table', () {
      // Never played, so no table has been sat at yet.
      expect(build(peakBankroll: 0).tablesReached, 0);
      expect(build(peakBankroll: 1).tablesReached, 1);
      expect(build(peakBankroll: 500).tablesReached, 2);
      expect(build(peakBankroll: 2000).tablesReached, 3);
      expect(build(peakBankroll: 10000).tablesReached, 4);
      expect(build(peakBankroll: 50000).tablesReached, 5);
      expect(build(peakBankroll: 5000000).tablesReached, 5);
    });

    test('progress through a level stays inside the bar', () {
      for (final xp in [0, 1, 499, 500, 501, 13500, 99999]) {
        final p = build(lifetime: record(rounds: 0, correct: xp ~/ 4));
        expect(p.levelProgress, inInclusiveRange(0.0, 1.0));
        expect(p.xpIntoLevel, greaterThanOrEqualTo(0));
        expect(p.xpToNextLevel, greaterThan(0));
      }
    });
  });

  group('achievements', () {
    Achievement find(Profile p, String id) => p.badges.firstWhere((b) => b.id == id);

    test('a fresh profile has earned none of them', () {
      expect(build().badges.where((b) => b.earned), isEmpty);
    });

    test('count badges report progress and then latch', () {
      final some = build(lifetime: record(rounds: 40));
      expect(find(some, 'hundred').earned, isFalse);
      expect(find(some, 'hundred').progressLabel, '40 / 100');
      expect(find(some, 'first').earned, isTrue);

      final more = build(lifetime: record(rounds: 100));
      expect(find(more, 'hundred').earned, isTrue);
      expect(find(more, 'hundred').progressLabel, 'Earned');
    });

    test('accuracy badges need the volume before the percentage counts', () {
      // Perfect, but over far too few decisions to mean anything.
      final thin = build(lifetime: record(decisions: 20, correct: 20));
      expect(find(thin, 'sharp').earned, isFalse);
      expect(find(thin, 'sharp').progressLabel, contains('decisions'));

      // Enough decisions, not accurate enough.
      final sloppy = build(lifetime: record(decisions: 600, correct: 500));
      expect(find(sloppy, 'sharp').earned, isFalse);
      expect(find(sloppy, 'sharp').progressLabel, contains('%'));

      final sharp = build(lifetime: record(decisions: 600, correct: 580));
      expect(find(sharp, 'sharp').earned, isTrue);
    });

    test('the marker badge is lost outright, not merely stalled', () {
      final clean = build(lifetime: record(rounds: 500));
      expect(find(clean, 'unmarked').earned, isTrue);

      final marked = build(lifetime: record(rounds: 5000, markers: 1));
      expect(find(marked, 'unmarked').earned, isFalse);
      expect(find(marked, 'unmarked').progress, 0);
      expect(find(marked, 'unmarked').progressLabel, 'Marker taken');
    });

    test('streak badges follow the calendar, not the win streak', () {
      final week = build(dayStreak: 7);
      expect(find(week, 'week').earned, isTrue);
      expect(find(week, 'month').earned, isFalse);

      final month = build(dayStreak: 30);
      expect(find(month, 'month').earned, isTrue);
    });

    test('nearest lists the unearned badges closest to falling', () {
      final p = build(lifetime: record(rounds: 95, blackjacks: 1));
      final near = p.nearest();
      expect(near, isNotEmpty);
      expect(near.every((b) => !b.earned), isTrue);
      for (var i = 1; i < near.length; i++) {
        expect(near[i - 1].progress, greaterThanOrEqualTo(near[i].progress));
      }
    });

    test('every badge has a distinct id', () {
      final ids = build().badges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('ProfileStore', () {
    Future<ProfileStore> store() async {
      SharedPreferences.setMockInitialValues({});
      return ProfileStore(await SharedPreferences.getInstance());
    }

    test('a name is trimmed, capped and remembered', () async {
      final s = await store();
      expect(s.hasName, isFalse);
      expect(s.displayName, 'Player');

      s.setName('   Ionel   ');
      expect(s.name, 'Ionel');
      expect(s.hasName, isTrue);

      s.setName('x' * 40);
      expect(s.name.length, ProfileStore.nameLimit);
    });

    test('the bankroll peak only ever climbs', () async {
      final s = await store();
      s.noteBankroll(1000);
      expect(s.peakBankroll, 1000);

      s.noteBankroll(400);
      expect(s.peakBankroll, 1000);

      s.noteBankroll(2500);
      expect(s.peakBankroll, 2500);
    });

    test('it survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProfileStore(prefs)
        ..setName('Ionel')
        ..noteBankroll(12000);

      final reloaded = ProfileStore(prefs);
      expect(reloaded.name, 'Ionel');
      expect(reloaded.peakBankroll, 12000);
    });

    test('an import replaces the peak rather than taking the higher one',
        () async {
      final s = await store();
      s.noteBankroll(90000);
      s.applyImported({'name': 'Other', 'peak': 500});
      expect(s.name, 'Other');
      expect(s.peakBankroll, 500);
    });
  });

  test('a settled round lifts the peak through StatsStore', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final days = DayStatsStore(prefs)..now = () => DateTime(2026, 9, 20);
    final profile = ProfileStore(prefs);
    final stats = StatsStore(prefs, days: days, profile: profile);

    stats.recordRound(net: 200, wagered: 100, bankroll: 4200);
    expect(profile.peakBankroll, 4200);

    stats.recordRound(net: -3000, wagered: 3000, bankroll: 1200);
    expect(profile.peakBankroll, 4200);

    stats.flush();
    days.dispose();
  });
}

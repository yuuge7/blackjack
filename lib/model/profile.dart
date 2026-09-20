import 'dart:math' as math;

import 'stats.dart';
import 'table_tier.dart';

/// Where experience comes from, and how much each thing is worth.
///
/// Weighted to skill on purpose. Playing a round at all earns something,
/// playing it the way the chart says earns more, and money earns least of the
/// three — a lucky shoe should not out-level a careful one. Winnings and
/// tables reached are in there because a bankroll climbing is still progress,
/// just not the kind the app is really measuring.
class Xp {
  const Xp._();

  static const int perRound = 12;
  static const int perCorrectDecision = 4;
  static const int perDayPlayed = 20;
  static const int perTableReached = 250;

  /// Chips of lifetime profit per point. Deliberately coarse.
  static const int chipsPerPoint = 50;
}

/// The same total, split by where it came from, so the profile can show its
/// working instead of one unexplained number.
class XpBreakdown {
  const XpBreakdown({
    required this.rounds,
    required this.accuracy,
    required this.winnings,
    required this.days,
    required this.tables,
  });

  final int rounds;
  final int accuracy;
  final int winnings;
  final int days;
  final int tables;

  int get total => rounds + accuracy + winnings + days + tables;

  List<({String label, String note, int value})> get parts => [
        (label: 'Rounds dealt', note: '${Xp.perRound} each', value: rounds),
        (label: 'Chart-perfect plays', note: '${Xp.perCorrectDecision} each', value: accuracy),
        (label: 'Days at the table', note: '${Xp.perDayPlayed} each', value: days),
        (label: 'Tables reached', note: '${Xp.perTableReached} each', value: tables),
        (label: 'Winnings', note: '1 per ${Xp.chipsPerPoint} chips up', value: winnings),
      ];
}

/// A named band of levels. Ranks are sparse — most levels just move the bar,
/// and a handful change what you are called.
class Rank {
  const Rank(this.level, this.name, this.note);

  final int level;
  final String name;
  final String note;
}

/// The ladder of names. `level` is the level at which the rank is earned.
const List<Rank> kRanks = [
  Rank(1, 'Walk-in', 'You found the table.'),
  Rank(3, 'Tourist', 'Enough hands in to know where the buttons are.'),
  Rank(6, 'Grinder', 'Turning up is the whole discipline.'),
  Rank(10, 'Regular', 'The floor knows your face.'),
  Rank(15, 'Pit Regular', 'You stopped guessing somewhere around here.'),
  Rank(21, 'Sharp', 'The chart is in your hands, not on the screen.'),
  Rank(28, 'Advantage Player', 'You know exactly what the table costs you.'),
  Rank(36, 'Counter', 'Deep shoes stopped being decoration.'),
  Rank(45, 'Table Captain', 'Nobody at this table plays it better.'),
  Rank(60, 'Floor Legend', 'There is nothing left to teach you here.'),
];

/// Cumulative experience needed to *reach* [level]. Quadratic, so early levels
/// come quickly and later ones ask for real volume.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  final n = level - 1;
  return 125 * n * n + 375 * n;
}

/// The inverse: the level a given total of experience has bought.
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  // 125n² + 375n = xp, solved for n, floored.
  final n = (-375 + math.sqrt(140625 + 500 * xp)) / 250;
  return n.floor() + 1;
}

Rank rankForLevel(int level) {
  var found = kRanks.first;
  for (final r in kRanks) {
    if (level >= r.level) found = r;
  }
  return found;
}

Rank? nextRankAfter(int level) {
  for (final r in kRanks) {
    if (r.level > level) return r;
  }
  return null;
}

/// One thing worth having done, and how close you are to it.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.note,
    required this.progress,
    required this.progressLabel,
  });

  final String id;
  final String name;
  final String note;

  /// 0 to 1. Exactly 1 means earned.
  final double progress;

  /// Where you are, in the badge's own units.
  final String progressLabel;

  bool get earned => progress >= 1;
}

Achievement _count({
  required String id,
  required String name,
  required String note,
  required int have,
  required int need,
}) =>
    Achievement(
      id: id,
      name: name,
      note: note,
      progress: need <= 0 ? 1 : (have / need).clamp(0.0, 1.0),
      progressLabel: have >= need ? 'Earned' : '$have / $need',
    );

/// Everything the profile screen shows, computed rather than stored.
///
/// Deriving it from the records that already exist means there is no second
/// ledger to keep in step, no migration when the numbers change, and a save
/// imported from another device arrives with the right level already on it.
class Profile {
  const Profile({
    required this.name,
    required this.xp,
    required this.level,
    required this.breakdown,
    required this.rank,
    required this.nextRank,
    required this.badges,
    required this.peakBankroll,
    required this.daysPlayed,
    required this.dayStreak,
    required this.tablesReached,
  });

  final String name;
  final int xp;
  final int level;
  final XpBreakdown breakdown;
  final Rank rank;
  final Rank? nextRank;
  final List<Achievement> badges;
  final int peakBankroll;
  final int daysPlayed;
  final int dayStreak;
  final int tablesReached;

  int get xpAtLevelStart => xpForLevel(level);
  int get xpAtNextLevel => xpForLevel(level + 1);
  int get xpIntoLevel => xp - xpAtLevelStart;
  int get xpNeededForLevel => xpAtNextLevel - xpAtLevelStart;
  int get xpToNextLevel => xpAtNextLevel - xp;

  double get levelProgress =>
      xpNeededForLevel <= 0 ? 1 : (xpIntoLevel / xpNeededForLevel).clamp(0.0, 1.0);

  List<Achievement> get earned => badges.where((b) => b.earned).toList();

  /// The closest unearned badges, for the "next up" line.
  List<Achievement> nearest({int limit = 3}) {
    final open = badges.where((b) => !b.earned).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    return open.take(limit).toList();
  }

  bool get isNew => xp == 0;

  static Profile of({
    required String name,
    required StatsData lifetime,
    required int peakBankroll,
    required int daysPlayed,
    required int dayStreak,
  }) {
    // Every preset table whose seating minimum this bankroll has ever cleared.
    // The bottom table seats at zero, so a peak of zero would otherwise hand
    // someone who has never played a table's worth of experience.
    var tables = 0;
    if (peakBankroll > 0) {
      for (final t in kTiers) {
        if (!t.isCustom && peakBankroll >= t.sitMin) tables++;
      }
    }

    final breakdown = XpBreakdown(
      rounds: lifetime.rounds * Xp.perRound,
      accuracy: lifetime.correct * Xp.perCorrectDecision,
      winnings: lifetime.net > 0 ? lifetime.net ~/ Xp.chipsPerPoint : 0,
      days: daysPlayed * Xp.perDayPlayed,
      tables: tables * Xp.perTableReached,
    );

    final xp = breakdown.total;
    final level = levelForXp(xp);

    return Profile(
      name: name,
      xp: xp,
      level: level,
      breakdown: breakdown,
      rank: rankForLevel(level),
      nextRank: nextRankAfter(level),
      badges: _achievementsFor(
        lifetime: lifetime,
        peakBankroll: peakBankroll,
        daysPlayed: daysPlayed,
        dayStreak: dayStreak,
      ),
      peakBankroll: peakBankroll,
      daysPlayed: daysPlayed,
      dayStreak: dayStreak,
      tablesReached: tables,
    );
  }

  static List<Achievement> _achievementsFor({
    required StatsData lifetime,
    required int peakBankroll,
    required int daysPlayed,
    required int dayStreak,
  }) {
    final s = lifetime;

    // Accuracy badges only mean anything over a real sample, so they carry
    // their own volume requirement and report progress against whichever of
    // the two is further behind.
    Achievement accuracyAchievement({
      required String id,
      required String name,
      required String note,
      required double target,
      required int minDecisions,
    }) {
      if (s.decisions < minDecisions) {
        return Achievement(
          id: id,
          name: name,
          note: note,
          progress: (s.decisions / minDecisions).clamp(0.0, 0.99),
          progressLabel: '${s.decisions} / $minDecisions decisions',
        );
      }
      final hit = s.accuracy >= target;
      return Achievement(
        id: id,
        name: name,
        note: note,
        progress: hit ? 1 : (s.accuracy / target).clamp(0.0, 0.99),
        progressLabel: hit
            ? 'Earned'
            : '${(s.accuracy * 100).toStringAsFixed(1)}% of '
                '${(target * 100).toStringAsFixed(0)}%',
      );
    }

    return [
      _count(
        id: 'first',
        name: 'First Hand',
        note: 'Sat down and played one.',
        have: s.rounds,
        need: 1,
      ),
      _count(
        id: 'natural',
        name: 'Natural',
        note: 'Drew a blackjack.',
        have: s.blackjacks,
        need: 1,
      ),
      _count(
        id: 'hundred',
        name: 'Hundred Up',
        note: 'A hundred rounds dealt.',
        have: s.rounds,
        need: 100,
      ),
      _count(
        id: 'thousand',
        name: 'Four Figures',
        note: 'A thousand rounds dealt.',
        have: s.rounds,
        need: 1000,
      ),
      _count(
        id: 'tenthousand',
        name: 'Lifer',
        note: 'Ten thousand rounds dealt.',
        have: s.rounds,
        need: 10000,
      ),
      accuracyAchievement(
        id: 'sharp',
        name: 'By The Book',
        note: '95% of your decisions matched the chart.',
        target: 0.95,
        minDecisions: 500,
      ),
      accuracyAchievement(
        id: 'textbook',
        name: 'Textbook',
        note: '99% accuracy over a thousand decisions.',
        target: 0.99,
        minDecisions: 1000,
      ),
      _count(
        id: 'streak',
        name: 'Hot Run',
        note: 'Won eight rounds in a row.',
        have: s.bestWinStreak,
        need: 8,
      ),
      _count(
        id: 'dealerbust',
        name: 'Let Them Bust',
        note: 'Watched the dealer break a hundred times.',
        have: s.dealerBusts,
        need: 100,
      ),
      _count(
        id: 'week',
        name: 'Iron Week',
        note: 'Played seven days running.',
        have: dayStreak,
        need: 7,
      ),
      _count(
        id: 'month',
        name: 'Month Straight',
        note: 'Played thirty days running.',
        have: dayStreak,
        need: 30,
      ),
      _count(
        id: 'hundreddays',
        name: 'Hundred Days',
        note: 'A hundred separate days at the table.',
        have: daysPlayed,
        need: 100,
      ),
      _count(
        id: 'purple',
        name: 'Purple',
        note: 'Built a bankroll big enough for the Purple table.',
        have: peakBankroll,
        need: 10000,
      ),
      _count(
        id: 'salon',
        name: 'Salon Privé',
        note: 'Built a bankroll big enough for the best game in the house.',
        have: peakBankroll,
        need: 50000,
      ),
      Achievement(
        id: 'unmarked',
        name: 'Never Asked',
        note: 'Five hundred rounds without taking a marker.',
        progress: s.markers > 0 ? 0 : (s.rounds / 500).clamp(0.0, 1.0),
        progressLabel: s.markers > 0
            ? 'Marker taken'
            : s.rounds >= 500
                ? 'Earned'
                : '${s.rounds} / 500',
      ),
    ];
  }
}

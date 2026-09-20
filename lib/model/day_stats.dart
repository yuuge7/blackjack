import 'hand.dart';

/// One calendar day's play, and the unit every calendar total is built from.
///
/// Stored as a plain list of counters rather than a keyed object: a player who
/// sits down most days for a few years accumulates thousands of these, and the
/// list form is roughly a third of the size on disk with no lookup cost.
class DayStats {
  DayStats();

  int rounds = 0;
  int hands = 0;
  int wins = 0;
  int losses = 0;
  int pushes = 0;
  int blackjacks = 0;
  int busts = 0;
  int dealerBusts = 0;
  int surrenders = 0;
  int doubles = 0;
  int splits = 0;
  int insuranceTaken = 0;
  int insuranceWon = 0;

  int wagered = 0;
  int net = 0;
  int biggestWin = 0;
  int biggestLoss = 0;

  int bestWinStreak = 0;
  int worstLossStreak = 0;

  int decisions = 0;
  int correct = 0;

  int markers = 0;
  int marked = 0;

  /// How many times the app was opened and played on this day.
  int sessions = 0;

  /// The streak still running at the end of the day, so reopening the app on
  /// the same day picks the run back up instead of restarting it.
  int streak = 0;

  double get winRate {
    final decided = wins + losses;
    return decided == 0 ? 0 : wins / decided;
  }

  double get accuracy => decisions == 0 ? 0 : correct / decisions;

  /// What the table actually took, per chip wagered.
  double get realizedEdge => wagered == 0 ? 0 : -net / wagered * 100;

  double get avgBet => rounds == 0 ? 0 : wagered / rounds;

  bool get isEmpty => rounds == 0 && markers == 0;

  bool get isNotEmpty => !isEmpty;

  // --- recording -----------------------------------------------------------

  void recordHand(Hand h) {
    hands++;
    if (h.doubled) doubles++;
    if (h.fromSplit) splits++;
    switch (h.outcome) {
      case Outcome.blackjack:
      case Outcome.win:
      case Outcome.dealerBust:
        wins++;
        if (h.outcome == Outcome.blackjack) blackjacks++;
        if (h.outcome == Outcome.dealerBust) dealerBusts++;
      case Outcome.push:
        pushes++;
      case Outcome.bust:
        losses++;
        busts++;
      case Outcome.surrender:
        losses++;
        surrenders++;
      case Outcome.lose:
        losses++;
      case null:
        break;
    }
  }

  void recordRound({required int roundNet, required int roundWagered}) {
    rounds++;
    wagered += roundWagered;
    net += roundNet;
    if (roundNet > biggestWin) biggestWin = roundNet;
    if (roundNet < biggestLoss) biggestLoss = roundNet;

    if (roundNet > 0) {
      streak = streak > 0 ? streak + 1 : 1;
      if (streak > bestWinStreak) bestWinStreak = streak;
    } else if (roundNet < 0) {
      streak = streak < 0 ? streak - 1 : -1;
      if (streak < worstLossStreak) worstLossStreak = streak;
    }
  }

  void recordDecision({required bool wasCorrect}) {
    decisions++;
    if (wasCorrect) correct++;
  }

  void recordMarker(int amount) {
    markers++;
    marked += amount;
  }

  void recordInsurance({required bool won}) {
    insuranceTaken++;
    if (won) insuranceWon++;
  }

  // --- aggregation ---------------------------------------------------------

  /// Folds another day into this one. Counters sum; records take the extreme.
  /// The running [streak] is dropped, because a streak across a month boundary
  /// is not a thing that happened.
  void absorb(DayStats o) {
    rounds += o.rounds;
    hands += o.hands;
    wins += o.wins;
    losses += o.losses;
    pushes += o.pushes;
    blackjacks += o.blackjacks;
    busts += o.busts;
    dealerBusts += o.dealerBusts;
    surrenders += o.surrenders;
    doubles += o.doubles;
    splits += o.splits;
    insuranceTaken += o.insuranceTaken;
    insuranceWon += o.insuranceWon;
    wagered += o.wagered;
    net += o.net;
    decisions += o.decisions;
    correct += o.correct;
    markers += o.markers;
    marked += o.marked;
    sessions += o.sessions;
    if (o.biggestWin > biggestWin) biggestWin = o.biggestWin;
    if (o.biggestLoss < biggestLoss) biggestLoss = o.biggestLoss;
    if (o.bestWinStreak > bestWinStreak) bestWinStreak = o.bestWinStreak;
    if (o.worstLossStreak < worstLossStreak) worstLossStreak = o.worstLossStreak;
    streak = 0;
  }

  DayStats copy() => DayStats()..absorb(this)..streak = streak;

  // --- serialisation -------------------------------------------------------

  /// Field order is append-only. A shorter list is an older save and the
  /// missing tail reads as zero; a longer one came from a newer build and the
  /// tail is ignored rather than fatal.
  List<int> toList() {
    final out = <int>[
      rounds, hands, wins, losses, pushes, blackjacks, busts, dealerBusts,
      surrenders, doubles, splits, insuranceTaken, insuranceWon, wagered, net,
      biggestWin, biggestLoss, bestWinStreak, worstLossStreak, decisions,
      correct, markers, marked, sessions, streak,
    ];
    // Most days never touch insurance, surrender or a marker, so the tail is
    // usually zeros. Trimming them is free and keeps a decade of play small.
    var end = out.length;
    while (end > 0 && out[end - 1] == 0) {
      end--;
    }
    return out.sublist(0, end);
  }

  static DayStats fromList(List<dynamic> raw) {
    final s = DayStats();
    int at(int i) => i < raw.length ? ((raw[i] as num?)?.toInt() ?? 0) : 0;
    s.rounds = at(0);
    s.hands = at(1);
    s.wins = at(2);
    s.losses = at(3);
    s.pushes = at(4);
    s.blackjacks = at(5);
    s.busts = at(6);
    s.dealerBusts = at(7);
    s.surrenders = at(8);
    s.doubles = at(9);
    s.splits = at(10);
    s.insuranceTaken = at(11);
    s.insuranceWon = at(12);
    s.wagered = at(13);
    s.net = at(14);
    s.biggestWin = at(15);
    s.biggestLoss = at(16);
    s.bestWinStreak = at(17);
    s.worstLossStreak = at(18);
    s.decisions = at(19);
    s.correct = at(20);
    s.markers = at(21);
    s.marked = at(22);
    s.sessions = at(23);
    s.streak = at(24);
    return s;
  }
}

/// A month, a year, or any other run of days, summed up with the few facts
/// that only make sense across more than one day.
class PeriodStats {
  PeriodStats({
    required this.totals,
    required this.daysPlayed,
    required this.bestDay,
    required this.worstDay,
    required this.busiestDay,
  });

  final DayStats totals;
  final int daysPlayed;

  /// The single best and worst days by net, and the day with the most rounds.
  /// Null when nothing was played in the period.
  final DateTime? bestDay;
  final DateTime? worstDay;
  final DateTime? busiestDay;

  bool get isEmpty => daysPlayed == 0;

  static PeriodStats of(Map<DateTime, DayStats> days) {
    final totals = DayStats();
    DateTime? best, worst, busiest;
    var bestNet = 0, worstNet = 0, mostRounds = -1;
    var played = 0;

    final keys = days.keys.toList()..sort();
    for (final date in keys) {
      final d = days[date]!;
      if (d.isEmpty) continue;
      played++;
      totals.absorb(d);
      if (best == null || d.net > bestNet) {
        best = date;
        bestNet = d.net;
      }
      if (worst == null || d.net < worstNet) {
        worst = date;
        worstNet = d.net;
      }
      if (d.rounds > mostRounds) {
        busiest = date;
        mostRounds = d.rounds;
      }
    }

    return PeriodStats(
      totals: totals,
      daysPlayed: played,
      bestDay: played == 0 ? null : best,
      worstDay: played == 0 ? null : worst,
      busiestDay: played == 0 ? null : busiest,
    );
  }
}

/// Dates are keyed by day, never by instant. Everything the calendar stores is
/// local-time, because "what did I play on the 3rd" is a local-time question.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// `MMDD`, the key a year's worth of days is stored under.
int dayKey(int month, int day) => month * 100 + day;

int monthOfKey(int key) => key ~/ 100;

int dayOfKey(int key) => key % 100;

const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Monday-first, which is how the grid is laid out.
const List<String> kWeekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

int daysInMonth(int year, int month) =>
    DateTime(year, month + 1, 0).day;

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

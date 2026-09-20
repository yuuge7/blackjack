import 'hand.dart';

/// How often one decision point was played, and how often it was misplayed.
class Leak {
  Leak({this.total = 0, this.wrong = 0, this.lastMistake = ''});

  int total;
  int wrong;
  String lastMistake;

  double get errorRate => total == 0 ? 0 : wrong / total;
}

/// Everything the Stats tab reads. One instance holds the lifetime record,
/// another holds the current session so the two can be compared.
class StatsData {
  StatsData();

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

  int streak = 0;
  int bestWinStreak = 0;
  int worstLossStreak = 0;

  int decisions = 0;
  int correct = 0;

  /// Comped chips the house handed over when you ran dry. Kept separate from
  /// [net], which only ever counts money that crossed the table.
  int markers = 0;
  int marked = 0;

  final Map<String, Leak> leaks = {};
  final List<int> bankrollHistory = [];

  double get winRate {
    final decided = wins + losses;
    return decided == 0 ? 0 : wins / decided;
  }

  double get accuracy => decisions == 0 ? 0 : correct / decisions;

  /// Realized house edge: what the table actually took, per chip wagered.
  double get realizedEdge => wagered == 0 ? 0 : -net / wagered * 100;

  double get avgBet => rounds == 0 ? 0 : wagered / rounds;

  /// A marker with no rounds yet is still something worth showing.
  bool get isEmpty => rounds == 0 && markers == 0;

  void recordMarker(int amount) {
    markers++;
    marked += amount;
  }

  void recordDecision(String key, bool wasCorrect, String played) {
    decisions++;
    if (wasCorrect) correct++;
    final leak = leaks.putIfAbsent(key, Leak.new);
    leak.total++;
    if (!wasCorrect) {
      leak.wrong++;
      leak.lastMistake = played;
    }
    if (leaks.length > 140) _trimLeaks();
  }

  void _trimLeaks() {
    final entries = leaks.entries.toList()
      ..sort((a, b) => a.value.total.compareTo(b.value.total));
    for (final e in entries.take(40)) {
      if (e.value.wrong == 0) leaks.remove(e.key);
    }
  }

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

  void recordRound({required int roundNet, required int roundWagered, required int bankroll}) {
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

    bankrollHistory.add(bankroll);
    if (bankrollHistory.length > 400) bankrollHistory.removeAt(0);
  }

  /// Leaks worth practising: played enough times to be real, misplayed most.
  List<MapEntry<String, Leak>> topLeaks({int limit = 6}) {
    final list = leaks.entries.where((e) => e.value.wrong > 0).toList()
      ..sort((a, b) {
        final byWrong = b.value.wrong.compareTo(a.value.wrong);
        return byWrong != 0 ? byWrong : b.value.errorRate.compareTo(a.value.errorRate);
      });
    return list.take(limit).toList();
  }

  Map<String, dynamic> toJson() => {
        'rounds': rounds,
        'hands': hands,
        'wins': wins,
        'losses': losses,
        'pushes': pushes,
        'bj': blackjacks,
        'busts': busts,
        'dbusts': dealerBusts,
        'surr': surrenders,
        'dbl': doubles,
        'spl': splits,
        'insT': insuranceTaken,
        'insW': insuranceWon,
        'wagered': wagered,
        'net': net,
        'bigWin': biggestWin,
        'bigLoss': biggestLoss,
        'streak': streak,
        'bestWin': bestWinStreak,
        'worstLoss': worstLossStreak,
        'dec': decisions,
        'cor': correct,
        'markers': markers,
        'marked': marked,
        'leaks': leaks.map((k, v) => MapEntry(k, [v.total, v.wrong, v.lastMistake])),
        'curve': bankrollHistory,
      };

  static StatsData fromJson(Map<String, dynamic> j) {
    final s = StatsData();
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    s.rounds = i('rounds');
    s.hands = i('hands');
    s.wins = i('wins');
    s.losses = i('losses');
    s.pushes = i('pushes');
    s.blackjacks = i('bj');
    s.busts = i('busts');
    s.dealerBusts = i('dbusts');
    s.surrenders = i('surr');
    s.doubles = i('dbl');
    s.splits = i('spl');
    s.insuranceTaken = i('insT');
    s.insuranceWon = i('insW');
    s.wagered = i('wagered');
    s.net = i('net');
    s.biggestWin = i('bigWin');
    s.biggestLoss = i('bigLoss');
    s.streak = i('streak');
    s.bestWinStreak = i('bestWin');
    s.worstLossStreak = i('worstLoss');
    s.decisions = i('dec');
    s.correct = i('cor');
    s.markers = i('markers');
    s.marked = i('marked');
    final raw = j['leaks'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List && v.length >= 2) {
          s.leaks[k as String] = Leak(
            total: (v[0] as num).toInt(),
            wrong: (v[1] as num).toInt(),
            lastMistake: v.length > 2 ? (v[2] as String? ?? '') : '',
          );
        }
      });
    }
    final curve = j['curve'];
    if (curve is List) {
      s.bankrollHistory.addAll(curve.map((e) => (e as num).toInt()));
    }
    return s;
  }
}

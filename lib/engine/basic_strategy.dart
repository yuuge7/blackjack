import '../model/card.dart';
import '../model/hand.dart';
import '../model/rules.dart';

enum Move { hit, stand, double, split, surrender }

extension MoveX on Move {
  String get label => switch (this) {
        Move.hit => 'Hit',
        Move.stand => 'Stand',
        Move.double => 'Double',
        Move.split => 'Split',
        Move.surrender => 'Surrender',
      };

  /// Single letter used in the strategy chart.
  String get code => switch (this) {
        Move.hit => 'H',
        Move.stand => 'S',
        Move.double => 'D',
        Move.split => 'P',
        Move.surrender => 'R',
      };
}

class StrategyCall {
  const StrategyCall(this.move, this.key);

  /// What perfect basic strategy plays here.
  final Move move;

  /// Stable label for this decision point, e.g. `Hard 16 v 10`.
  final String key;
}

String _dealerLabel(int d) => d == 11 ? 'A' : '$d';

/// Multi-deck basic strategy, adjusted for the posted rules. Returns the move
/// the player should make given which moves are actually available.
class BasicStrategy {
  const BasicStrategy._();

  static StrategyCall recommend({
    required Hand hand,
    required PlayingCard dealerUp,
    required RuleSet rules,
    required bool canDouble,
    required bool canSplit,
    required bool canSurrender,
  }) {
    final d = dealerUp.value; // 2..11, ace counts 11
    final total = hand.total;
    final soft = hand.isSoft;

    if (canSplit && hand.isPair) {
      final p = hand.cards[0].value;
      final key = 'Pair ${p == 11 ? 'A' : p}s v ${_dealerLabel(d)}';
      // Under H17 with late surrender, 8s against an ace is a surrender.
      if (p == 8 && d == 11 && canSurrender && rules.dealerHitsSoft17) {
        return StrategyCall(Move.surrender, key);
      }
      if (_shouldSplit(p, d, rules.doubleAfterSplit)) {
        return StrategyCall(Move.split, key);
      }
    }

    if (soft && total < 21) {
      final key = 'Soft $total v ${_dealerLabel(d)}';
      final wanted = _softMove(total, d, rules.dealerHitsSoft17);
      if (wanted == Move.double && !canDouble) {
        // A double you cannot make becomes the stand-or-hit it was built on.
        return StrategyCall(total >= 18 ? Move.stand : Move.hit, key);
      }
      return StrategyCall(wanted, key);
    }

    final key = 'Hard $total v ${_dealerLabel(d)}';
    final wanted = _hardMove(total, d, rules.dealerHitsSoft17);
    if (wanted == Move.surrender && !canSurrender) {
      return StrategyCall(total >= 17 ? Move.stand : Move.hit, key);
    }
    if (wanted == Move.double && !canDouble) {
      return StrategyCall(Move.hit, key);
    }
    return StrategyCall(wanted, key);
  }

  static bool _shouldSplit(int pair, int d, bool das) => switch (pair) {
        11 => true, // aces
        10 => false,
        9 => d != 7 && d != 10 && d != 11,
        8 => true,
        7 => d <= 7,
        6 => das ? d >= 2 && d <= 6 : d >= 3 && d <= 6,
        5 => false,
        4 => das && (d == 5 || d == 6),
        3 || 2 => das ? d <= 7 : d >= 4 && d <= 7,
        _ => false,
      };

  static Move _softMove(int total, int d, bool h17) {
    switch (total) {
      case 20:
      case 21:
        return Move.stand;
      case 19:
        return (h17 && d == 6) ? Move.double : Move.stand;
      case 18:
        if (d >= 9) return Move.hit;
        if (d == 7 || d == 8) return Move.stand;
        if (d == 2) return h17 ? Move.double : Move.stand;
        return Move.double; // 3..6
      case 17:
        return (d >= 3 && d <= 6) ? Move.double : Move.hit;
      case 16:
      case 15:
        return (d >= 4 && d <= 6) ? Move.double : Move.hit;
      case 14:
      case 13:
        return (d >= 5 && d <= 6) ? Move.double : Move.hit;
      default:
        return Move.hit;
    }
  }

  static Move _hardMove(int total, int d, bool h17) {
    if (total >= 18) return Move.stand;
    if (total == 17) return (h17 && d == 11) ? Move.surrender : Move.stand;
    if (total == 16) {
      if (d <= 6) return Move.stand;
      if (d >= 9) return Move.surrender;
      return Move.hit;
    }
    if (total == 15) {
      if (d <= 6) return Move.stand;
      if (d == 10) return Move.surrender;
      if (d == 11 && h17) return Move.surrender;
      return Move.hit;
    }
    if (total == 14 || total == 13) return d <= 6 ? Move.stand : Move.hit;
    if (total == 12) return (d >= 4 && d <= 6) ? Move.stand : Move.hit;
    if (total == 11) return (d == 11 && !h17) ? Move.hit : Move.double;
    if (total == 10) return d <= 9 ? Move.double : Move.hit;
    if (total == 9) return (d >= 3 && d <= 6) ? Move.double : Move.hit;
    return Move.hit;
  }

  /// Chart cell for the reference table in the Rules tab, assuming every move
  /// is available.
  static Move chartCell({
    required ChartRow row,
    required int playerValue,
    required int dealerValue,
    required RuleSet rules,
  }) {
    switch (row) {
      case ChartRow.pairs:
        if (playerValue == 8 && dealerValue == 11 && rules.lateSurrender && rules.dealerHitsSoft17) {
          return Move.surrender;
        }
        if (_shouldSplit(playerValue, dealerValue, rules.doubleAfterSplit)) return Move.split;
        if (playerValue == 11) return Move.split;
        final asTotal = playerValue == 11 ? 12 : playerValue * 2;
        return playerValue == 11
            ? _softMove(asTotal, dealerValue, rules.dealerHitsSoft17)
            : _hardMove(asTotal, dealerValue, rules.dealerHitsSoft17);
      case ChartRow.soft:
        return _softMove(playerValue, dealerValue, rules.dealerHitsSoft17);
      case ChartRow.hard:
        final m = _hardMove(playerValue, dealerValue, rules.dealerHitsSoft17);
        if (m == Move.surrender && !rules.lateSurrender) {
          return playerValue >= 17 ? Move.stand : Move.hit;
        }
        return m;
    }
  }
}

enum ChartRow { hard, soft, pairs }

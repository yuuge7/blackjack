import 'card.dart';

enum Outcome { blackjack, win, dealerBust, push, lose, bust, surrender }

extension OutcomeX on Outcome {
  bool get isWin => this == Outcome.win || this == Outcome.blackjack || this == Outcome.dealerBust;
  bool get isLoss => this == Outcome.lose || this == Outcome.bust || this == Outcome.surrender;

  String get label => switch (this) {
        Outcome.blackjack => 'Blackjack',
        Outcome.win => 'Win',
        Outcome.dealerBust => 'Dealer busts',
        Outcome.push => 'Push',
        Outcome.lose => 'Lose',
        Outcome.bust => 'Bust',
        Outcome.surrender => 'Surrendered',
      };
}

/// One wagered position. A split produces additional hands that each carry
/// their own bet and settle independently.
class Hand {
  Hand({required this.bet, this.fromSplit = false});

  final List<PlayingCard> cards = [];
  int bet;
  bool fromSplit;
  bool doubled = false;
  bool stood = false;
  bool surrendered = false;

  /// Split aces receive exactly one card and are then closed out.
  bool splitAce = false;

  Outcome? outcome;

  /// Chips won or lost on this hand, filled in at settlement.
  int net = 0;

  int get total {
    var t = 0;
    var aces = 0;
    for (final c in cards) {
      t += c.value;
      if (c.isAce) aces++;
    }
    while (t > 21 && aces > 0) {
      t -= 10;
      aces--;
    }
    return t;
  }

  /// True while an ace is still being counted as eleven.
  bool get isSoft {
    var t = 0;
    var aces = 0;
    for (final c in cards) {
      t += c.value;
      if (c.isAce) aces++;
    }
    while (t > 21 && aces > 0) {
      t -= 10;
      aces--;
    }
    return aces > 0;
  }

  bool get isBust => total > 21;
  bool get isBlackjack => cards.length == 2 && total == 21 && !fromSplit;
  bool get isPair => cards.length == 2 && cards[0].value == cards[1].value;
  bool get isClosed => stood || surrendered || isBust || total >= 21;

  String get readout => cards.map((c) => c.label).join(' ');

  /// Moves the second card into a brand new hand carrying an equal bet.
  Hand splitOff() {
    final moved = cards.removeLast();
    final other = Hand(bet: bet, fromSplit: true);
    other.cards.add(moved);
    other.splitAce = moved.isAce;
    fromSplit = true;
    splitAce = cards.first.isAce;
    return other;
  }
}

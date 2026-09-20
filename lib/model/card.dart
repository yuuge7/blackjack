import 'package:flutter/foundation.dart';

enum Suit { spades, hearts, diamonds, clubs }

extension SuitX on Suit {
  /// Unicode pip used on the card face and in compact hand read-outs.
  String get glyph => const ['♠', '♥', '♦', '♣'][index];
  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

extension RankX on Rank {
  String get label =>
      const ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'][index];

  /// Blackjack value. Aces count 11 here; [Hand] demotes them when needed.
  int get value {
    if (this == Rank.ace) return 11;
    return index <= 7 ? index + 2 : 10;
  }

  /// Hi-Lo tag: low cards leaving the shoe move the count in the player's favour.
  int get hiLo {
    if (index <= 4) return 1; // 2..6
    if (index <= 7) return 0; // 7..9
    return -1; // 10, J, Q, K, A
  }
}

@immutable
class PlayingCard {
  const PlayingCard(this.rank, this.suit, this.id);

  final Rank rank;
  final Suit suit;

  /// Unique within a shoe, so widgets keep identity across rebuilds.
  final int id;

  int get value => rank.value;
  int get hiLo => rank.hiLo;
  bool get isAce => rank == Rank.ace;
  bool get isTen => rank.value == 10;

  String get label => '${rank.label}${suit.glyph}';

  @override
  String toString() => label;
}

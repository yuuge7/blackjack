import 'package:blackjack/engine/basic_strategy.dart';
import 'package:blackjack/model/card.dart';
import 'package:blackjack/model/hand.dart';
import 'package:blackjack/model/rules.dart';
import 'package:blackjack/model/shoe.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard c(Rank r, [Suit s = Suit.spades]) => PlayingCard(r, s, r.index);

Hand handOf(List<Rank> ranks, {bool fromSplit = false, int bet = 10}) {
  final h = Hand(bet: bet, fromSplit: fromSplit);
  for (var i = 0; i < ranks.length; i++) {
    h.cards.add(PlayingCard(ranks[i], Suit.values[i % 4], i));
  }
  return h;
}

void main() {
  group('hand totals', () {
    test('an ace counts eleven until it would bust', () {
      expect(handOf([Rank.ace, Rank.six]).total, 17);
      expect(handOf([Rank.ace, Rank.six]).isSoft, isTrue);

      final hard = handOf([Rank.ace, Rank.six, Rank.king]);
      expect(hard.total, 17);
      expect(hard.isSoft, isFalse);
    });

    test('two aces make a soft twelve', () {
      final h = handOf([Rank.ace, Rank.ace]);
      expect(h.total, 12);
      expect(h.isSoft, isTrue);
    });

    test('blackjack needs two cards and no split', () {
      expect(handOf([Rank.ace, Rank.king]).isBlackjack, isTrue);
      expect(handOf([Rank.ace, Rank.king], fromSplit: true).isBlackjack, isFalse);
      expect(handOf([Rank.five, Rank.six, Rank.ten]).isBlackjack, isFalse);
    });

    test('any two ten-value cards are a pair', () {
      expect(handOf([Rank.king, Rank.queen]).isPair, isTrue);
      expect(handOf([Rank.king, Rank.nine]).isPair, isFalse);
    });

    test('splitting moves the second card to a new hand', () {
      final h = handOf([Rank.eight, Rank.eight], bet: 25);
      final other = h.splitOff();
      expect(h.cards.length, 1);
      expect(other.cards.length, 1);
      expect(other.bet, 25);
      expect(other.fromSplit, isTrue);
      expect(h.fromSplit, isTrue);
    });
  });

  group('basic strategy', () {
    const s17 = RuleSet();
    const h17 = RuleSet(dealerHitsSoft17: true);

    Move call(
      Hand hand,
      Rank up, {
      RuleSet rules = s17,
      bool canDouble = true,
      bool canSplit = true,
      bool canSurrender = true,
    }) =>
        BasicStrategy.recommend(
          hand: hand,
          dealerUp: c(up),
          rules: rules,
          canDouble: canDouble,
          canSplit: canSplit,
          canSurrender: canSurrender,
        ).move;

    test('hard 16 against a ten surrenders, or hits when it cannot', () {
      expect(call(handOf([Rank.ten, Rank.six]), Rank.king), Move.surrender);
      expect(
        call(handOf([Rank.ten, Rank.six]), Rank.king, canSurrender: false),
        Move.hit,
      );
    });

    test('hard 16 stands against a bust card', () {
      expect(call(handOf([Rank.ten, Rank.six]), Rank.six), Move.stand);
    });

    test('eleven against an ace follows the soft 17 rule', () {
      expect(call(handOf([Rank.six, Rank.five]), Rank.ace), Move.hit);
      expect(call(handOf([Rank.six, Rank.five]), Rank.ace, rules: h17), Move.double);
    });

    test('soft 18 doubles, stands and hits in the right places', () {
      expect(call(handOf([Rank.ace, Rank.seven]), Rank.three), Move.double);
      expect(call(handOf([Rank.ace, Rank.seven]), Rank.two), Move.stand);
      expect(call(handOf([Rank.ace, Rank.seven]), Rank.two, rules: h17), Move.double);
      expect(call(handOf([Rank.ace, Rank.seven]), Rank.nine), Move.hit);
      expect(call(handOf([Rank.ace, Rank.seven]), Rank.eight), Move.stand);
    });

    test('a double you cannot make falls back correctly', () {
      expect(
        call(handOf([Rank.ace, Rank.seven]), Rank.three, canDouble: false),
        Move.stand,
      );
      expect(
        call(handOf([Rank.ace, Rank.three]), Rank.five, canDouble: false),
        Move.hit,
      );
    });

    test('always split aces and eights, never tens', () {
      expect(call(handOf([Rank.ace, Rank.ace]), Rank.king), Move.split);
      expect(call(handOf([Rank.eight, Rank.eight]), Rank.ten), Move.split);
      expect(call(handOf([Rank.king, Rank.queen]), Rank.six), Move.stand);
    });

    test('splitting fours depends on double after split', () {
      expect(call(handOf([Rank.four, Rank.four]), Rank.five), Move.split);
      expect(
        call(
          handOf([Rank.four, Rank.four]),
          Rank.five,
          rules: const RuleSet(doubleAfterSplit: false),
        ),
        Move.hit,
      );
    });

    test('a pair you do not split is played as its total', () {
      // Fives are a hard ten, which doubles against a nine.
      expect(call(handOf([Rank.five, Rank.five]), Rank.nine), Move.double);
    });

    test('the chart agrees with the live recommendation', () {
      for (final dealer in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
        final fromChart = BasicStrategy.chartCell(
          row: ChartRow.hard,
          playerValue: 16,
          dealerValue: dealer,
          rules: s17,
        );
        final live = call(handOf([Rank.ten, Rank.six]), _rankFor(dealer));
        expect(fromChart, live, reason: 'hard 16 v $dealer');
      }
    });
  });

  group('shoe', () {
    test('holds the right number of cards and cuts inside them', () {
      final shoe = Shoe(decks: 6, penetration: 0.75, seed: 1);
      expect(shoe.cardsTotal, 312);
      expect(shoe.cardsToCut, greaterThan(0));
      expect(shoe.cardsToCut, lessThan(312));
    });

    test('a full deck is count neutral', () {
      final shoe = Shoe(decks: 1, penetration: 0.99, seed: 42);
      for (var i = 0; i < 52; i++) {
        shoe.draw();
      }
      expect(shoe.runningCount, 0);
    });

    test('the running count follows Hi-Lo tags', () {
      expect(Rank.two.hiLo, 1);
      expect(Rank.six.hiLo, 1);
      expect(Rank.seven.hiLo, 0);
      expect(Rank.nine.hiLo, 0);
      expect(Rank.ten.hiLo, -1);
      expect(Rank.ace.hiLo, -1);
    });
  });

  group('rules', () {
    test('house edge responds to the conditions', () {
      const base = RuleSet();
      // Six decks, stands on soft 17, double after split, no surrender.
      expect(base.copyWith(lateSurrender: false).houseEdge, closeTo(0.40, 0.001));
      expect(base.houseEdge, lessThan(0.40));
      expect(base.copyWith(payout: Payout.sixToFive).houseEdge, greaterThan(1.5));
      expect(base.copyWith(dealerHitsSoft17: true).houseEdge, greaterThan(base.houseEdge));
      expect(base.copyWith(decks: 1).houseEdge, lessThan(base.houseEdge));
    });

    test('doubling restrictions are enforced', () {
      expect(DoubleRule.tenEleven.allows(9, false), isFalse);
      expect(DoubleRule.tenEleven.allows(10, false), isTrue);
      expect(DoubleRule.nineToEleven.allows(17, true), isFalse);
      expect(DoubleRule.any.allows(17, true), isTrue);
    });
  });
}

Rank _rankFor(int value) => switch (value) {
      11 => Rank.ace,
      10 => Rank.ten,
      _ => Rank.values[value - 2],
    };

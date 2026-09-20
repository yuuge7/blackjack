enum Payout { threeToTwo, sixToFive }

extension PayoutX on Payout {
  double get multiplier => this == Payout.threeToTwo ? 1.5 : 1.2;
  String get label => this == Payout.threeToTwo ? '3 to 2' : '6 to 5';
}

enum DoubleRule { any, nineToEleven, tenEleven }

extension DoubleRuleX on DoubleRule {
  String get label => switch (this) {
        DoubleRule.any => 'Any two cards',
        DoubleRule.nineToEleven => 'Hard 9 to 11',
        DoubleRule.tenEleven => 'Hard 10 and 11',
      };

  bool allows(int total, bool soft) => switch (this) {
        DoubleRule.any => true,
        DoubleRule.nineToEleven => !soft && total >= 9 && total <= 11,
        DoubleRule.tenEleven => !soft && total >= 10 && total <= 11,
      };
}

/// The table's posted conditions. The engine and the strategy trainer both
/// read from this so a hint always matches the table you are sitting at.
class RuleSet {
  const RuleSet({
    this.decks = 6,
    this.dealerHitsSoft17 = false,
    this.doubleAfterSplit = true,
    this.doubleRule = DoubleRule.any,
    this.maxHands = 4,
    this.resplitAces = false,
    this.hitSplitAces = false,
    this.lateSurrender = true,
    this.payout = Payout.threeToTwo,
    this.penetration = 0.75,
  });

  final int decks;
  final bool dealerHitsSoft17;
  final bool doubleAfterSplit;
  final DoubleRule doubleRule;
  final int maxHands;
  final bool resplitAces;
  final bool hitSplitAces;
  final bool lateSurrender;
  final Payout payout;
  final double penetration;

  RuleSet copyWith({
    int? decks,
    bool? dealerHitsSoft17,
    bool? doubleAfterSplit,
    DoubleRule? doubleRule,
    int? maxHands,
    bool? resplitAces,
    bool? hitSplitAces,
    bool? lateSurrender,
    Payout? payout,
    double? penetration,
  }) =>
      RuleSet(
        decks: decks ?? this.decks,
        dealerHitsSoft17: dealerHitsSoft17 ?? this.dealerHitsSoft17,
        doubleAfterSplit: doubleAfterSplit ?? this.doubleAfterSplit,
        doubleRule: doubleRule ?? this.doubleRule,
        maxHands: maxHands ?? this.maxHands,
        resplitAces: resplitAces ?? this.resplitAces,
        hitSplitAces: hitSplitAces ?? this.hitSplitAces,
        lateSurrender: lateSurrender ?? this.lateSurrender,
        payout: payout ?? this.payout,
        penetration: penetration ?? this.penetration,
      );

  /// Screen-printed on the table arc, the way a real layout carries its terms.
  String get legend {
    final s17 = dealerHitsSoft17 ? 'DEALER HITS SOFT 17' : 'DEALER STANDS ON ALL 17s';
    return 'BLACKJACK PAYS ${payout.label.toUpperCase()}   ·   $s17';
  }

  /// House edge for these conditions against perfect basic strategy, in
  /// percent of the original wager. Built from the standard rule adjustments.
  double get houseEdge {
    var edge = 0.40; // 6 deck, S17, DAS, no surrender baseline
    edge += switch (decks) { 1 => -0.48, 2 => -0.19, 4 => -0.06, 6 => 0.0, _ => 0.02 };
    if (dealerHitsSoft17) edge += 0.22;
    if (!doubleAfterSplit) edge += 0.14;
    if (lateSurrender) edge -= 0.08;
    if (resplitAces) edge -= 0.08;
    if (hitSplitAces) edge -= 0.18;
    if (payout == Payout.sixToFive) edge += 1.39;
    edge += switch (doubleRule) {
      DoubleRule.any => 0.0,
      DoubleRule.nineToEleven => 0.09,
      DoubleRule.tenEleven => 0.18,
    };
    return edge;
  }

  Map<String, dynamic> toJson() => {
        'decks': decks,
        'h17': dealerHitsSoft17,
        'das': doubleAfterSplit,
        'dbl': doubleRule.index,
        'maxHands': maxHands,
        'rsa': resplitAces,
        'hsa': hitSplitAces,
        'ls': lateSurrender,
        'payout': payout.index,
        'pen': penetration,
      };

  static RuleSet fromJson(Map<String, dynamic> j) => RuleSet(
        decks: j['decks'] as int? ?? 6,
        dealerHitsSoft17: j['h17'] as bool? ?? false,
        doubleAfterSplit: j['das'] as bool? ?? true,
        doubleRule: DoubleRule.values[((j['dbl'] as int?) ?? 0).clamp(0, 2)],
        maxHands: j['maxHands'] as int? ?? 4,
        resplitAces: j['rsa'] as bool? ?? false,
        hitSplitAces: j['hsa'] as bool? ?? false,
        lateSurrender: j['ls'] as bool? ?? true,
        payout: Payout.values[((j['payout'] as int?) ?? 0).clamp(0, 1)],
        penetration: ((j['pen'] as num?) ?? 0.75).toDouble(),
      );
}

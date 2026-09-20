import 'rules.dart';

/// A table you can sit at. Higher tables take bigger bets and — the reason to
/// climb — post better conditions, so the house edge drops as you move up.
class TableTier {
  const TableTier({
    required this.id,
    required this.name,
    required this.blurb,
    required this.min,
    required this.max,
    required this.sitMin,
    required this.chips,
    required this.rules,
    required this.accentChip,
  });

  final String id;
  final String name;

  /// One line of why this table is different.
  final String blurb;

  final int min;
  final int max;

  /// Bankroll you need before the floor will seat you.
  final int sitMin;

  /// Denominations in this table's rack.
  final List<int> chips;

  final RuleSet rules;

  /// Denomination whose clay colours this table in the list.
  final int accentChip;

  bool get isCustom => id == 'custom';
}

/// The ladder. Conditions improve on the way up, which is the whole point.
const List<TableTier> kTiers = [
  TableTier(
    id: 'nickel',
    name: 'Nickel',
    blurb: 'Where everyone starts. The conditions are as bad as they look.',
    min: 5,
    max: 100,
    sitMin: 0,
    chips: [5, 25, 100],
    accentChip: 5,
    rules: RuleSet(
      decks: 8,
      dealerHitsSoft17: true,
      doubleAfterSplit: false,
      doubleRule: DoubleRule.nineToEleven,
      maxHands: 2,
      lateSurrender: false,
      payout: Payout.sixToFive,
      penetration: 0.60,
    ),
  ),
  TableTier(
    id: 'quarter',
    name: 'Quarter',
    blurb: 'Blackjack pays properly here. The dealer still hits soft 17.',
    min: 25,
    max: 500,
    sitMin: 500,
    chips: [25, 100, 500],
    accentChip: 25,
    rules: RuleSet(
      decks: 6,
      dealerHitsSoft17: true,
      maxHands: 3,
      lateSurrender: false,
      penetration: 0.70,
    ),
  ),
  TableTier(
    id: 'black',
    name: 'Black Action',
    blurb: 'The dealer stands on all seventeens, and you may surrender.',
    min: 100,
    max: 2500,
    sitMin: 2000,
    chips: [100, 500, 1000],
    accentChip: 100,
    rules: RuleSet(penetration: 0.75),
  ),
  TableTier(
    id: 'purple',
    name: 'Purple',
    blurb: 'Four decks, deep shoe, and you may split aces again.',
    min: 500,
    max: 10000,
    sitMin: 10000,
    chips: [500, 1000, 5000],
    accentChip: 500,
    rules: RuleSet(
      decks: 4,
      resplitAces: true,
      penetration: 0.80,
    ),
  ),
  TableTier(
    id: 'salon',
    name: 'Salon Privé',
    blurb: 'Two decks, cut deep. The best game in the house.',
    min: 2000,
    max: 50000,
    sitMin: 50000,
    chips: [1000, 5000, 25000],
    accentChip: 5000,
    rules: RuleSet(
      decks: 2,
      resplitAces: true,
      penetration: 0.85,
    ),
  ),
  TableTier(
    id: 'custom',
    name: 'House rules',
    blurb: 'A practice table you set up yourself. Always open.',
    min: 5,
    max: 500,
    sitMin: 0,
    chips: [5, 25, 100, 500],
    accentChip: 1,
    rules: RuleSet(),
  ),
];

TableTier tierById(String id) =>
    kTiers.firstWhere((t) => t.id == id, orElse: () => kTiers.first);

/// Tables you can afford to sit at right now.
Iterable<TableTier> seatableTiers(int bankroll) =>
    kTiers.where((t) => bankroll >= t.sitMin);

/// The next table up that is still out of reach, for the progress read-out.
TableTier? nextTierAbove(int bankroll) {
  for (final t in kTiers) {
    if (!t.isCustom && bankroll < t.sitMin) return t;
  }
  return null;
}

/// The best table this bankroll can sit at, used when a bust drops you down.
TableTier bestSeatable(int bankroll) {
  TableTier best = kTiers.first;
  for (final t in kTiers) {
    if (t.isCustom) continue;
    if (bankroll >= t.sitMin && bankroll >= t.min) best = t;
  }
  return best;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/basic_strategy.dart';
import '../model/hand.dart';
import '../model/rules.dart';
import '../model/shoe.dart';
import '../model/table_tier.dart';
import 'settings_store.dart';
import 'stats_store.dart';

enum Phase { betting, dealing, insurance, playerTurn, dealerTurn, settled }

/// What the floor comps you when you cannot cover the cheapest table. There is
/// always a marker available, so a session can never dead-end.
const int kMarkerAmount = 200;

/// Starting bankroll for a brand new player.
const int kOpeningStake = 500;

/// Runs one blackjack table: shoe, dealer, the player's hands, and the money.
class GameController extends ChangeNotifier {
  GameController({
    required this.settings,
    required this.stats,
    required this.prefs,
  }) {
    bankroll = prefs.getInt('bankroll') ?? kOpeningStake;
    bet = prefs.getInt('bet') ?? 25;
    _shoe = Shoe(decks: rules.decks, penetration: rules.penetration);
    settings.addListener(_onSettingsChanged);
    _ensureAffordableTable();
    _clampBet();
  }

  final SettingsStore settings;
  final StatsStore stats;
  final SharedPreferences prefs;

  RuleSet get rules => settings.rules;
  TableTier get tier => settings.tier;
  List<int> get chips => tier.chips;

  late Shoe _shoe;
  Shoe get shoe => _shoe;

  int bankroll = kOpeningStake;
  int bet = 25;
  int _lastBet = 25;
  int insuranceBet = 0;

  Phase phase = Phase.betting;
  Hand dealer = Hand(bet: 0);
  List<Hand> hands = [];
  int active = 0;
  bool holeDown = true;
  bool _busy = false;
  bool _disposed = false;

  String message = 'Place your bet';
  String detail = '';
  int roundNet = 0;
  String? lastMistake;
  bool shoeJustShuffled = false;

  /// A table that just came within reach, announced once.
  String? unlockedTable;

  /// The table you were moved down to after a bad run.
  String? demotedTo;

  Hand? get current =>
      phase == Phase.playerTurn && active < hands.length ? hands[active] : null;

  bool get hasSplits => hands.length > 1;
  bool get canDeal =>
      phase == Phase.betting && bet >= tier.min && bet <= bankroll && bet <= tier.max;

  /// You cannot cover the cheapest bet at the table you are seated at. The
  /// table you are seated at is always one you can afford unless you are
  /// under the very bottom of the ladder, so this means: take a marker.
  bool get isBroke => phase == Phase.betting && bankroll < tier.min;

  bool get canHit {
    final h = current;
    return h != null && !h.isClosed && !(h.splitAce && !rules.hitSplitAces);
  }

  bool get canStand => current != null;

  bool get canDouble {
    final h = current;
    if (h == null || h.cards.length != 2 || bankroll < h.bet) return false;
    if (h.splitAce && !rules.hitSplitAces) return false;
    if (h.fromSplit && !rules.doubleAfterSplit) return false;
    return rules.doubleRule.allows(h.total, h.isSoft);
  }

  bool get canSplit {
    final h = current;
    if (h == null || !h.isPair || bankroll < h.bet) return false;
    if (hands.length >= rules.maxHands) return false;
    if (h.splitAce && !rules.resplitAces) return false;
    return true;
  }

  bool get canSurrender {
    final h = current;
    return rules.lateSurrender && h != null && h.cards.length == 2 && !h.fromSplit;
  }

  /// Whether the player's blackjack means the insurance offer is even money.
  bool get isEvenMoneyOffer => hands.length == 1 && hands.first.isBlackjack;

  StrategyCall? get hint {
    final h = current;
    if (h == null || !settings.coach || dealer.cards.isEmpty) return null;
    if (h.splitAce && !rules.hitSplitAces) return null;
    return BasicStrategy.recommend(
      hand: h,
      dealerUp: dealer.cards.first,
      rules: rules,
      canDouble: canDouble,
      canSplit: canSplit,
      canSurrender: canSurrender,
    );
  }

  // --- betting -------------------------------------------------------------

  void addChip(int denom) {
    if (phase != Phase.betting) return;
    if (bet + denom > bankroll || bet + denom > tier.max) return;
    bet += denom;
    _tick();
    _persistBet();
    _notify();
  }

  void clearBet() {
    if (phase != Phase.betting) return;
    bet = 0;
    _notify();
  }

  void rebet() {
    if (phase != Phase.betting) return;
    bet = _lastBet;
    _clampBet();
    _notify();
  }

  /// The house always has a marker for you, so you can never be left at the
  /// table with nothing and no way to bet again.
  void takeMarker() {
    bankroll += kMarkerAmount;
    stats.recordMarker(kMarkerAmount);
    prefs.setInt('bankroll', bankroll);
    _ensureAffordableTable();
    _clampBet();
    message = 'Marker for $kMarkerAmount';
    detail = 'Comped chips. They never count as winnings.';
    _notify();
  }

  /// Keeps you at a table you can actually play. Called whenever the bankroll
  /// moves, so a losing run walks you back down the ladder instead of
  /// stranding you at a table whose minimum you cannot meet.
  void _ensureAffordableTable() {
    if (tier.isCustom || bankroll >= tier.min) return;
    final best = bestSeatable(bankroll);
    if (best.id != tier.id) {
      demotedTo = best.name;
      settings.setTier(best.id);
    }
  }

  void _clampBet() {
    final ceiling = bankroll < tier.max ? bankroll : tier.max;
    bet = ceiling < tier.min ? 0 : bet.clamp(tier.min, ceiling);
    _persistBet();
  }

  // --- the round -----------------------------------------------------------

  Future<void> deal() async {
    if (_busy || !canDeal) return;
    _busy = true;

    shoeJustShuffled = false;
    if (_shoe.pastCut) {
      _shoe.shuffle();
      shoeJustShuffled = true;
    }

    _lastBet = bet;
    _persistBet();
    bankroll -= bet;
    insuranceBet = 0;
    roundNet = 0;
    lastMistake = null;
    dealer = Hand(bet: 0);
    hands = [Hand(bet: bet)];
    active = 0;
    holeDown = true;
    phase = Phase.dealing;
    message = '';
    detail = '';
    _notify();

    for (var i = 0; i < 2; i++) {
      await _pause(220);
      hands.first.cards.add(_shoe.draw());
      _tick();
      _notify();
      await _pause(220);
      dealer.cards.add(_shoe.draw());
      _tick();
      _notify();
    }

    final up = dealer.cards.first;
    if (up.isAce) {
      phase = Phase.insurance;
      message = isEvenMoneyOffer ? 'Take even money?' : 'Insurance?';
      detail = isEvenMoneyOffer
          ? 'Guarantees an even-money payout on your blackjack.'
          : 'Costs half your bet. Pays 2 to 1 if the dealer has blackjack.';
      _busy = false;
      _notify();
      return;
    }

    if (up.isTen) {
      await _pause(260);
      if (dealer.isBlackjack) {
        await _revealAndSettle();
        _busy = false;
        return;
      }
    }

    _busy = false;
    await _startPlayerTurn();
  }

  Future<void> answerInsurance(bool take) async {
    if (_busy || phase != Phase.insurance) return;
    _busy = true;

    if (take) {
      insuranceBet = bet ~/ 2;
      bankroll -= insuranceBet;
      _tick();
    }
    message = '';
    detail = '';
    _notify();
    await _pause(300);

    if (dealer.isBlackjack) {
      if (take) stats.recordInsurance(won: true);
      await _revealAndSettle();
      _busy = false;
      return;
    }

    if (take) {
      stats.recordInsurance(won: false);
      detail = 'Insurance lost.';
    }
    _busy = false;
    await _startPlayerTurn();
  }

  Future<void> _startPlayerTurn() async {
    phase = Phase.playerTurn;
    active = 0;
    _notify();

    if (hands.first.isBlackjack) {
      message = 'Blackjack';
      await _pause(500);
      await _finishRound();
      return;
    }
    _notify();
  }

  Future<void> hit() async {
    if (_busy || !canHit) return;
    _busy = true;
    _recordDecision(Move.hit);
    final h = hands[active];
    h.cards.add(_shoe.draw());
    _tick();
    _notify();
    await _pause(260);
    _busy = false;
    if (h.isClosed) await _advance();
  }

  Future<void> stand() async {
    if (_busy || !canStand) return;
    _busy = true;
    _recordDecision(Move.stand);
    hands[active].stood = true;
    _busy = false;
    await _advance();
  }

  Future<void> doubleDown() async {
    if (_busy || !canDouble) return;
    _busy = true;
    _recordDecision(Move.double);
    final h = hands[active];
    bankroll -= h.bet;
    h.bet *= 2;
    h.doubled = true;
    h.cards.add(_shoe.draw());
    h.stood = true;
    _tick();
    _notify();
    await _pause(420);
    _busy = false;
    await _advance();
  }

  Future<void> split() async {
    if (_busy || !canSplit) return;
    _busy = true;
    _recordDecision(Move.split);
    final h = hands[active];
    bankroll -= h.bet;
    final other = h.splitOff();
    hands.insert(active + 1, other);
    _tick();
    _notify();

    await _pause(240);
    h.cards.add(_shoe.draw());
    _notify();
    await _pause(240);
    other.cards.add(_shoe.draw());
    _notify();

    if (h.splitAce && !rules.hitSplitAces) {
      for (final s in hands.where((x) => x.splitAce)) {
        s.stood = true;
      }
    }
    _busy = false;
    if (hands[active].isClosed) await _advance();
  }

  Future<void> surrender() async {
    if (_busy || !canSurrender) return;
    _busy = true;
    _recordDecision(Move.surrender);
    hands[active].surrendered = true;
    _busy = false;
    await _advance();
  }

  Future<void> _advance() async {
    final next = hands.indexWhere((h) => !h.isClosed, active + 1);
    if (next != -1) {
      active = next;
      _notify();
      await _pause(320);
      // A fresh split hand always draws its second card before you act.
      if (hands[active].cards.length == 1) {
        hands[active].cards.add(_shoe.draw());
        _notify();
        await _pause(240);
        if (hands[active].isClosed) {
          await _advance();
          return;
        }
      }
      return;
    }
    await _finishRound();
  }

  Future<void> _finishRound() async {
    phase = Phase.dealerTurn;
    holeDown = false;
    _notify();
    await _pause(420);

    final live = hands.any((h) => !h.isBust && !h.surrendered);
    if (live && !hands.every((h) => h.isBlackjack)) {
      while (_dealerMustDraw()) {
        dealer.cards.add(_shoe.draw());
        _tick();
        _notify();
        await _pause(440);
      }
    }
    await _settle();
  }

  bool _dealerMustDraw() {
    final t = dealer.total;
    if (t < 17) return true;
    return t == 17 && dealer.isSoft && rules.dealerHitsSoft17;
  }

  Future<void> _revealAndSettle() async {
    phase = Phase.dealerTurn;
    holeDown = false;
    _notify();
    await _pause(520);
    await _settle();
  }

  Future<void> _settle() async {
    final dealerBj = dealer.isBlackjack;
    final dealerTotal = dealer.total;
    final dealerBust = dealerTotal > 21;

    var staked = insuranceBet;
    var returned = 0;

    if (insuranceBet > 0 && dealerBj) returned += insuranceBet * 3;

    for (final h in hands) {
      staked += h.bet;
      if (h.surrendered) {
        h.outcome = Outcome.surrender;
        returned += h.bet ~/ 2;
      } else if (h.isBust) {
        h.outcome = Outcome.bust;
      } else if (h.isBlackjack) {
        if (dealerBj) {
          h.outcome = Outcome.push;
          returned += h.bet;
        } else {
          h.outcome = Outcome.blackjack;
          returned += h.bet + (h.bet * rules.payout.multiplier).round();
        }
      } else if (dealerBj) {
        h.outcome = Outcome.lose;
      } else if (dealerBust) {
        h.outcome = Outcome.dealerBust;
        returned += h.bet * 2;
      } else if (h.total > dealerTotal) {
        h.outcome = Outcome.win;
        returned += h.bet * 2;
      } else if (h.total == dealerTotal) {
        h.outcome = Outcome.push;
        returned += h.bet;
      } else {
        h.outcome = Outcome.lose;
      }
      h.net = _handNet(h, dealerBj: dealerBj, dealerBust: dealerBust, dealerTotal: dealerTotal);
      stats.recordHand(h);
    }

    final bankrollBefore = bankroll;
    bankroll += returned;
    roundNet = returned - staked;
    prefs.setInt('bankroll', bankroll);

    // Crossing a table's seating minimum is the one bit of progress worth
    // interrupting for.
    for (final t in kTiers) {
      if (t.isCustom) continue;
      if (bankrollBefore < t.sitMin && bankroll >= t.sitMin) unlockedTable = t.name;
    }

    stats.recordRound(net: roundNet, wagered: staked, bankroll: bankroll);

    phase = Phase.settled;
    message = _headline();
    detail = _detailLine();
    if (settings.haptics) {
      if (roundNet > 0) {
        HapticFeedback.mediumImpact();
      } else if (roundNet < 0) {
        HapticFeedback.lightImpact();
      }
    }
    _notify();
  }

  int _handNet(Hand h, {required bool dealerBj, required bool dealerBust, required int dealerTotal}) {
    return switch (h.outcome) {
      Outcome.blackjack => (h.bet * rules.payout.multiplier).round(),
      Outcome.win || Outcome.dealerBust => h.bet,
      Outcome.push => 0,
      Outcome.surrender => -(h.bet - h.bet ~/ 2),
      _ => -h.bet,
    };
  }

  String _headline() {
    if (hands.length > 1) {
      if (roundNet > 0) return 'You win $roundNet';
      if (roundNet < 0) return 'You lose ${-roundNet}';
      return 'Even';
    }
    final h = hands.first;
    return switch (h.outcome!) {
      Outcome.blackjack => 'Blackjack',
      Outcome.win => 'You win',
      Outcome.dealerBust => 'Dealer busts',
      Outcome.push => 'Push',
      Outcome.bust => 'Bust',
      Outcome.surrender => 'Surrendered',
      Outcome.lose => 'Dealer wins',
    };
  }

  String _detailLine() {
    final parts = <String>[];
    if (insuranceBet > 0) {
      parts.add(dealer.isBlackjack ? 'Insurance paid' : 'Insurance lost');
    }
    if (roundNet != 0) parts.add(roundNet > 0 ? '+$roundNet' : '$roundNet');
    if (dealer.cards.isNotEmpty) parts.add('Dealer ${dealer.total > 21 ? 'bust' : dealer.total}');
    return parts.join('  ·  ');
  }

  void nextRound() {
    if (phase != Phase.settled) return;
    hands = [];
    dealer = Hand(bet: 0);
    holeDown = true;
    insuranceBet = 0;
    lastMistake = null;
    unlockedTable = null;
    demotedTo = null;
    phase = Phase.betting;
    message = _shoe.pastCut ? 'Shuffling for the next shoe' : 'Place your bet';
    detail = '';
    _ensureAffordableTable();
    _clampBet();
    _notify();
  }

  // --- trainer -------------------------------------------------------------

  void _recordDecision(Move played) {
    final h = current;
    if (h == null || dealer.cards.isEmpty) return;
    final call = BasicStrategy.recommend(
      hand: h,
      dealerUp: dealer.cards.first,
      rules: rules,
      canDouble: canDouble,
      canSplit: canSplit,
      canSurrender: canSurrender,
    );
    final correct = call.move == played;
    stats.recordDecision(call.key, correct, played.label);
    lastMistake = correct || !settings.flagMistakes
        ? null
        : '${call.key} — basic strategy says ${call.move.label.toLowerCase()}';
  }

  // --- plumbing ------------------------------------------------------------

  void _onSettingsChanged() {
    // A new shoe only appears between rounds, never under a live hand.
    final changed = _shoe.decks != rules.decks || _shoe.penetration != rules.penetration;
    if (changed && (phase == Phase.betting || phase == Phase.settled)) {
      _shoe = Shoe(decks: rules.decks, penetration: rules.penetration);
    }
    if (phase == Phase.betting) _clampBet();
    _notify();
  }

  /// Drops a restored save onto a clean table.
  void applyImported(int restoredBankroll) {
    bankroll = restoredBankroll;
    prefs.setInt('bankroll', bankroll);
    hands = [];
    dealer = Hand(bet: 0);
    holeDown = true;
    insuranceBet = 0;
    lastMistake = null;
    unlockedTable = null;
    demotedTo = null;
    phase = Phase.betting;
    message = 'Save restored';
    detail = '';
    _shoe = Shoe(decks: rules.decks, penetration: rules.penetration);
    _ensureAffordableTable();
    _clampBet();
    _notify();
  }

  void _persistBet() => prefs.setInt('bet', bet);

  void _tick() {
    if (settings.haptics) HapticFeedback.selectionClick();
  }

  Future<void> _pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: settings.fastDeal ? (ms * 0.45).round() : ms));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

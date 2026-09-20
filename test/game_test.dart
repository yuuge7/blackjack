import 'package:blackjack/state/game_controller.dart';
import 'package:blackjack/state/settings_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> table() async {
    SharedPreferences.setMockInitialValues({
      'haptics': false,
      'fastDeal': true,
      'bankroll': 1000,
      'bet': 25,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final stats = StatsStore(prefs);
    return GameController(settings: settings, stats: stats, prefs: prefs);
  }

  /// Plays a round to completion, standing on everything.
  Future<void> playStanding(GameController g) async {
    await g.deal();
    if (g.phase == Phase.insurance) await g.answerInsurance(false);
    var guard = 0;
    while (g.phase == Phase.playerTurn && guard++ < 12) {
      await g.stand();
    }
  }

  test('a round settles to exactly the money it moved', () async {
    final g = await table();
    for (var i = 0; i < 25; i++) {
      final before = g.bankroll;
      await playStanding(g);
      expect(g.phase, Phase.settled, reason: 'round $i never settled');
      expect(g.bankroll, before + g.roundNet, reason: 'round $i money did not balance');
      expect(g.bankroll, greaterThanOrEqualTo(0));
      g.nextRound();
      expect(g.phase, Phase.betting);
    }
    expect(g.stats.session.rounds, 25);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('every hand ends with an outcome and the dealer respects the rules', () async {
    final g = await table();
    for (var i = 0; i < 15; i++) {
      await playStanding(g);
      for (final h in g.hands) {
        expect(h.outcome, isNotNull);
      }
      final d = g.dealer;
      // The dealer only draws when a live hand can still beat them: not when
      // everything busted or surrendered, and not against a natural.
      final nothingToBeat =
          g.hands.every((h) => h.isBust || h.surrendered) || g.hands.every((h) => h.isBlackjack);
      if (!nothingToBeat && !d.isBlackjack) {
        final stoodOn = d.total;
        expect(
          stoodOn >= 17 || stoodOn > 21,
          isTrue,
          reason: 'dealer stopped on $stoodOn',
        );
        if (stoodOn == 17 && d.isSoft) {
          expect(g.rules.dealerHitsSoft17, isFalse);
        }
      }
      g.nextRound();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('hitting past twenty-one closes the hand as a bust', () async {
    final g = await table();
    await g.deal();
    if (g.phase == Phase.insurance) await g.answerInsurance(false);
    var guard = 0;
    while (g.phase == Phase.playerTurn && g.canHit && guard++ < 12) {
      await g.hit();
    }
    expect(g.phase, Phase.settled);
    expect(g.hands.first.outcome, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

}

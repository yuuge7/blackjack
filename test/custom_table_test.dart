import 'package:blackjack/model/table_tier.dart';
import 'package:blackjack/state/game_controller.dart';
import 'package:blackjack/state/settings_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SettingsStore, GameController)> table({
    int bankroll = 100000,
    Map<String, Object> seed = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'haptics': false,
      'fastDeal': true,
      'tier': 'custom',
      'bankroll': bankroll,
      ...seed,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final stats = StatsStore(prefs);
    return (settings, GameController(settings: settings, stats: stats, prefs: prefs));
  }

  group('chipsForLimits', () {
    test('the default table keeps the rack it always had', () {
      expect(chipsForLimits(5, 500), [5, 25, 100, 500]);
    });

    test('the rack starts at the largest chip the minimum can cover', () {
      expect(chipsForLimits(25, 5000), [25, 100, 500, 1000]);
      expect(chipsForLimits(1000, 1000000), [1000, 5000, 25000, 100000]);
    });

    test('a tight range still gets a usable rack', () {
      expect(chipsForLimits(1, 3), isNotEmpty);
      expect(chipsForLimits(1, 10), [1, 5]);
      expect(chipsForLimits(7, 13), isNotEmpty);
    });

    test('never more than four, never empty', () {
      for (final min in [1, 5, 37, 250, 9999, 100000, 7500000]) {
        for (final max in [min, min * 3, min * 1000, kMaxStake]) {
          final rack = chipsForLimits(min, max);
          expect(rack, isNotEmpty, reason: '$min..$max');
          expect(rack.length, lessThanOrEqualTo(4), reason: '$min..$max');
          expect(rack, orderedEquals(rack.toList()..sort()), reason: '$min..$max');
        }
      }
    });
  });

  group('custom limits', () {
    test('default to the old fixed values', () async {
      final (settings, _) = await table();
      expect(settings.customMin, 5);
      expect(settings.customMax, 500);
      expect(settings.tier.min, 5);
      expect(settings.tier.max, 500);
    });

    test('any amount can be set, and it sticks', () async {
      SharedPreferences.setMockInitialValues({'tier': 'custom'});
      final prefs = await SharedPreferences.getInstance();
      SettingsStore(prefs).setCustomLimits(min: 137, max: 2500000);

      final reloaded = SettingsStore(prefs);
      expect(reloaded.customMin, 137);
      expect(reloaded.customMax, 2500000);
      expect(reloaded.tier.min, 137);
      expect(reloaded.tier.max, 2500000);
    });

    test('a maximum can never end up under its own minimum', () async {
      final (settings, _) = await table();

      settings.setCustomLimits(min: 10000);
      expect(settings.customMin, 10000);
      // The maximum was 500; raising the minimum past it drags it up.
      expect(settings.customMax, greaterThanOrEqualTo(10000));

      settings.setCustomLimits(max: 1);
      expect(settings.customMax, greaterThanOrEqualTo(settings.customMin));
    });

    test('limits are clamped to the stake bounds', () async {
      final (settings, _) = await table();

      settings.setCustomLimits(min: 0, max: -5);
      expect(settings.customMin, kMinStake);

      settings.setCustomLimits(min: kMaxStake * 10, max: kMaxStake * 10);
      expect(settings.customMin, kMaxStake);
      expect(settings.customMax, kMaxStake);
    });

    test('only the house table is affected', () async {
      final (settings, _) = await table(seed: {'tier': 'quarter'});
      settings.setCustomLimits(min: 99999, max: 99999);
      expect(settings.tier.id, 'quarter');
      expect(settings.tier.min, 25);
      expect(settings.tier.max, 500);
      // The custom table still carries the new numbers when you sit at it.
      expect(settings.customTier.min, 99999);
    });

    test('the rack follows the limits', () async {
      final (settings, game) = await table();
      settings.setCustomLimits(min: 1000, max: 500000);
      expect(game.chips.first, 1000);
      expect(game.chips.every((c) => c >= 1000), isTrue);
    });
  });

  group('betting any amount', () {
    test('setBet takes an exact figure the rack cannot stack', () async {
      final (settings, game) = await table();
      settings.setCustomLimits(min: 1, max: 1000000);

      game.setBet(13337);
      expect(game.bet, 13337);
      expect(game.canDeal, isTrue);
    });

    test('a bet is clamped to the table maximum', () async {
      final (settings, game) = await table();
      settings.setCustomLimits(min: 5, max: 250);

      game.setBet(999999);
      expect(game.bet, 250);
    });

    test('a bet is clamped to what you can actually cover', () async {
      final (settings, game) = await table(bankroll: 400);
      settings.setCustomLimits(min: 1, max: 1000000);

      game.setBet(999999);
      expect(game.bet, 400);
      expect(game.maxBet, 400);
    });

    test('zero and negatives clear the bet rather than going below it', () async {
      final (_, game) = await table();
      game.setBet(100);
      game.setBet(0);
      expect(game.bet, 0);
      game.setBet(-50);
      expect(game.bet, 0);
    });

    test('a bet cannot be set mid-hand', () async {
      final (settings, game) = await table();
      settings.setCustomLimits(min: 5, max: 10000);
      game.setBet(100);
      await game.deal();

      final during = game.bet;
      game.setBet(9999);
      expect(game.bet, during);
    });

    test('raising the minimum re-clamps a bet that is now too small', () async {
      final (settings, game) = await table();
      settings.setCustomLimits(min: 5, max: 1000000);
      game.setBet(10);

      settings.setCustomLimits(min: 5000);
      expect(game.bet, greaterThanOrEqualTo(5000));
    });
  });

  group('never dead-ended at your own table', () {
    test('a marker covers a minimum far above the bankroll', () async {
      final (settings, game) = await table(bankroll: 100);
      settings.setCustomLimits(min: 50000, max: 100000);

      expect(game.isBroke, isTrue);
      expect(game.markerAmount, greaterThan(kMarkerAmount));

      game.takeMarker();
      expect(game.bankroll, greaterThanOrEqualTo(settings.customMin));
      expect(game.isBroke, isFalse);
      expect(game.canDeal, isTrue);
    });

    test('preset tables still comp the flat amount', () async {
      final (_, game) = await table(bankroll: 1, seed: {'tier': 'nickel'});
      expect(game.markerAmount, kMarkerAmount);
    });
  });
}

import 'package:blackjack/model/table_tier.dart';
import 'package:blackjack/state/game_controller.dart';
import 'package:blackjack/state/save_data.dart';
import 'package:blackjack/state/settings_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(GameController, SettingsStore, StatsStore)> seat({int bankroll = 500}) async {
  SharedPreferences.setMockInitialValues({
    'haptics': false,
    'fastDeal': true,
    'bankroll': bankroll,
    'bet': 25,
  });
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final stats = StatsStore(prefs);
  final game = GameController(settings: settings, stats: stats, prefs: prefs);
  return (game, settings, stats);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the table ladder', () {
    test('climbing always improves the conditions', () {
      final ladder = kTiers.where((t) => !t.isCustom).toList();
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i].rules.houseEdge,
          lessThan(ladder[i - 1].rules.houseEdge),
          reason: '${ladder[i].name} should beat ${ladder[i - 1].name}',
        );
        expect(ladder[i].min, greaterThan(ladder[i - 1].min));
        expect(ladder[i].sitMin, greaterThan(ladder[i - 1].sitMin));
      }
    });

    test('you can always afford to sit at the bottom table', () {
      expect(kTiers.first.sitMin, 0);
      expect(bestSeatable(0).id, kTiers.first.id);
      expect(bestSeatable(1 << 30).id, 'salon');
    });

    test('the seating requirement covers several buy-ins', () {
      for (final t in kTiers.where((t) => !t.isCustom && t.sitMin > 0)) {
        expect(t.sitMin, greaterThanOrEqualTo(t.min * 4));
      }
    });
  });

  group('never stranded', () {
    test('a marker always puts you back in action', () async {
      final (game, _, _) = await seat();
      game.bankroll = 0;
      expect(game.isBroke, isTrue);
      expect(game.canDeal, isFalse);

      game.takeMarker();

      expect(game.bankroll, kMarkerAmount);
      expect(game.isBroke, isFalse);
      expect(game.canDeal, isTrue);
      expect(game.stats.lifetime.markers, 1);
      expect(game.stats.lifetime.marked, kMarkerAmount);
    });

    test('markers are never counted as winnings', () async {
      final (game, _, stats) = await seat();
      game.bankroll = 0;
      game.takeMarker();
      expect(stats.lifetime.net, 0);
      expect(stats.lifetime.wagered, 0);
    });

    test('a bust at a high table walks you back down to one you can play',
        () async {
      final (game, settings, _) = await seat(bankroll: 80000);
      settings.setTier('salon');
      expect(game.tier.id, 'salon');

      game.bankroll = 40;
      game.takeMarker();

      expect(game.tier.id, 'nickel');
      expect(game.canDeal, isTrue);
    });

    test('the bet is clamped into the new table limits', () async {
      final (game, settings, _) = await seat(bankroll: 60000);
      settings.setTier('salon');
      expect(game.bet, greaterThanOrEqualTo(game.tier.min));

      settings.setTier('nickel');
      expect(game.bet, lessThanOrEqualTo(game.tier.max));
      expect(game.bet, greaterThanOrEqualTo(game.tier.min));
    });

    test('chips on offer never exceed the table maximum', () async {
      final (game, settings, _) = await seat(bankroll: 100000);
      for (final t in kTiers) {
        settings.setTier(t.id);
        for (final denom in game.chips) {
          expect(denom, lessThanOrEqualTo(t.max));
        }
        expect(game.chips.first, lessThanOrEqualTo(t.min));
      }
    });
  });

  group('save codes', () {
    test('a save survives the round trip', () async {
      final (game, settings, stats) = await seat(bankroll: 1234);
      settings.setTier('quarter');
      stats.recordRound(net: -50, wagered: 100, bankroll: 1234);
      stats.recordDecision('Hard 16 v 10', false, 'Hit');

      final code = SaveCode.encode(game: game, settings: settings, stats: stats);
      expect(code.startsWith(SaveCode.prefix), isTrue);

      final restored = SaveCode.decode(code);
      expect(restored.bankroll, 1234);
      expect(restored.stats.rounds, 1);
      expect(restored.stats.net, -50);
      expect(restored.stats.leaks['Hard 16 v 10']!.wrong, 1);
      expect(restored.payload['settings']['tier'], 'quarter');
    });

    test('restoring replaces the live state', () async {
      final (game, settings, stats) = await seat(bankroll: 9000);
      settings.setTier('black');
      stats.recordRound(net: 500, wagered: 1000, bankroll: 9000);
      final code = SaveCode.encode(game: game, settings: settings, stats: stats);

      final (other, otherSettings, otherStats) = await seat(bankroll: 20);
      SaveCode.apply(
        SaveCode.decode(code),
        game: other,
        settings: otherSettings,
        stats: otherStats,
      );

      expect(other.bankroll, 9000);
      expect(otherSettings.tier.id, 'black');
      expect(otherStats.lifetime.rounds, 1);
      expect(other.phase, Phase.betting);
      expect(other.hands, isEmpty);
    });

    test('a damaged or foreign code is refused with a readable reason', () {
      expect(
        () => SaveCode.decode(''),
        throwsA(isA<SaveCodeError>().having((e) => e.message, 'message', contains('Paste'))),
      );
      expect(
        () => SaveCode.decode('hello world'),
        throwsA(isA<SaveCodeError>()
            .having((e) => e.message, 'message', contains('not a blackjack save'))),
      );
      expect(
        () => SaveCode.decode('${SaveCode.prefix}not-real-base64!!!'),
        throwsA(isA<SaveCodeError>().having((e) => e.message, 'message', contains('damaged'))),
      );
    });
  });
}

import 'dart:io';

import 'package:blackjack/model/day_stats.dart';
import 'package:blackjack/state/day_stats_store.dart';
import 'package:blackjack/state/game_controller.dart';
import 'package:blackjack/state/save_file.dart';
import 'package:blackjack/state/settings_store.dart';
import 'package:blackjack/state/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything a save file touches, wired together the way the app wires it.
class Rig {
  Rig({
    required this.prefs,
    required this.settings,
    required this.days,
    required this.stats,
    required this.game,
  });

  final SharedPreferences prefs;
  final SettingsStore settings;
  final DayStatsStore days;
  final StatsStore stats;
  final GameController game;

  static Future<Rig> build({Map<String, Object> seed = const {}}) async {
    SharedPreferences.setMockInitialValues({'haptics': false, ...seed});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final days = DayStatsStore(prefs);
    final stats = StatsStore(prefs, days: days);
    final game = GameController(settings: settings, stats: stats, prefs: prefs);
    return Rig(prefs: prefs, settings: settings, days: days, stats: stats, game: game);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('bj-save-test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File scratch(String name) => File('${tmp.path}${Platform.pathSeparator}$name');

  test('a save survives the round trip to a file and back', () async {
    final source = await Rig.build(seed: {'bankroll': 4200, 'bet': 50});
    source.days.now = () => DateTime(2026, 9, 20);
    source.stats.recordRound(net: 175, wagered: 50, bankroll: 4200);
    source.stats.recordDecision('16 v 10', true, 'Hit');
    source.settings.setCoach(false);
    source.settings.setShowCount(true);

    final file = scratch('save.bjsave');
    final bytes = await SaveFile.write(
      file,
      game: source.game,
      settings: source.settings,
      stats: source.stats,
      days: source.days,
    );
    expect(bytes, greaterThan(0));
    expect(file.existsSync(), isTrue);

    final summary = await SaveFile.inspect(file);
    expect(summary.version, SaveFile.version);
    expect(summary.bankroll, 4200);
    expect(summary.bet, 50);
    expect(summary.stats.rounds, 1);
    expect(summary.dayCount, 1);
    expect(summary.dayNet, 175);
    expect(summary.firstYear, 2026);
    expect(summary.savedAt, isNotNull);

    final target = await Rig.build();
    await SaveFile.restore(
      file,
      game: target.game,
      settings: target.settings,
      stats: target.stats,
      days: target.days,
      mergeCalendar: false,
    );

    expect(target.game.bankroll, 4200);
    expect(target.game.bet, 50);
    expect(target.stats.lifetime.rounds, 1);
    expect(target.settings.coach, isFalse);
    expect(target.settings.showCount, isTrue);
    expect(target.days.day(DateTime(2026, 9, 20))!.net, 175);
  });

  test('restoring without merge drops whatever calendar was already here',
      () async {
    final source = await Rig.build();
    source.days.now = () => DateTime(2026, 1, 1);
    source.stats.recordRound(net: 10, wagered: 10, bankroll: 510);

    final file = scratch('save.bjsave');
    await SaveFile.write(
      file,
      game: source.game,
      settings: source.settings,
      stats: source.stats,
      days: source.days,
    );

    final target = await Rig.build();
    target.days.now = () => DateTime(2024, 6, 6);
    target.stats.recordRound(net: -99, wagered: 99, bankroll: 401);

    await SaveFile.restore(
      file,
      game: target.game,
      settings: target.settings,
      stats: target.stats,
      days: target.days,
      mergeCalendar: false,
    );

    expect(target.days.day(DateTime(2024, 6, 6)), isNull);
    expect(target.days.day(DateTime(2026, 1, 1))!.net, 10);
  });

  test('merging keeps both devices\' days and folds a shared one together',
      () async {
    final source = await Rig.build();
    source.days.now = () => DateTime(2026, 1, 1);
    source.stats.recordRound(net: 10, wagered: 10, bankroll: 510);

    final file = scratch('save.bjsave');
    await SaveFile.write(
      file,
      game: source.game,
      settings: source.settings,
      stats: source.stats,
      days: source.days,
    );

    final target = await Rig.build();
    target.days.now = () => DateTime(2024, 6, 6);
    target.stats.recordRound(net: -99, wagered: 99, bankroll: 401);
    target.days.now = () => DateTime(2026, 1, 1);
    target.stats.recordRound(net: 5, wagered: 5, bankroll: 406);

    await SaveFile.restore(
      file,
      game: target.game,
      settings: target.settings,
      stats: target.stats,
      days: target.days,
      mergeCalendar: true,
    );

    expect(target.days.day(DateTime(2024, 6, 6))!.net, -99);
    final shared = target.days.day(DateTime(2026, 1, 1))!;
    expect(shared.rounds, 2);
    expect(shared.net, 15);
    // Two devices on one date is not two sessions on one device.
    expect(shared.sessions, 1);
  });

  test('a decade of daily play round trips, and stays small', () async {
    final source = await Rig.build();

    // Ten years, every day, a handful of rounds each: about 3,650 days.
    var written = 0;
    for (var y = 2016; y <= 2025; y++) {
      final year = <String, List<int>>{};
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= daysInMonth(y, m); d++) {
          final day = DayStats()
            ..recordRound(roundNet: (d % 7) * 25 - 75, roundWagered: 50)
            ..recordRound(roundNet: (m % 5) * 20 - 40, roundWagered: 50)
            ..recordDecision(wasCorrect: d.isEven)
            ..sessions = 1;
          year[dayKey(m, d).toString().padLeft(4, '0')] = day.toList();
          written++;
        }
      }
      source.days.importYear(y, year, replace: true);
    }
    source.days.flush();
    expect(written, greaterThan(3600));

    final file = scratch('decade.bjsave');
    final bytes = await SaveFile.write(
      file,
      game: source.game,
      settings: source.settings,
      stats: source.stats,
      days: source.days,
    );

    // Gzipped, ten years of daily play is a rounding error of a file. The
    // point of the assertion is that the format has not quietly become one
    // that a phone would choke on.
    expect(bytes, lessThan(256 * 1024));

    final summary = await SaveFile.inspect(file);
    expect(summary.dayCount, written);
    expect(summary.firstYear, 2016);
    expect(summary.lastYear, 2025);
    expect(summary.dayRounds, written * 2);

    final target = await Rig.build();
    await SaveFile.restore(
      file,
      game: target.game,
      settings: target.settings,
      stats: target.stats,
      days: target.days,
      mergeCalendar: false,
    );

    expect(target.days.years, [for (var y = 2016; y <= 2025; y++) y]);
    expect(target.days.yearTotals(2020).daysPlayed, 366);
    expect(target.days.yearTotals(2021).daysPlayed, 365);
    expect(
      target.days.day(DateTime(2019, 3, 14))!.net,
      source.days.day(DateTime(2019, 3, 14))!.net,
    );
  });

  group('rejecting bad files', () {
    test('a file that is not gzip at all', () async {
      final file = scratch('nope.bjsave')..writeAsStringSync('just some text');
      expect(
        () => SaveFile.inspect(file),
        throwsA(isA<SaveFileError>()),
      );
    });

    test('gzipped JSON that is not ours', () async {
      final file = scratch('other.bjsave');
      await Stream<List<int>>.value(
        '{"t":"bj","v":1,"app":"some-other-app"}\n'.codeUnits,
      ).transform(GZipCodec().encoder).pipe(file.openWrite());

      expect(() => SaveFile.inspect(file), throwsA(isA<SaveFileError>()));
    });

    test('a save from a future version is refused rather than half-read',
        () async {
      final file = scratch('future.bjsave');
      await Stream<List<int>>.value(
        '{"t":"bj","v":${SaveFile.version + 1},"app":"${SaveFile.magic}"}\n'.codeUnits,
      ).transform(GZipCodec().encoder).pipe(file.openWrite());

      await expectLater(
        SaveFile.inspect(file),
        throwsA(
          isA<SaveFileError>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a truncated file is reported, not applied', () async {
      final source = await Rig.build();
      source.days.now = () => DateTime(2026, 9, 20);
      source.stats.recordRound(net: 10, wagered: 10, bankroll: 510);

      final whole = scratch('whole.bjsave');
      await SaveFile.write(
        whole,
        game: source.game,
        settings: source.settings,
        stats: source.stats,
        days: source.days,
      );

      final bytes = whole.readAsBytesSync();
      final cut = scratch('cut.bjsave')
        ..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));

      expect(() => SaveFile.inspect(cut), throwsA(isA<SaveFileError>()));
    });
  });

  test('the suggested name carries the date and our extension', () {
    expect(
      SaveFile.suggestedName(DateTime(2026, 9, 20)),
      'blackjack-2026-09-20.bjsave',
    );
  });
}

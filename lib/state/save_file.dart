import 'dart:convert';
import 'dart:io';

import '../model/day_stats.dart';
import '../model/stats.dart';
import 'day_stats_store.dart';
import 'game_controller.dart';
import 'settings_store.dart';
import 'stats_store.dart';

/// A whole save as a file: gzipped newline-delimited JSON.
///
/// One JSON object per line, one line per year of calendar history. Nothing
/// ever holds the entire save in memory — not on write, not on read, not on
/// restore — so a player with a decade of daily play exports and imports in
/// the same fixed footprint as one with a week of it.
///
/// ```text
/// {"t":"bj","v":2,"app":"blackjack-save","saved":"2026-09-20T…"}
/// {"t":"core","bankroll":4200,"bet":25}
/// {"t":"settings","d":{…}}
/// {"t":"stats","d":{…}}
/// {"t":"days","y":2025,"d":{"0101":[…],"0102":[…]}}
/// {"t":"days","y":2026,"d":{…}}
/// ```
class SaveFile {
  const SaveFile._();

  static const String extension = 'bjsave';
  static const String mimeType = 'application/gzip';
  static const String magic = 'blackjack-save';

  /// Bumped only when a reader written today could not make sense of the file.
  static const int version = 2;

  /// Level 6 rather than 9: a year of play compresses to within a few percent
  /// of best either way, and 6 keeps the export instant on a phone.
  static final GZipCodec _gzip = GZipCodec(level: 6);

  static String suggestedName([DateTime? at]) =>
      'blackjack-${isoDay(at ?? DateTime.now())}.$extension';

  // --- writing -------------------------------------------------------------

  /// Streams the current save into [target] and returns its size in bytes.
  static Future<int> write(
    File target, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
  }) async {
    // Both stores debounce their writes; an export has to see the last round.
    stats.flush();
    days.flush();

    await target.parent.create(recursive: true);
    await _lines(game: game, settings: settings, stats: stats, days: days)
        .transform(_gzip.encoder)
        .pipe(target.openWrite());
    return target.length();
  }

  static Stream<List<int>> _lines({
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
  }) async* {
    List<int> line(Map<String, dynamic> record) => utf8.encode('${jsonEncode(record)}\n');

    yield line({
      't': 'bj',
      'v': version,
      'app': magic,
      'saved': DateTime.now().toIso8601String(),
    });
    yield line({'t': 'core', 'bankroll': game.bankroll, 'bet': game.bet});
    yield line({'t': 'settings', 'd': settings.toJson()});
    yield line({'t': 'stats', 'd': stats.lifetime.toJson()});

    for (final y in days.years) {
      final d = days.exportYear(y);
      if (d.isNotEmpty) yield line({'t': 'days', 'y': y, 'd': d});
    }
  }

  // --- reading -------------------------------------------------------------

  static Stream<Map<String, dynamic>> _records(File source) {
    return source
        .openRead()
        .transform(_gzip.decoder)
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .where((l) => l.trim().isNotEmpty)
        .map((l) {
      final decoded = jsonDecode(l);
      if (decoded is! Map<String, dynamic>) {
        throw const SaveFileError('This save file is damaged.');
      }
      return decoded;
    });
  }

  /// Reads a file without applying it, so the UI can say what is inside before
  /// anything is overwritten. Day records are counted as they stream past and
  /// then dropped — the summary is a handful of integers however big the file.
  static Future<SaveSummary> inspect(File source) async {
    var seenHeader = false;
    DateTime? savedAt;
    var fileVersion = 0;
    var bankroll = kOpeningStake;
    var bet = 25;
    var stats = StatsData();
    var dayCount = 0;
    var dayRounds = 0;
    var dayNet = 0;
    int? firstYear;
    int? lastYear;

    Stream<Map<String, dynamic>> records;
    try {
      records = _records(source);
    } on FormatException {
      throw const SaveFileError('This is not a blackjack save file.');
    }

    try {
      await for (final r in records) {
        switch (r['t']) {
          case 'bj':
            seenHeader = true;
            fileVersion = (r['v'] as num?)?.toInt() ?? 0;
            if (r['app'] != magic) {
              throw const SaveFileError('This is not a blackjack save file.');
            }
            if (fileVersion > version) {
              throw const SaveFileError(
                'This save came from a newer version of the app. Update, then import it.',
              );
            }
            savedAt = DateTime.tryParse(r['saved'] as String? ?? '');
          case 'core':
            bankroll = (r['bankroll'] as num?)?.toInt() ?? bankroll;
            bet = (r['bet'] as num?)?.toInt() ?? bet;
          case 'stats':
            final d = r['d'];
            if (d is Map<String, dynamic>) stats = StatsData.fromJson(d);
          case 'days':
            final y = (r['y'] as num?)?.toInt();
            final d = r['d'];
            if (y == null || d is! Map) break;
            if (firstYear == null || y < firstYear) firstYear = y;
            if (lastYear == null || y > lastYear) lastYear = y;
            for (final v in d.values) {
              if (v is! List) continue;
              final day = DayStats.fromList(v);
              if (day.isEmpty) continue;
              dayCount++;
              dayRounds += day.rounds;
              dayNet += day.net;
            }
        }
        if (!seenHeader) {
          throw const SaveFileError('This is not a blackjack save file.');
        }
      }
    } on SaveFileError {
      rethrow;
    } on FormatException {
      throw const SaveFileError('This save file is damaged. Try exporting it again.');
    } on FileSystemException {
      throw const SaveFileError('That file could not be read.');
    } on Exception {
      throw const SaveFileError('This save file is damaged. Try exporting it again.');
    }

    if (!seenHeader) {
      throw const SaveFileError('This is not a blackjack save file.');
    }

    return SaveSummary(
      version: fileVersion,
      savedAt: savedAt,
      bankroll: bankroll,
      bet: bet,
      stats: stats,
      dayCount: dayCount,
      dayRounds: dayRounds,
      dayNet: dayNet,
      firstYear: firstYear,
      lastYear: lastYear,
      bytes: await source.length(),
    );
  }

  /// Applies a file that [inspect] already vetted.
  ///
  /// [mergeCalendar] keeps whatever days are already on this device and folds
  /// the file's days in on top — the right thing when two devices have both
  /// been played on. Without it the calendar is replaced outright.
  ///
  /// The bankroll, settings and lifetime record are single-valued, so they are
  /// always replaced; there is no sensible way to average two of them.
  static Future<void> restore(
    File source, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required bool mergeCalendar,
  }) async {
    if (!mergeCalendar) days.clear();

    var bankroll = game.bankroll;
    var bet = game.bet;

    await for (final r in _records(source)) {
      switch (r['t']) {
        case 'core':
          bankroll = (r['bankroll'] as num?)?.toInt() ?? bankroll;
          bet = (r['bet'] as num?)?.toInt() ?? bet;
        case 'settings':
          final d = r['d'];
          if (d is Map<String, dynamic>) settings.applyImported(d);
        case 'stats':
          final d = r['d'];
          if (d is Map<String, dynamic>) stats.replaceLifetime(StatsData.fromJson(d));
        case 'days':
          final y = (r['y'] as num?)?.toInt();
          final d = r['d'];
          if (y != null && d is Map<String, dynamic>) {
            days.importYear(y, d, replace: false);
          }
      }
    }

    days.importFinished();
    game.bet = bet;
    game.applyImported(bankroll);
  }
}

/// What a save file holds, read without applying it.
class SaveSummary {
  const SaveSummary({
    required this.version,
    required this.savedAt,
    required this.bankroll,
    required this.bet,
    required this.stats,
    required this.dayCount,
    required this.dayRounds,
    required this.dayNet,
    required this.firstYear,
    required this.lastYear,
    required this.bytes,
  });

  final int version;
  final DateTime? savedAt;
  final int bankroll;
  final int bet;
  final StatsData stats;
  final int dayCount;
  final int dayRounds;
  final int dayNet;
  final int? firstYear;
  final int? lastYear;
  final int bytes;

  String get savedOn => savedAt == null ? 'an unknown date' : isoDay(savedAt!);

  String get calendarSpan {
    if (dayCount == 0) return 'No calendar history';
    final span = firstYear == lastYear ? '$firstYear' : '$firstYear–$lastYear';
    return '$dayCount day${dayCount == 1 ? '' : 's'} logged · $span';
  }

  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SaveFileError implements Exception {
  const SaveFileError(this.message);
  final String message;

  @override
  String toString() => message;
}

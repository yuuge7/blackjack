import 'dart:convert';
import 'dart:io';

import '../model/stats.dart';
import 'game_controller.dart';
import 'settings_store.dart';
import 'stats_store.dart';

/// A whole save as one pasteable string: JSON, gzipped, base64'd, with a
/// version tag on the front so a future format can refuse an old code politely
/// instead of crashing on it.
class SaveCode {
  const SaveCode._();

  static const int version = 1;
  static const String prefix = 'BJ1.';

  static String encode({
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
  }) {
    final payload = <String, dynamic>{
      'v': version,
      'saved': DateTime.now().toIso8601String(),
      'bankroll': game.bankroll,
      'bet': game.bet,
      'settings': settings.toJson(),
      'stats': stats.lifetime.toJson(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    final zipped = GZipCodec(level: 9).encode(bytes);
    return prefix + base64Url.encode(zipped);
  }

  /// Reads a code without applying it, so the UI can describe what is inside
  /// before overwriting anything.
  static SavePreview decode(String raw) {
    final code = raw.trim().replaceAll(RegExp(r'\s'), '');
    if (code.isEmpty) {
      throw const SaveCodeError('Paste a save code first.');
    }
    if (!code.startsWith(prefix)) {
      throw const SaveCodeError('That is not a blackjack save code.');
    }

    Map<String, dynamic> payload;
    try {
      final zipped = base64Url.decode(code.substring(prefix.length));
      final bytes = GZipCodec().decode(zipped);
      payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const SaveCodeError('This code is damaged. Copy it again in full.');
    }

    final v = (payload['v'] as num?)?.toInt() ?? 0;
    if (v > version) {
      throw const SaveCodeError('This save came from a newer version of the app.');
    }

    final statsJson = payload['stats'];
    final stats = statsJson is Map<String, dynamic>
        ? StatsData.fromJson(statsJson)
        : StatsData();

    return SavePreview(
      payload: payload,
      bankroll: (payload['bankroll'] as num?)?.toInt() ?? kOpeningStake,
      bet: (payload['bet'] as num?)?.toInt() ?? 25,
      stats: stats,
      savedAt: DateTime.tryParse(payload['saved'] as String? ?? ''),
    );
  }

  /// Replaces the current save. Destructive, so the caller confirms first.
  static void apply(
    SavePreview preview, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
  }) {
    final s = preview.payload['settings'];
    if (s is Map<String, dynamic>) settings.applyImported(s);
    stats.replaceLifetime(preview.stats);
    game.bet = preview.bet;
    game.applyImported(preview.bankroll);
  }
}

class SavePreview {
  const SavePreview({
    required this.payload,
    required this.bankroll,
    required this.bet,
    required this.stats,
    required this.savedAt,
  });

  final Map<String, dynamic> payload;
  final int bankroll;
  final int bet;
  final StatsData stats;
  final DateTime? savedAt;

  String get summary {
    final when = savedAt == null
        ? 'unknown date'
        : '${savedAt!.year}-${savedAt!.month.toString().padLeft(2, '0')}-'
            '${savedAt!.day.toString().padLeft(2, '0')}';
    return '$bankroll chips, ${stats.rounds} rounds, ${stats.decisions} decisions · saved $when';
  }
}

class SaveCodeError implements Exception {
  const SaveCodeError(this.message);
  final String message;

  @override
  String toString() => message;
}

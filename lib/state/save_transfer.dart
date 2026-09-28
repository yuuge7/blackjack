import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'day_stats_store.dart';
import 'game_controller.dart';
import 'profile_store.dart';
import 'save_file.dart';
import 'settings_store.dart';
import 'stats_store.dart';

/// Gets a [SaveFile] in and out of the device.
///
/// Two routes, because the platforms genuinely differ: on a phone the file is
/// written to the app's own cache and handed to the share sheet, which is the
/// only way to reach Drive, Files, a mail app or another phone. On a desktop
/// the user picks a folder and the file is streamed straight into it.
///
/// [download] is the third route, for keeping a copy on the device itself:
/// on Android it opens the system's save dialog instead of the share sheet.
///
/// Every route streams. None ever materialises the save as one buffer, so
/// the size of a player's history is not a limit on exporting it.
class SaveTransfer {
  const SaveTransfer._();

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Answered by `MainActivity.kt`. file_picker's own `saveFile` wants the
  /// whole file as bytes, which is exactly what the format exists to avoid.
  static const MethodChannel _channel = MethodChannel('dev.ionel.blackjack/save');

  // --- export --------------------------------------------------------------

  static Future<ExportOutcome> export({
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required ProfileStore profile,
  }) async {
    final name = SaveFile.suggestedName();

    if (!_isMobile) {
      return _toFolder(name,
          game: game, settings: settings, stats: stats, days: days, profile: profile);
    }

    final target = await _stage(name,
        game: game, settings: settings, stats: stats, days: days, profile: profile);
    final bytes = await target.length();

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(target.path, mimeType: SaveFile.mimeType, name: name)],
        fileNameOverrides: [name],
        subject: 'Blackjack save',
        title: 'Blackjack save',
      ),
    );

    if (result.status == ShareResultStatus.dismissed) {
      return const ExportOutcome.cancelled();
    }
    return ExportOutcome.saved(name: name, bytes: bytes, where: null);
  }

  /// Keeps a copy of the current save on this device — the safety net before
  /// an import overwrites it.
  ///
  /// On Android the share sheet is the wrong tool for this: plenty of phones
  /// offer no "save to device" target in it at all. The system save dialog
  /// always does, and the player picks the folder.
  static Future<ExportOutcome> download({
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required ProfileStore profile,
    String? name,
  }) async {
    final wanted = name ?? SaveFile.suggestedName();

    if (!Platform.isAndroid) {
      return _isMobile
          ? export(game: game, settings: settings, stats: stats, days: days, profile: profile)
          : _toFolder(wanted,
              game: game, settings: settings, stats: stats, days: days, profile: profile);
    }

    final staged = await _stage(wanted,
        game: game, settings: settings, stats: stats, days: days, profile: profile);
    try {
      final bytes = await staged.length();
      final String? landed;
      try {
        landed = await _channel.invokeMethod<String>(
          'saveAs',
          {'path': staged.path, 'name': wanted},
        );
      } on PlatformException catch (e) {
        throw SaveFileError(
          e.code == 'unavailable'
              ? 'This phone has no file manager to save into.'
              : 'The save could not be written there.',
        );
      }
      if (landed == null) return const ExportOutcome.cancelled();
      return ExportOutcome.saved(name: landed, bytes: bytes, where: null);
    } finally {
      await discard(staged);
    }
  }

  static Future<ExportOutcome> _toFolder(
    String name, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required ProfileStore profile,
  }) async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Where should the save go?',
    );
    if (folder == null) return const ExportOutcome.cancelled();
    final target = File('$folder${Platform.pathSeparator}$name');
    final bytes = await SaveFile.write(
      target,
      game: game,
      settings: settings,
      stats: stats,
      days: days,
      profile: profile,
    );
    return ExportOutcome.saved(name: name, bytes: bytes, where: folder);
  }

  /// Writes the save into the cache. Both phone routes hand another app a
  /// real file, and the cache directory is the one place this app can always
  /// write to.
  static Future<File> _stage(
    String name, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required ProfileStore profile,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File(
      '${dir.path}${Platform.pathSeparator}exports${Platform.pathSeparator}$name',
    );
    await SaveFile.write(
      target,
      game: game,
      settings: settings,
      stats: stats,
      days: days,
      profile: profile,
    );
    return target;
  }

  // --- import --------------------------------------------------------------

  /// Asks for a file, copies it somewhere this app can re-read, and reports
  /// what is inside it. Nothing is applied yet.
  ///
  /// The copy matters: a picked file can be a `content://` document owned by
  /// another app, readable once as a stream and not seekable. Staging it means
  /// the preview pass and the restore pass both have a real file to read.
  static Future<StagedSave?> pick() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Choose a blackjack save');
    if (picked == null) return null;

    final dir = await getTemporaryDirectory();
    final staging = Directory('${dir.path}${Platform.pathSeparator}imports');
    await staging.create(recursive: true);
    final staged = File(
      '${staging.path}${Platform.pathSeparator}'
      'pending-${DateTime.now().millisecondsSinceEpoch}.${SaveFile.extension}',
    );

    try {
      // An IOSink consumes List<int>; the picker hands back Uint8List.
      await picked.readAsByteStream().cast<List<int>>().pipe(staged.openWrite());
    } on FileSystemException {
      throw const SaveFileError('That file could not be read.');
    }

    try {
      final summary = await SaveFile.inspect(staged);
      return StagedSave(file: staged, name: picked.name, summary: summary);
    } catch (_) {
      await discard(staged);
      rethrow;
    }
  }

  static Future<void> restore(
    StagedSave staged, {
    required GameController game,
    required SettingsStore settings,
    required StatsStore stats,
    required DayStatsStore days,
    required ProfileStore profile,
    required bool mergeCalendar,
  }) async {
    await SaveFile.restore(
      staged.file,
      game: game,
      settings: settings,
      stats: stats,
      days: days,
      profile: profile,
      mergeCalendar: mergeCalendar,
    );
    await discard(staged.file);
  }

  /// Best-effort cleanup. A leftover file in the cache is harmless, so a
  /// failure here is never worth surfacing.
  static Future<void> discard(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Nothing to do; the OS clears the cache directory on its own.
    }
  }
}

/// A picked save, read and understood, waiting for the user to say yes.
class StagedSave {
  const StagedSave({required this.file, required this.name, required this.summary});

  final File file;
  final String name;
  final SaveSummary summary;
}

class ExportOutcome {
  const ExportOutcome.saved({required this.name, required this.bytes, required this.where})
      : cancelled = false;

  const ExportOutcome.cancelled()
      : cancelled = true,
        name = '',
        bytes = 0,
        where = null;

  final bool cancelled;
  final String name;
  final int bytes;

  /// The folder it landed in, when the platform let us know. On a phone the
  /// share sheet picks the destination and never tells us which.
  final String? where;

  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

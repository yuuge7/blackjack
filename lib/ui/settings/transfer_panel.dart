import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../state/day_stats_store.dart';
import '../../state/game_controller.dart';
import '../../state/profile_store.dart';
import '../../state/save_data.dart';
import '../../state/save_file.dart';
import '../../state/save_transfer.dart';
import '../../state/settings_store.dart';
import '../../state/stats_store.dart';
import '../common/table_button.dart';
import '../stats/stat_tile.dart';

/// Move a save off this device and back onto another one.
///
/// A file is the main route: it carries the whole calendar, however many years
/// of it there are, and nothing about it is capped by what a clipboard will
/// hold. The short code is still there underneath for the quick case of moving
/// a bankroll and a lifetime record between two phones in front of you.
class TransferPanel extends StatefulWidget {
  const TransferPanel({super.key});

  @override
  State<TransferPanel> createState() => _TransferPanelState();
}

class _TransferPanelState extends State<TransferPanel> {
  bool _busyIo = false;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final settings = context.read<SettingsStore>();
    final stats = context.read<StatsStore>();
    final days = context.read<DayStatsStore>();
    final profile = context.read<ProfileStore>();
    final midHand = game.phase != Phase.betting;
    final blocked = midHand || _busyIo;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('YOUR SAVE', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          Text(
            midHand
                ? 'Finish the hand you are playing, then you can export or restore.'
                : 'A save file holds your bankroll, table, rules, lifetime record '
                    'and every day on your calendar. It is written straight to '
                    'disk, so the size of your history is not a limit.',
            style: AppText.ui(11.5, color: AppColor.boneMid, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TableButton(
                  label: _busyIo ? 'Working…' : 'Export file',
                  tone: ButtonTone.primary,
                  height: 44,
                  fontSize: 12.5,
                  enabled: !blocked,
                  onTap: () => _exportFile(game, settings, stats, days, profile),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TableButton(
                  label: 'Import file',
                  height: 44,
                  fontSize: 12.5,
                  enabled: !blocked,
                  onTap: () => _importFile(game, settings, stats, days, profile),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: AppColor.line),
          const SizedBox(height: 14),
          Text('SHORT CODE', style: AppText.eyebrow(8)),
          const SizedBox(height: 5),
          Text(
            'The same save minus the calendar, small enough to paste into a '
            'message. Good for hopping between two devices in one sitting.',
            style: AppText.ui(11, color: AppColor.slate, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TableButton(
                  label: 'Copy code',
                  tone: ButtonTone.quiet,
                  height: 38,
                  fontSize: 11.5,
                  enabled: !blocked,
                  onTap: () => _copyCode(game, settings, stats),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TableButton(
                  label: 'Paste code',
                  tone: ButtonTone.quiet,
                  height: 38,
                  fontSize: 11.5,
                  enabled: !blocked,
                  onTap: () => _pasteCode(game, settings, stats),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toast(String text, {Color colour = AppColor.bone}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColor.railHi,
        content: Text(text, style: AppText.ui(12.5, color: colour)),
      ),
    );
  }

  // --- file route ----------------------------------------------------------

  Future<void> _exportFile(
    GameController game,
    SettingsStore settings,
    StatsStore stats,
    DayStatsStore days,
    ProfileStore profile,
  ) async {
    setState(() => _busyIo = true);
    try {
      final outcome = await SaveTransfer.export(
        game: game,
        settings: settings,
        stats: stats,
        days: days,
        profile: profile,
      );
      if (outcome.cancelled) return;
      _toast(
        outcome.where == null
            ? 'Exported ${outcome.name} · ${outcome.sizeLabel}'
            : 'Saved to ${outcome.where} · ${outcome.sizeLabel}',
      );
    } on SaveFileError catch (e) {
      _toast(e.message, colour: AppColor.clay);
    } catch (_) {
      _toast('The save could not be written.', colour: AppColor.clay);
    } finally {
      if (mounted) setState(() => _busyIo = false);
    }
  }

  Future<void> _importFile(
    GameController game,
    SettingsStore settings,
    StatsStore stats,
    DayStatsStore days,
    ProfileStore profile,
  ) async {
    setState(() => _busyIo = true);
    StagedSave? staged;
    try {
      staged = await SaveTransfer.pick();
    } on SaveFileError catch (e) {
      _toast(e.message, colour: AppColor.clay);
    } catch (_) {
      _toast('That file could not be read.', colour: AppColor.clay);
    } finally {
      if (mounted) setState(() => _busyIo = false);
    }

    if (staged == null || !mounted) return;

    final choice = await showDialog<_RestoreChoice>(
      context: context,
      builder: (ctx) => _RestoreDialog(staged: staged!),
    );

    if (choice == null || choice == _RestoreChoice.cancel) {
      await SaveTransfer.discard(staged.file);
      return;
    }

    setState(() => _busyIo = true);
    try {
      await SaveTransfer.restore(
        staged,
        game: game,
        settings: settings,
        stats: stats,
        days: days,
        profile: profile,
        mergeCalendar: choice == _RestoreChoice.merge,
      );
      _toast(
        choice == _RestoreChoice.merge
            ? 'Save restored, calendar merged.'
            : 'Save restored.',
      );
    } on SaveFileError catch (e) {
      _toast(e.message, colour: AppColor.clay);
    } catch (_) {
      _toast('That save could not be applied.', colour: AppColor.clay);
    } finally {
      if (mounted) setState(() => _busyIo = false);
    }
  }

  // --- clipboard route -----------------------------------------------------

  Future<void> _copyCode(
    GameController game,
    SettingsStore settings,
    StatsStore stats,
  ) async {
    stats.flush();
    final code = SaveCode.encode(game: game, settings: settings, stats: stats);
    await Clipboard.setData(ClipboardData(text: code));
    _toast('Code copied — ${code.length} characters. The calendar is not in it.');
  }

  Future<void> _pasteCode(
    GameController game,
    SettingsStore settings,
    StatsStore stats,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final SavePreview preview;
    try {
      preview = SaveCode.decode(data?.text ?? '');
    } on SaveCodeError catch (e) {
      _toast(e.message, colour: AppColor.clay);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.rail,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Restore this code?', style: AppText.ui(16, weight: 600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preview.summary, style: AppText.mono(11, color: AppColor.jade, height: 1.4)),
            const SizedBox(height: 10),
            Text(
              'This replaces your bankroll and lifetime record. Your calendar '
              'is left alone — a code does not carry it.',
              style: AppText.ui(11.5, color: AppColor.boneMid, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppText.ui(13, color: AppColor.boneMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Replace', style: AppText.ui(13, weight: 600, color: AppColor.clay)),
          ),
        ],
      ),
    );

    if (ok ?? false) {
      SaveCode.apply(preview, game: game, settings: settings, stats: stats);
      _toast('Save restored.');
    }
  }
}

enum _RestoreChoice { cancel, merge, replace }

/// What is in the file, and the one decision that actually matters: whether
/// the calendar already on this device survives.
class _RestoreDialog extends StatelessWidget {
  const _RestoreDialog({required this.staged});

  final StagedSave staged;

  @override
  Widget build(BuildContext context) {
    final s = staged.summary;

    return AlertDialog(
      backgroundColor: AppColor.rail,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Restore this save?', style: AppText.ui(16, weight: 600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staged.name,
              style: AppText.mono(10.5, color: AppColor.slate),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text('THIS FILE HOLDS', style: AppText.eyebrow(7.5)),
            const SizedBox(height: 6),
            _Line('${chips(s.bankroll)} chips'),
            _Line('${chips(s.stats.rounds)} rounds · ${chips(s.stats.decisions)} decisions'),
            _Line(s.calendarSpan),
            if (s.dayCount > 0)
              _Line('${chips(s.dayRounds)} rounds on the calendar · '
                  '${signedChips(s.dayNet)} net'),
            _Line('Saved ${s.savedOn} · ${s.sizeLabel}'),
            const SizedBox(height: 12),
            Text(
              'Your bankroll, rules and lifetime record are replaced either way. '
              'Choose what happens to the calendar.',
              style: AppText.ui(11.5, color: AppColor.boneMid, height: 1.4),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _RestoreChoice.cancel),
          child: Text('Cancel', style: AppText.ui(13, color: AppColor.boneMid)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _RestoreChoice.merge),
          child: Text(
            'Merge days',
            style: AppText.ui(13, weight: 600, color: AppColor.jade),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _RestoreChoice.replace),
          child: Text(
            'Replace everything',
            style: AppText.ui(13, weight: 600, color: AppColor.clay),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(text, style: AppText.mono(11, color: AppColor.jade, height: 1.4)),
      );
}

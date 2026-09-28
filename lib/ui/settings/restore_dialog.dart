import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../state/save_file.dart';
import '../../state/save_transfer.dart';
import '../common/table_button.dart';

enum RestoreChoice { cancel, merge, replace }

/// What is in the file, and the one decision that actually matters: whether
/// the calendar already on this device survives.
///
/// Either choice overwrites the bankroll and lifetime record, so the dialog
/// also offers to download what is here now. It sits inside the dialog rather
/// than as a step before it because the player only knows they want a copy
/// once they have seen what the incoming file would replace it with.
class RestoreDialog extends StatefulWidget {
  const RestoreDialog({required this.staged, required this.onDownload, super.key});

  final StagedSave staged;

  /// Writes the save currently on this device somewhere the player keeps.
  final Future<ExportOutcome> Function() onDownload;

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  bool _saving = false;
  ExportOutcome? _kept;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final outcome = await widget.onDownload();
      if (!mounted) return;
      setState(() => _kept = outcome.cancelled ? _kept : outcome);
    } on SaveFileError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'The save could not be written.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.staged.summary;
    final kept = _kept;

    // Leaving or applying mid-download would restore over the stores while
    // the backup is still being read out of them.
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        backgroundColor: AppColor.rail,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Restore this save?', style: AppText.ui(16, weight: 600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.staged.name,
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
                _Line(
                  '${chips(s.dayRounds)} rounds on the calendar · '
                  '${signedChips(s.dayNet)} net',
                ),
              _Line('Saved ${s.savedOn} · ${s.sizeLabel}'),
              const SizedBox(height: 14),
              Text('WHAT YOU HAVE NOW', style: AppText.eyebrow(7.5)),
              const SizedBox(height: 6),
              TableButton(
                label: _saving
                    ? 'Saving…'
                    : kept == null
                    ? 'Download current save'
                    : 'Download again',
                height: 38,
                fontSize: 11.5,
                enabled: !_saving,
                onTap: _download,
              ),
              const SizedBox(height: 6),
              // The error outranks an earlier success: a failed second copy must
              // not read as if it had landed.
              if (_error != null)
                Text(_error!, style: AppText.ui(11, color: AppColor.clay, height: 1.4))
              else if (kept != null)
                Text(
                  'Kept ${kept.name} · ${kept.sizeLabel}',
                  style: AppText.mono(10.5, color: AppColor.jade, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'A copy of this device\'s save, to come back to if the import '
                  'is not what you wanted.',
                  style: AppText.ui(11, color: AppColor.slate, height: 1.4),
                ),
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
          _action('Cancel', RestoreChoice.cancel, AppText.ui(13, color: AppColor.boneMid)),
          _action(
            'Merge days',
            RestoreChoice.merge,
            AppText.ui(13, weight: 600, color: AppColor.jade),
          ),
          _action(
            'Replace everything',
            RestoreChoice.replace,
            AppText.ui(13, weight: 600, color: AppColor.clay),
          ),
        ],
      ),
    );
  }

  // The label colours are explicit, so TextButton's own disabled styling never
  // shows; fade them by hand instead.
  Widget _action(String label, RestoreChoice choice, TextStyle style) => TextButton(
    onPressed: _saving ? null : () => Navigator.pop(context, choice),
    child: AnimatedOpacity(
      opacity: _saving ? 0.28 : 1,
      duration: const Duration(milliseconds: 160),
      child: Text(label, style: style),
    ),
  );
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

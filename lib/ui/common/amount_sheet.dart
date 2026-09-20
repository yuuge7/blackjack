import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import 'table_button.dart';

/// One shortcut button under the field — "Min", "Max", "Double", and so on.
class AmountPreset {
  const AmountPreset(this.label, this.value);

  final String label;
  final int value;
}

/// Type an exact amount. Used anywhere the app takes a number of chips that a
/// rack of four denominations cannot stack: the table limits you set for your
/// own table, and the bet itself.
///
/// Returns the amount, or null if the sheet was dismissed.
Future<int?> askAmount(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
  String? note,
  String confirm = 'Set',
  List<AmountPreset> presets = const [],
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColor.rail,
    barrierColor: AppColor.feltLo.withValues(alpha: 0.72),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AmountSheet(
      title: title,
      initial: initial,
      min: min,
      max: max,
      note: note,
      confirm: confirm,
      presets: presets,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.note,
    required this.confirm,
    required this.presets,
  });

  final String title;
  final int initial;
  final int min;
  final int max;
  final String? note;
  final String confirm;
  final List<AmountPreset> presets;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _field =
      TextEditingController(text: widget.initial > 0 ? '${widget.initial}' : '');
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _field.selection = TextSelection(baseOffset: 0, extentOffset: _field.text.length);
    // The keyboard is the whole point of this sheet, so it opens with it up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  int? get _typed {
    final raw = _field.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  /// Null when the field holds something this sheet would refuse.
  String? get _problem {
    final v = _typed;
    if (v == null) return null;
    if (v < widget.min) return 'Minimum is ${chips(widget.min)}.';
    if (v > widget.max) return 'Maximum is ${chips(widget.max)}.';
    return null;
  }

  bool get _valid => _typed != null && _problem == null;

  void _submit() {
    if (!_valid) return;
    Navigator.pop(context, _typed);
  }

  void _use(int value) {
    setState(() {
      _field.text = '${value.clamp(widget.min, widget.max)}';
      _field.selection = TextSelection.collapsed(offset: _field.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final typed = _typed;
    final problem = _problem;

    return Padding(
      // Sits above the keyboard rather than under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.title, style: AppText.display(26, weight: 700, height: 0.95)),
              const SizedBox(height: 10),
              TextField(
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
                style: AppText.display(38, weight: 700, height: 1.05),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: AppText.display(38, weight: 700, color: AppColor.slate, height: 1.05),
                  filled: true,
                  fillColor: AppColor.railHi,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColor.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: problem == null ? AppColor.line : AppColor.clay,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: problem == null ? AppColor.amber : AppColor.clay,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Echoes the number back grouped, because a long run of digits is
              // hard to read back at a glance.
              Text(
                problem ??
                    (typed == null
                        ? 'Anything from ${chips(widget.min)} to ${chips(widget.max)}.'
                        : '${chips(typed)} chips'),
                style: AppText.mono(
                  11.5,
                  color: problem == null ? AppColor.jade : AppColor.clay,
                ),
              ),
              if (widget.presets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in widget.presets)
                      _Preset(label: p.label, onTap: () => _use(p.value)),
                  ],
                ),
              ],
              if (widget.note != null) ...[
                const SizedBox(height: 14),
                Text(
                  widget.note!,
                  style: AppText.ui(11.5, color: AppColor.slate, height: 1.4),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TableButton(
                      label: 'Cancel',
                      tone: ButtonTone.quiet,
                      height: 46,
                      fontSize: 12.5,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TableButton(
                      label: widget.confirm,
                      tone: ButtonTone.primary,
                      height: 46,
                      fontSize: 13,
                      enabled: _valid,
                      onTap: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: AppColor.railHi,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColor.line),
        ),
        child: Text(label, style: AppText.ui(11.5, weight: 600, color: AppColor.boneMid)),
      ),
    );
  }
}

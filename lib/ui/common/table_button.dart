import 'package:flutter/material.dart';

import '../../design/tokens.dart';

enum ButtonTone { neutral, primary, quiet, danger }

/// The table's controls. Deliberately plain, because the one thing allowed to
/// stand out is the ring the coach puts around the move basic strategy wants.
class TableButton extends StatefulWidget {
  const TableButton({
    required this.label,
    required this.onTap,
    this.tone = ButtonTone.neutral,
    this.enabled = true,
    this.recommended = false,
    this.height = 48,
    this.fontSize = 13,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final ButtonTone tone;
  final bool enabled;

  /// Marks the move basic strategy would make, when the coach is on.
  final bool recommended;
  final double height;
  final double fontSize;

  @override
  State<TableButton> createState() => _TableButtonState();
}

class _TableButtonState extends State<TableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;

    final (bg, fg, border) = switch (widget.tone) {
      ButtonTone.primary => (AppColor.amber, AppColor.ink, AppColor.amber),
      ButtonTone.danger => (AppColor.railHi, AppColor.clay, AppColor.clay.withValues(alpha: 0.45)),
      ButtonTone.quiet => (Colors.transparent, AppColor.boneMid, Colors.transparent),
      ButtonTone.neutral => (AppColor.railHi, AppColor.bone, AppColor.line),
    };

    return Semantics(
      button: true,
      enabled: on,
      label: widget.recommended ? '${widget.label}, basic strategy play' : widget.label,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTap: on ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? 0.965 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: on ? 1 : 0.28,
            duration: const Duration(milliseconds: 160),
            child: Container(
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: widget.recommended && on ? AppColor.amber : border,
                  width: widget.recommended && on ? 1.6 : 1,
                ),
                boxShadow: widget.recommended && on
                    ? [BoxShadow(color: AppColor.amber.withValues(alpha: 0.22), blurRadius: 14)]
                    : null,
              ),
              child: Text(
                widget.label,
                style: AppText.ui(
                  widget.fontSize,
                  weight: 600,
                  color: fg,
                  letterSpacing: widget.fontSize * 0.09,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

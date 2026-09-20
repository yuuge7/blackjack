import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Bankroll after every round, one series. Drag across it to read a round.
class BankrollChart extends StatefulWidget {
  const BankrollChart({required this.values, this.height = 132, super.key});

  final List<int> values;
  final double height;

  @override
  State<BankrollChart> createState() => _BankrollChartState();
}

class _BankrollChartState extends State<BankrollChart> {
  int? _scrub;

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    if (values.length < 2) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            'The curve starts after your second hand.',
            style: AppText.ui(12, color: AppColor.slate),
          ),
        ),
      );
    }

    final index = _scrub;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 16,
          child: Row(
            children: [
              Text('BANKROLL BY ROUND', style: AppText.eyebrow(8)),
              const Spacer(),
              if (index != null)
                Text(
                  'ROUND ${index + 1}  ·  ${values[index]}',
                  style: AppText.mono(10, weight: FontWeight.w600, color: AppColor.amber),
                )
              else
                Text(
                  'LOW ${_min(values)}  ·  HIGH ${_max(values)}',
                  style: AppText.mono(10, color: AppColor.slate),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => _update(d.localPosition.dx),
          onHorizontalDragEnd: (_) => setState(() => _scrub = null),
          onTapDown: (d) => _update(d.localPosition.dx),
          onTapUp: (_) => setState(() => _scrub = null),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(painter: _CurvePainter(values: values, scrub: index)),
          ),
        ),
      ],
    );
  }

  void _update(double dx) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    final n = widget.values.length;
    final i = ((dx / w) * (n - 1)).round().clamp(0, n - 1);
    if (i != _scrub) setState(() => _scrub = i);
  }

  static int _min(List<int> v) => v.reduce((a, b) => a < b ? a : b);
  static int _max(List<int> v) => v.reduce((a, b) => a > b ? a : b);
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.values, required this.scrub});

  final List<int> values;
  final int? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final pad = 8.0;
    final plotH = size.height - pad * 2;

    Offset at(int i) {
      final x = values.length == 1 ? 0.0 : i / (values.length - 1) * size.width;
      final y = pad + (1 - (values[i] - lo) / span) * plotH;
      return Offset(x, y);
    }

    // Where the session started, so gains and losses are readable at a glance.
    final startY = at(0).dy;
    final dash = Paint()
      ..color = AppColor.slate.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, startY), Offset(x + 3.5, startY), dash);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColor.amber.withValues(alpha: 0.18), AppColor.amber.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColor.amber,
    );

    final i = scrub;
    if (i != null) {
      final p = at(i);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..strokeWidth = 1
          ..color = AppColor.amber.withValues(alpha: 0.35),
      );
      // 2px surface ring keeps the marker legible over the fill.
      canvas.drawCircle(p, 6, Paint()..color = AppColor.rail);
      canvas.drawCircle(p, 4.5, Paint()..color = AppColor.amber);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.values != values || old.scrub != scrub;
}

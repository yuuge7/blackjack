/// Chip amounts, grouped so a six-figure bankroll is still readable at a
/// glance. Plain digits everywhere else would run together.
String chips(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

/// Signed, for anything that can go either way.
String signedChips(int value) => value > 0 ? '+${chips(value)}' : chips(value);

/// What fits on the face of a chip: 25, 500, 1K, 25K.
String chipFace(int denom) {
  if (denom < 1000) return '$denom';
  final thousands = denom / 1000;
  final label = thousands == thousands.roundToDouble()
      ? thousands.round().toString()
      : thousands.toStringAsFixed(1);
  return '${label}K';
}

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

/// What fits on the face of a chip: 25, 500, 1K, 25K, 2.5M.
String chipFace(int denom) {
  String scaled(num value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  if (denom < 1000) return '$denom';
  if (denom < 1000000) return '${scaled(denom / 1000)}K';
  if (denom < 1000000000) return '${scaled(denom / 1000000)}M';
  return '${scaled(denom / 1000000000)}B';
}

/// A short form for headline amounts, where the full grouped number would not
/// fit: 4,200 stays 4,200, but 1,250,000 becomes 1.25M.
String compactChips(int value) {
  final n = value.abs();
  if (n < 100000) return chips(value);
  final sign = value < 0 ? '-' : '';
  if (n < 1000000) return '$sign${(n / 1000).toStringAsFixed(0)}K';
  if (n < 1000000000) return '$sign${(n / 1000000).toStringAsFixed(2)}M';
  return '$sign${(n / 1000000000).toStringAsFixed(2)}B';
}

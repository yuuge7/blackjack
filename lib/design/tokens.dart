import 'package:flutter/material.dart';

/// Colour comes from the table itself: a deep indigo layout under a warm
/// overhead light, bone screen-print, and clay chip denominations.
class AppColor {
  const AppColor._();

  static const feltHi = Color(0xFF2B3357);
  static const feltMid = Color(0xFF1B2140);
  static const feltLo = Color(0xFF0A0D18);

  static const rail = Color(0xFF12151F);
  static const railHi = Color(0xFF1C2130);
  static const line = Color(0xFF2B3149);

  static const bone = Color(0xFFEDE6D4);
  static const boneMid = Color(0xFFBCB6A6);

  static const amber = Color(0xFFF0B429);
  static const clay = Color(0xFFD8453F);
  static const jade = Color(0xFF2FA37B);
  static const violet = Color(0xFF7A5CC4);
  static const ink = Color(0xFF14161F);

  /// Neutral midpoint for the win / push / loss scale, and recessive chart ink.
  static const slate = Color(0xFF7C8498);

  /// Chip clay by denomination, the way a real rack is ordered.
  static const chips = <int, Color>{
    1: Color(0xFFE6DFCE),
    5: Color(0xFFC8372F),
    25: Color(0xFF1E7A5A),
    100: Color(0xFF20242F),
    500: Color(0xFF5B3E8E),
    1000: Color(0xFFB8701A),
    5000: Color(0xFF2E5E8E),
    25000: Color(0xFFCBAE55),
  };

  /// Denominations whose clay is light enough to need dark lettering.
  static const _lightChips = {1, 25000};

  static Color chipInk(int denom) => _lightChips.contains(denom) ? ink : bone;

  static Color chipColor(int denom) => chips[denom] ?? amber;
}

/// Three voices: a tall condensed display for card ranks and headline numbers,
/// a grotesque for interface labels, and a mono for money and counts.
class AppText {
  const AppText._();

  static const _display = 'BigShoulders';
  static const _ui = 'Archivo';
  static const _mono = 'PlexMono';

  static TextStyle display(
    double size, {
    double weight = 700,
    Color color = AppColor.bone,
    double letterSpacing = 0,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', weight)],
      );

  static TextStyle ui(
    double size, {
    double weight = 500,
    Color color = AppColor.bone,
    double letterSpacing = 0,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _ui,
        fontSize: size,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', weight), const FontVariation('wdth', 100)],
      );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColor.bone,
    double letterSpacing = 0,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _mono,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Small caps-and-tracking label, the register the table itself is printed in.
  static TextStyle eyebrow(double size, {Color color = AppColor.boneMid, double weight = 600}) =>
      ui(size, weight: weight, color: color, letterSpacing: size * 0.18);
}

class AppSpace {
  const AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 22.0;
  static const xl = 34.0;
}

/// Playing card proportions, held at the real 2.5 by 3.5 ratio.
const double kCardAspect = 0.7;

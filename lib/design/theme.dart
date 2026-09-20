import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColor.amber,
    onPrimary: AppColor.ink,
    secondary: AppColor.jade,
    onSecondary: AppColor.ink,
    error: AppColor.clay,
    onError: AppColor.bone,
    surface: AppColor.rail,
    onSurface: AppColor.bone,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColor.feltLo,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: 'Archivo',
    textTheme: TextTheme(
      bodyMedium: AppText.ui(14),
      bodySmall: AppText.ui(12, color: AppColor.boneMid),
      titleMedium: AppText.ui(15, weight: 600),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColor.amber,
      inactiveTrackColor: AppColor.line,
      thumbColor: AppColor.amber,
      overlayColor: Color(0x22F0B429),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColor.ink : AppColor.boneMid,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColor.amber : AppColor.line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

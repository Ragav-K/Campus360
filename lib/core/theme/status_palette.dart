import 'package:flutter/material.dart';

import '../../models/enums/pulse_enums.dart';
import 'app_colors.dart';

/// Resolves a semantic [StatusTone] to concrete colours and an icon.
///
/// Everything that shows a status — Pulse cards, map markers, print order
/// states, Lost & Found claim states — goes through here, so "green means
/// good" is true across the whole app and only has to be changed in one place.
abstract final class StatusPalette {
  static Color colorOf(StatusTone tone) => switch (tone) {
        StatusTone.good => AppColors.success,
        StatusTone.caution => AppColors.warning,
        StatusTone.bad => AppColors.danger,
        StatusTone.info => AppColors.info,
        StatusTone.neutral => AppColors.neutral,
      };

  static IconData iconOf(StatusTone tone) => switch (tone) {
        StatusTone.good => Icons.check_circle_rounded,
        StatusTone.caution => Icons.warning_amber_rounded,
        StatusTone.bad => Icons.error_rounded,
        StatusTone.info => Icons.info_rounded,
        StatusTone.neutral => Icons.remove_circle_outline_rounded,
      };

  /// Background for a chip, blended against the surface for the current theme.
  static Color surfaceOf(StatusTone tone, Brightness brightness) =>
      AppColors.tint(colorOf(tone), brightness);

  /// Foreground that stays readable on [surfaceOf]. In dark mode the base
  /// colours are too dim against a dark tint, so they're lightened.
  static Color onSurfaceOf(StatusTone tone, Brightness brightness) {
    final base = colorOf(tone);
    if (brightness == Brightness.light) return base;
    return Color.lerp(base, Colors.white, 0.35)!;
  }
}

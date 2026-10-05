# lib/core/theme/status_palette.dart

## Purpose
Resolves the semantic `StatusTone` enum to concrete colors and icons, as the single place that defines what "good/caution/bad/info/neutral" look like across the app.

## Key members
- `StatusPalette` (abstract final class):
  - `colorOf(StatusTone)` — maps tone to an `AppColors` value.
  - `iconOf(StatusTone)` — maps tone to a Material icon.
  - `surfaceOf(StatusTone, Brightness)` — tinted chip background via `AppColors.tint`.
  - `onSurfaceOf(StatusTone, Brightness)` — foreground color readable on `surfaceOf`, lightened in dark mode.

## Dependencies & relationships
Imports `flutter/material.dart`, `models/enums/pulse_enums.dart` (for `StatusTone`), `app_colors.dart`. Used by Pulse cards, map markers, print order states, and Lost & Found claim states wherever a status badge/chip is rendered.

## Notable behavior / gotchas
In dark mode, base status colors are blended 35% toward white (`onSurfaceOf`) because they're otherwise too dim against a dark tinted background.

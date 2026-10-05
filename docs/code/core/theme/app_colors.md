# lib/core/theme/app_colors.dart

## Purpose
Defines the Campus360 color palette (brand, light/dark surfaces, semantic status colors) used across the whole app.

## Key members
- `AppColors` (abstract final class) — const `Color`s for brand (`primary`, `primaryDark`, `primaryLight`, `accent`, `accentLight`), light surfaces (`bgLight`, `surfaceLight`, `surfaceAltLight`, `borderLight`, `textLight`, `textMutedLight`), dark surfaces (equivalent `*Dark` set), semantic status colors (`success`, `warning`, `danger`, `info`, `neutral`), and `tint(Color, Brightness)` for blending a status color onto the current surface.

## Dependencies & relationships
Imports `flutter/material.dart`. Consumed by `app_theme.dart` and `status_palette.dart`, and indirectly by any widget rendering status chips/badges.

## Notable behavior / gotchas
Status colors are explicitly shared across Pulse, Lost & Found, and Printout so "green means good" is consistent app-wide — do not introduce a feature-local status color scheme.

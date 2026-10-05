# lib/core/theme/app_theme.dart

## Purpose
Builds the app's Material 3 `ThemeData` for light and dark brightness, applying `AppColors` and `Gap`/`Radii` to all major component themes.

## Key members
- `AppTheme` (abstract final class) — `light()` and `dark()` return `ThemeData` via shared `_build(Brightness)`, which configures `ColorScheme`, text theme, app bar, card, input decoration, filled/outlined/text button themes, chip theme, navigation bar theme, divider, bottom sheet, dialog, snackbar, and page transitions.

## Dependencies & relationships
Imports `flutter/material.dart`, `flutter/cupertino.dart` (for `CupertinoPageTransitionsBuilder`), `app_colors.dart`, `app_spacing.dart`. Consumed by `app.dart` (`AppTheme.light()`/`AppTheme.dark()` passed to `MaterialApp.router`).

## Notable behavior / gotchas
Uses platform-specific page transitions: `FadeUpwardsPageTransitionsBuilder` on Android, `CupertinoPageTransitionsBuilder` on iOS. All interactive components enforce `kMinTouchTarget` (48px) for accessibility. Card/app bar/bottom sheet/dialog all disable `surfaceTintColor` to avoid Material 3's default tint overlay.

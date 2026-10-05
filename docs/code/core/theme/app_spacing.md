# lib/core/theme/app_spacing.dart

## Purpose
4pt spacing scale and shared layout constants (border radii, minimum touch target, page padding) for consistent density across the app.

## Key members
- `Gap` (abstract final class) — spacing constants `xs`..`xxl` (4–32), plus pre-built `SizedBox`es for vertical (`h4`..`h32`) and horizontal (`w4`..`w16`) gaps.
- `Radii` (abstract final class) — `BorderRadius` presets `sm`, `md`, `lg`, `pill`.
- `kMinTouchTarget` — 48.0, accessibility minimum interactive size.
- `kPagePadding` — standard horizontal page `EdgeInsets`.

## Dependencies & relationships
Imports `flutter/widgets.dart`. Used extensively by `app_theme.dart` and nearly every screen/widget for spacing and corner radii.

## Notable behavior / gotchas
None noted.

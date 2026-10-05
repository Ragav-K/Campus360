# lib/features/auth/widgets/brand_mark.dart

## Purpose
Reusable widget rendering the Campus360 logo mark (rounded square with a radar/pulse icon and accent dot).

## Key members
- `BrandMark` — stateless widget; `size` (default 56) and `onPrimary` (default false, for rendering on a primary-color background e.g. the splash screen) control appearance.

## Dependencies & relationships
Uses `AppColors` (primary, accentLight). Used by `SplashScreen` and `AuthScaffold` (login screen header).

## Notable behavior / gotchas
None noted — purely presentational, no interactivity or state.

# lib/features/auth/widgets/auth_scaffold.dart

## Purpose
Shared layout chrome reused by all four auth screens (login, register, forgot password, and its confirmation state): centered, max-width, scrollable column with title, subtitle, optional error banner, and slot for form content.

## Key members
- `AuthScaffold` — takes `title`, `subtitle`, `children`, optional `failure` (`AppFailure?`) and `showBack` (bool). Renders an `AppBar` only when `showBack` is true; otherwise shows a `BrandMark` instead (used on the login screen, the entry point with no back action).
- `_ErrorBanner` — private widget rendering an inline, accessible (`Semantics(liveRegion: true)`) error box for a given `AppFailure`.

## Dependencies & relationships
Uses `AppFailure` (core/errors), `brand_mark.dart`. Used by `LoginScreen`, `RegisterScreen`, `ForgotPasswordScreen`.

## Notable behavior / gotchas
- Error banner is placed inline next to the form rather than in a `SnackBar`, by design (per doc comment) — auth errors belong next to the form.
- `SingleChildScrollView` ensures the keyboard never covers the submit button.
- Max content width is capped at 440 logical pixels for larger screens.

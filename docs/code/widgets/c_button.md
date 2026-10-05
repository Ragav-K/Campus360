# lib/widgets/c_button.dart

## Purpose
The app's primary action button, standardizing loading/disabled state, variants, and danger styling so no screen needs to re-implement double-submit protection.

## Key members
- `CButton` (StatelessWidget) — constructor params: `label` (required), `onPressed` (required, nullable), `loading` (default false, shows spinner and disables), `icon`, `variant` (`CButtonVariant`), `expand` (default true, fills width), `danger` (error-colored styling).
- `CButtonVariant` enum — `filled`, `outlined`, `text`.

## Dependencies & relationships
Imports `app_spacing.dart` (`Gap`). Used broadly across forms and action screens throughout the app (auth, reporting, orders, admin screens) as the standard button.

## Notable behavior / gotchas
- While `loading` is true, the button is disabled *and* shows a spinner, enforcing the "don't allow double submit" rule structurally.
- Wraps the button in `Semantics` to announce "in progress" to screen readers when loading, not just visually via the spinner.

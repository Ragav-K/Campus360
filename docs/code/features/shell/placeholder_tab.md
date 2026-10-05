# lib/features/shell/placeholder_tab.dart

## Purpose
Generic "not built yet" screen used for app tabs/features whose real implementation hasn't shipped, so the shell never shows a dead or fake feature.

## Key members
- `PlaceholderTab` — `ConsumerWidget` taking `title`, `icon`, and `phase` (describing when the real feature ships); shows an app bar with a sign-out action, an optional user summary card, and an `EmptyState` message stating the module isn't built yet and isn't a mock.

## Dependencies & relationships
Uses `currentUserProvider`, `authControllerProvider.signOut()` (auth_providers.dart), `EmptyState` widget, `kPagePadding`.

## Notable behavior / gotchas
- Explicitly designed to avoid "fake" or misleading UI (per doc comment referencing "§40: no dead buttons, no features pretending to work") — intended to be replaced module by module in later development phases.

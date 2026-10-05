# lib/widgets/state_views.dart

## Purpose
Shared UI building blocks for empty states, error states, and loading skeletons, used to standardize non-happy-path screens across the app.

## Key members
- `EmptyState` (StatelessWidget) — params: `icon`, `title`, `message`, `actionLabel`, `onAction`, `compact`. Generic "nothing to show" view with an optional action button.
- `ErrorStateView` (StatelessWidget) — params: `failure` (`AppFailure`), `onRetry`, `compact`. Picks an icon/title from `failure.kind` and shows `failure.message` (never a raw Firebase error); shows a "Try again" action only if `failure.isRetryable` and `onRetry` is provided. Built on top of `EmptyState`.
- `Skeleton` (StatefulWidget) — params: `height`, `width`, `borderRadius`. A single shimmering placeholder block, animated via an `AnimationController` that repeats/reverses.
- `SkeletonCard` (StatelessWidget) — params: `lines`. A composite skeleton matching a typical card's silhouette (badge row, title, body lines).

## Dependencies & relationships
Imports `app_failure.dart`, `app_spacing.dart` (`Gap`, `Radii`), and `c_button.dart` (`CButton`). Consumed indirectly via `async_value_view.dart` (for error/loading rendering) and directly by screens building custom skeleton loading layouts.

## Notable behavior / gotchas
- `ErrorStateView` intentionally never surfaces raw Firebase/exception text — only the mapped `AppFailure.message`.
- `Skeleton`'s `_SkeletonState` properly disposes its `AnimationController`; wrapped in `ExcludeSemantics` so screen readers skip the shimmering placeholder.

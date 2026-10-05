# lib/widgets/async_value_view.dart

## Purpose
A generic widget that renders the loading / error / empty / data states of a Riverpod `AsyncValue<T>` consistently in one place, so screens can't forget a state.

## Key members
- `AsyncValueView<T>` (StatelessWidget) — constructor params: `value` (the `AsyncValue<T>`), `data` (builder for loaded content), `skeleton` (optional loading widget builder), `empty`/`isEmpty` (optional empty-state builder and predicate), `onRetry` (retry callback for errors), `compact` (dense error/empty layout).

## Dependencies & relationships
Imports `flutter_riverpod`, `app_failure.dart`/`failure_mapper.dart`, and `state_views.dart` (`ErrorStateView`). Used throughout feature screens wherever a Riverpod provider's `AsyncValue` is rendered (Pulse, Map, Lost & Found, Printout, Timetable lists/details).

## Notable behavior / gotchas
- Uses `value.when(skipLoadingOnRefresh: true, ...)` so a refresh doesn't flash the loading state over existing data.
- On error, wraps non-`AppFailure` errors via `FailureMapper.map(e, s)` before passing to `ErrorStateView` — callers never see raw exceptions.
- Empty detection defaults to `d is Iterable && d.isEmpty` when `isEmpty` is not supplied, but only triggers the `empty` builder if one was provided.

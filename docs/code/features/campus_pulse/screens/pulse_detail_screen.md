# lib/features/campus_pulse/screens/pulse_detail_screen.dart

## Purpose
Full detail view for one Campus Pulse update, including posted/expiry metadata, its related location, and a "report outdated info" flow.

## Key members
- `PulseDetailScreen` — `ConsumerWidget` loading `pulseDetailProvider(pulseId)` via `AsyncValueView`, with a "not found/removed or expired" empty state.
- `_Body` — shows a "no longer active" banner for expired updates, status chip, category, title/description, and info rows for posted time, expiry countdown, poster name, and linked location (tappable to `locationDetail`).
- `_InfoRow` — icon/label/value row, optionally tappable, with an optional highlighted value color.
- `_ReportStaleButton` / `_ReportStaleButtonState` — lets a signed-in user report an update as outdated; opens `_ReportSheet` to pick a reason, then calls `pulseRepository.reportStale(...)`, showing a sending/sent/error state.
- `_ReportSheet` — bottom sheet with a `RadioGroup` of canned reasons ("no longer accurate", "status has changed", etc.) and a submit button.

## Dependencies & relationships
Watches `pulseDetailProvider` and `clockTickProvider` (for live countdowns), uses `authRepositoryProvider` for the reporting user's uid, and `pulseRepositoryProvider.reportStale`. Navigates to `Routes.locationDetail`. Uses `StatusChip`, `AsyncValueView`, `EmptyState`, `CButton`.

## Notable behavior / gotchas
An update can be opened after it has expired (via a stale list or deep link); the screen explicitly flags this ("no longer active") rather than presenting stale data as current. Expiry value color turns to the status accent and bold when under 30 minutes remaining. Report submission requires a logged-in uid; if absent, `_report()` silently returns. Errors from reporting are mapped through `AppFailure` and shown via snackbar.

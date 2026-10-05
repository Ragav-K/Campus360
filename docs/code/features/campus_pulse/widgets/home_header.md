# lib/features/campus_pulse/widgets/home_header.dart

## Purpose
Small header widgets for the Pulse/home screen: the quick-action row and the personalized greeting line.

## Key members
- `QuickActions` — a row of three `_ActionTile`s linking to Map (find location), Lost & Found, and new Print order. Only shows tiles for modules that actually exist.
- `_ActionTile` — a tappable card with an icon and label, used by `QuickActions`.
- `HomeGreeting` — shows a time-of-day greeting (e.g. "Good morning 👋") plus the user's first name, derived via `Fmt.greeting()` / `Fmt.firstName(name)`.

## Dependencies & relationships
Uses `go_router`'s `context.go` to navigate to `Routes.map`, `Routes.lostFound`, `Routes.print`, and `Fmt` formatting utilities. Used by `pulse_home_screen.dart`.

## Notable behavior / gotchas
None noted.

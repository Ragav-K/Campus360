# lib/core/constants/routes.dart

## Purpose
Centralized, typed route path/name constants for go_router navigation across the whole app.

## Key members
- `Routes` (abstract final class) — static const paths for auth screens (splash, login, register, forgot-password, verify-email), the four tab roots (pulse, map, lostFound, print), detail-route builder functions (`pulseDetail`, `locationDetail`, `navigate`, `lostDetail`, `foundDetail`, `matchDetail`, `claimDetail`, `claimVerify`, `printOrder`, `printOtp`), timetable, common screens (notifications, profile, activity, settings), staff routes, admin routes, and `tabs` (list of the four tab root paths).

## Dependencies & relationships
No imports. Consumed by `core/router/app_router.dart` to define `GoRoute`s and redirects, and by any screen that navigates via `context.go`/`context.push`.

## Notable behavior / gotchas
Kept flat and const specifically so navigation stays refactor-safe (renaming a route constant catches all call sites). Detail routes are functions (not consts) since they embed an id.

# lib/core/router/app_router.dart

## Purpose
Defines the app's go_router configuration: route tree, auth-based redirects, and the four-tab shell navigation structure.

## Key members
- `_AuthRefresh` (ChangeNotifier) — notifies go_router to re-evaluate redirects whenever `authStateProvider` changes.
- `routerProvider` — `Provider<GoRouter>` building the full `GoRouter` with `initialLocation`, `redirect` logic, `routes`, and `errorBuilder`.

## Dependencies & relationships
Imports `go_router`, `flutter_riverpod`, `features/auth/providers/auth_providers.dart` (for `authStateProvider`, `currentRoleProvider`), numerous feature screens (auth, admin, notifications, campus_map, campus_pulse, printout, lost_found, profile, shell, timetable), `models/app_user.dart`, and `core/constants/routes.dart`. This is the central navigation wiring consumed by `app.dart` (`ref.watch(routerProvider)`).

## Notable behavior / gotchas
Redirect logic explicitly notes route guards are UX only, not security — the real access boundary is Firestore rules. Holds on `/splash` while auth state is loading to avoid a login-screen flash on cold start with a cached session. Admin/staff route prefixes (`/admin`, `/staff`) are gated by `role`/`role.isStaff` client-side as UX convenience. Uses `StatefulShellRoute.indexedStack` so each of the four tabs (pulse, map, lostFound, print) keeps independent navigation state.

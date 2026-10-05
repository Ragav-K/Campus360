# lib/features/shell/app_shell.dart

## Purpose
The signed-in app's four-tab bottom-navigation shell (Pulse, Map, Lost & Found, Printout), and the single long-lived host for push-notification plumbing.

## Key members
- `AppShell` / `_AppShellState` — wraps a `StatefulNavigationShell` (go_router), renders the `NavigationBar` with four destinations, watches `tokenRegistrarProvider` to keep the FCM token registered, listens for foreground pushes (shows a snackbar with an "Open" action) and for notification taps (navigates directly), and handles the cold-start initial push message.

## Dependencies & relationships
Uses `messagingServiceProvider`, `tokenRegistrarProvider`, `foregroundMessageProvider`, `notificationTapProvider` (notification_providers.dart), `AppNotification` model, `Routes.notifications`, and `go_router`'s `context.push`. Hosted by the app's router as the shell for the four main tab routes.

## Notable behavior / gotchas
- Cold-start push payload (`initialMessage()`) is read exactly once, after the first frame, since it's only available at that point.
- Foreground pushes are surfaced manually via `SnackBar` because the OS suppresses system notification banners while the app is in the foreground.
- A push with no usable destination route falls back to opening the notifications inbox rather than silently doing nothing.

# lib/features/notifications/screens/notifications_screen.dart

## Purpose
The in-app notification inbox screen, plus the reusable `NotificationBell` icon-button shown in app bars.

## Key members
- `NotificationsScreen` — lists notifications with read/unread styling, a "Mark all read" action, tap-to-open-and-navigate behavior, and an explicit empty state explaining that server-side delivery isn't live yet.
- `_NotificationRow` — single list row (icon by category, title, body, relative timestamp).
- `NotificationBell` — `ConsumerWidget` icon button with an unread-count dot; navigates to `Routes.notifications` by default or calls a custom `onTap`.

## Dependencies & relationships
Uses `inboxProvider`, `unreadCountProvider`, `notificationRepositoryProvider` (notification_providers.dart), `authStateProvider` (auth), `AppNotification`/`NotificationCategory` model, `AsyncValueView`, `EmptyState`, `describeFailure`, `Fmt.relative`, and `go_router` (`GoRouter.of(context).push`, `context.push(Routes.notifications)`).

## Notable behavior / gotchas
- Empty state explicitly states that notification delivery is not switched on yet (requires a paid Firebase/Blaze plan for the Cloud Function), avoiding a misleading "all caught up" message.
- Marking a notification read is best-effort and must not block navigation — failures are silently caught so opening the notification always proceeds.
- If a tapped notification has no destination route, a snackbar says so instead of navigating anywhere.

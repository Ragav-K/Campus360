# test/notifications_widget_test.dart

## Purpose
Widget tests for `lib/features/notifications/screens/notifications_screen.dart` (`NotificationsScreen`, `NotificationBell`), covering the notification inbox UI and the app-bar bell icon, driven by `notification_providers.dart`.

## Test cases
- **NotificationsScreen**
  - "an empty inbox says delivery is not switched on" — shows "Nothing here yet" plus explicit text that push needs a paid Firebase plan (no misleading "all caught up" message).
  - "renders each notification with its title and body" — multiple inbox items render their title/body text.
  - "'Mark all read' is hidden when everything is read" / "...appears when something is unread" — button visibility driven by unread state.
  - "an unread entry is weighted more heavily than a read one" — unread titles use `FontWeight.w700`, read titles `w500`.
- **NotificationBell**
  - "says how many are unread" — `IconButton.tooltip` is `"3 unread notifications"`.
  - "reads as plain 'Notifications' when there is nothing" — tooltip falls back when unread count is 0.
  - "tapping it opens the inbox" — `onTap` callback fires.

## Dependencies & relationships
Renders `NotificationsScreen`/`NotificationBell` inside a `ProviderScope` with `inboxProvider` and `unreadCountProvider` overridden with `Stream.value(...)` — no real Firebase/repository calls occur because the repository is only touched on tap, which these tests avoid. Uses `AppNotification` fixtures via local `_n()` helper.

## Notable behavior / gotchas
Each test uses a separate `pumpWidget` call rather than re-pumping with new overrides within one test, because re-pumping reuses the existing `ProviderScope` container and new overrides would silently not take effect. The unread count is shown via tooltip text, not a numeric badge, by design (accessibility).

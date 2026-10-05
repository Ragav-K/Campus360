# lib/models/app_notification.dart

## Purpose
Defines the in-app notification inbox model and the taxonomy of notification types/categories used across Print, Lost & Found, and Pulse.

## Key members
- `NotificationType` enum — wire-string-backed type (`print.received`, `lostfound.match`, etc.); `fromWire` parses safely to `unknown`; `category` getter maps a type to its owning module.
- `NotificationCategory` enum — `print`, `lostFound`, `pulse`, `other`.
- `AppNotification` class — fields `id`, `userId`, `type`, `title`, `body`, `data` (deep-link payload map), `read`, `createdAt`.
- `AppNotification.route` getter — computes a deep-link route string (via `Routes`) from `type`/`data`, or null if nothing to open.
- `AppNotification.fromDoc` factory — builds from a Firestore `DocumentSnapshot`.
- `AppNotification.fromMessageData` factory — builds from an FCM push payload for immediate display.

## Dependencies & relationships
Imports `cloud_firestore` and `../core/constants/routes.dart` (`Routes`). Maps to the `notifications/{id}` Firestore collection (per ARCHITECTURE.md §7). Likely consumed by a notifications repository/provider and an inbox screen, plus FCM message handling code that calls `fromMessageData`.

## Notable behavior / gotchas
Unknown wire values map to `NotificationType.unknown` instead of throwing, intentionally, so old app installs don't crash when the server ships new types. The client never creates `AppNotification` documents (security rules forbid it) — this model is read-mostly. `route` returns null rather than guessing when required data is missing.

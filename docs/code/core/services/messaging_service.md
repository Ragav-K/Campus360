# lib/core/services/messaging_service.dart

## Purpose
Thin wrapper over `firebase_messaging` handling push notification permission, device token management, and converting incoming `RemoteMessage`s into the app's `AppNotification` model.

## Key members
- `MessagingService` — const class with:
  - `requestPermission()` / `hasPermission()` — request/check notification permission (treats denial as a normal outcome, not an error).
  - `token()` — this device's FCM token, or null on any failure.
  - `tokenRefreshes` — stream of token rotation events.
  - `foregroundMessages` — stream of messages received while app is foregrounded.
  - `openedFromBackground` — stream of notification taps that resumed the app.
  - `initialMessage()` — the tap that cold-started the app, if any (delivered once).
  - `_toNotification(RemoteMessage)` — static mapper to `AppNotification`.

## Dependencies & relationships
Imports `dart:async`, `firebase_messaging`, `models/app_notification.dart`. Receiving-only counterpart to a not-yet-built sending Cloud Function (requires Blaze plan).

## Notable behavior / gotchas
Deliberately "thin"/non-load-bearing by design: per ARCHITECTURE.md §7 the Firestore inbox is the source of truth and push is only a best-effort hint — if permission is refused or FCM is unreachable, the in-app inbox and unread count stay correct regardless. No background message handler is implemented yet — intentionally deferred until the sending Cloud Function (and its payload shape) exists, since writing one now would be guessing at an undefined payload.

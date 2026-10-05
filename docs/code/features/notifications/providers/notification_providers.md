# lib/features/notifications/providers/notification_providers.dart

## Purpose
Riverpod providers wiring Firebase Cloud Messaging and the Firestore-backed notification inbox for the signed-in user.

## Key members
- `messagingServiceProvider` — exposes `MessagingService` (FCM wrapper).
- `notificationRepositoryProvider` — exposes `NotificationRepository` backed by Firestore.
- `inboxProvider` — `StreamProvider<List<AppNotification>>` of the current user's inbox (empty stream when signed out).
- `unreadCountProvider` — `StreamProvider<int>` of unread count.
- `fcmTokenProvider` — `FutureProvider<String?>` for this device's push token, only if permission is granted.
- `tokenRegistrarProvider` — `Provider<void>` side-effect provider that keeps `users/{uid}.fcmTokens` in sync with this device and re-registers on token rotation; meant to be watched (not read) by a long-lived widget.
- `foregroundMessageProvider` — stream of pushes received while app is foregrounded (for in-app banner).
- `notificationTapProvider` — stream of pushes that opened/resumed the app from a tap.

## Dependencies & relationships
Depends on `firestoreProvider` (firebase_providers.dart), `MessagingService`, `AppNotification` model, `NotificationRepository`, and `authStateProvider` (auth feature) to scope everything to the signed-in uid. Consumed by `AppShell` (token registration, foreground/tap listeners), `NotificationsScreen`, and `NotificationBell`.

## Notable behavior / gotchas
- Token registration failures are deliberately swallowed — push delivery is a "hint," never allowed to surface as a user-facing error or block other work.
- FCM token rotations are listened to continuously via `tokenRefreshes` and re-registered; `ref.onDispose` cancels the subscription.
- `inboxProvider`/`unreadCountProvider` return empty/zero (not an error) when signed out.

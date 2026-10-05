# lib/repositories/notification_repository.dart

## Purpose
Reads the in-app notification inbox (`notifications` collection) and maintains per-device FCM push tokens on the user document; does not create notifications itself.

## Key members
- `NotificationRepository(FirebaseFirestore)` — touches `notifications` collection and `users/{uid}` doc.
- `watchInbox(uid, {limit})` — inbox stream, newest first, backed by a `userId ASC, createdAt DESC` index.
- `watchUnreadCount(uid)` — unread badge count via document-count of a filtered query.
- `markRead(id)` — marks one notification read.
- `markAllRead(uid)` — batches updates in chunks of 400 (Firestore's 500-write batch cap).
- `registerToken(uid, token)` / `removeToken(uid, token)` — adds/removes an FCM token from the `fcmTokens` array field.

## Dependencies & relationships
Imports `failure_mapper.dart` and `AppNotification` model. Likely consumed by a notification bell/inbox screen and app-start/sign-out logic for FCM token lifecycle.

## Notable behavior / gotchas
- By design, notifications are only ever written by a Cloud Function reacting to a domain event (per class doc comment and security rules) — this class has no "create" method.
- Token array (not single field) supports multiple signed-in devices per account without muting others.

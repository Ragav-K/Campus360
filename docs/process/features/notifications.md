# Notifications

Screens: `lib/features/notifications/screens/notifications_screen.dart`
Providers: `lib/features/notifications/providers/notification_providers.dart`
Repository: `lib/repositories/notification_repository.dart`
Model: `lib/models/app_notification.dart` (`AppNotification`, `NotificationType`, `NotificationCategory`)
Service: `lib/core/services/messaging_service.dart` (wraps `firebase_messaging`)
Firestore: `notifications/{id}`; `users/{uid}.fcmTokens` (array)

## How notifications are generated

Nothing on the client ever creates a notification document — the
`NotificationRepository` file's own comment is explicit that Firestore rules
forbid it, because a client that could write its own notifications could
write them into someone else's inbox. Instead, notifications are written by
a **Cloud Function reacting to a domain event** (e.g. a print order's status
changing, a Lost & Found claim request/approval/rejection, a return
confirmation, or an admin posting a Pulse alert) — `NotificationType`
enumerates the wire values this produces: `print.received`, `print.printing`,
`print.ready`, `print.rejected`, `print.collected`, `lostfound.match`,
`lostfound.claimRequest`, `lostfound.claimApproved`,
`lostfound.claimRejected`, `lostfound.returned`, `pulse.alert`. An unknown
wire value maps to `NotificationType.unknown` rather than throwing, so an
older installed app version doesn't crash when a new notification type ships
server-side.

## How they're delivered

1. **Token registration.** `tokenRegistrarProvider`, watched for the whole
   signed-in session from `AppShell`, asks `MessagingService` for
   permission and an FCM token, then calls
   `NotificationRepository.registerToken(uid, token)`, which `arrayUnion`s
   the token into `users/{uid}.fcmTokens` (an array, not a single field,
   because one person may be signed in on a phone and a lab machine — an
   overwrite would silently mute the other device). It also listens to
   `messaging.tokenRefreshes` and re-registers on rotation (FCM rotates
   tokens on reinstall/restore), since an unregistered rotation silently
   stops delivery with nothing to notice it by. Registration failures are
   deliberately swallowed — push is a best-effort delivery hint, never
   something that should surface as an error or block the user.
2. **Push delivery** happens via `firebase_messaging` to whichever tokens
   are registered; the Cloud Function that creates the Firestore document is
   also what sends the push (and is expected to prune tokens that bounce
   back `registration-token-not-registered`, though that pruning lives
   server-side, not in this client).
3. **Sign-out cleanup.** `NotificationRepository.removeToken(uid, token)` is
   called on sign-out (see `auth.md`) so the next person on a shared device
   doesn't receive the previous user's pushes.

## How they're displayed

4. **In-app inbox.** `NotificationsScreen` (`Routes.notifications`, reached
   from the bell in the Pulse header) shows `inboxProvider`
   (`NotificationRepository.watchInbox(uid)` — newest first, limit 50). This
   is the source of truth per the repository's own doc comment: "if push
   never arrives, this is still here and the unread count is still right."
5. **Unread badge.** `unreadCountProvider` streams a `read == false` query
   and counts documents client-side (chosen over trying to read an
   aggregate, since the badge just needs a number).
6. **Marking read.** `NotificationRepository.markRead(id)` for one;
   `markAllRead(uid)` for the whole inbox, chunked into batches of 400
   writes (Firestore caps a batch at 500) since a long-neglected inbox can
   exceed that in one write.
7. **Foreground push.** `foregroundMessageProvider` streams pushes that
   arrive while the app is in the foreground, for an in-app banner —
   `AppNotification.fromMessageData` builds a display-only model straight
   from the FCM payload without waiting for the Firestore snapshot to catch
   up (it's never written back, only shown).
8. **Tap-to-open.** `AppNotification.route` maps a notification's `data`
   payload to a route: all `print.*` types open `Routes.printOrder(orderId)`
   (keyed off `NotificationCategory.print` rather than listing five cases);
   `lostfound.match` opens `Routes.matchDetail(matchId)`; the claim-related
   types open `Routes.claimDetail(claimId)`; `pulse.alert` opens
   `Routes.pulseDetail(pulseId)`. A payload that doesn't identify anything
   returns `null` deliberately — `AppShell._openNotification` falls back to
   opening the inbox rather than guessing at the wrong screen.
   - `notificationTapProvider` handles a tap while the app is backgrounded.
   - `AppShell.initState` separately checks
     `messagingService.initialMessage()` once, after the first frame, for a
     tap that cold-started the app (delivered exactly once, before there's
     anywhere to navigate to otherwise).
9. **Preferences.** Per-module opt-out (`NotificationPrefs.lostFound/print/pulse`
   on the user profile) is set via `AuthController.updateNotificationPrefs`
   and is expected to be honoured both on-device and server-side when
   deciding whether to send a push for a given `NotificationCategory`.

# test/app_notification_test.dart

## Purpose
Tests `lib/models/app_notification.dart` — the `NotificationType` enum (wire-string mapping, categories) and the `AppNotification` model (deep-link routing, construction from an FCM message payload).

## Test cases
- **NotificationType**
  - "maps every wire value from the design document" — `fromWire` correctly maps `print.ready`, `lostfound.claimRequest`, `pulse.alert`.
  - "an unrecognised type degrades instead of throwing" — unknown or null wire strings become `NotificationType.unknown` rather than throwing.
  - "categories group the modules the preference switches use" — print/lostFound/pulse types map to their `NotificationCategory`; unknown maps to `other`.
- **deep links**
  - "every print type opens the order it is about" — all print-category types route to `/print/order/<orderId>`.
  - "lost & found types open the match or claim" — match/claimApproved/returned types route to `/lostfound/match/<id>` or `/lostfound/claim/<id>`.
  - "a pulse alert opens the update" — routes to `/pulse/<pulseId>`.
  - "a payload missing its id routes nowhere rather than guessing" — missing/wrong data keys yield a null route instead of a fallback guess.
- **fromMessageData**
  - "builds a displayable notification from an FCM payload" — constructs title/body/route/read state from a typical FCM message.
  - "falls back to the data payload when the message carries no notification block" — data-only (foregrounded) push still yields title/body.
  - "non-string payload values are coerced rather than dropped" — a numeric `orderId` still produces the correct route.

## Dependencies & relationships
Exercises `NotificationType` and `AppNotification` directly; no mocks/fakes — a local helper `_n()` builds `AppNotification` instances with sensible defaults.

## Notable behavior / gotchas
Design intentionally favors graceful degradation (unknown types/missing ids) over throwing or guessing, since notifications come from an independently-deployed Cloud Function.
